import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/auth/data/auth_repository.dart';
import 'package:singlearn/features/social/data/social_repository.dart';

import '../helpers.dart';

/// Issue #3/#5 (M2): the shared `pending_ops` queue follows the signed-in
/// account. Covers signed-out/guest, shared-path writes, a session change
/// while a flush runs, Firestore-style writes that never answer offline, and
/// the A -> B -> A flow through the app providers.

/// Fake Firestore enforcing the security rules: `users/{uid}/...` only for
/// the signed-in user, `songs/...` only for an admin. Every attempt is logged.
class RulesRemote extends FakeRemote {
  String? signedIn;
  Set<String> admins = {};
  final attempts = <String>[];
  int rejected = 0;

  /// When set, writes return this future instead of completing at once.
  Future<void> Function(String path)? gate;

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) async {
    attempts.add(path);
    if (!online) throw const SocketException('offline');
    final parts = path.split('/');
    final allowed = parts.first == 'users'
        ? signedIn != null && parts[1] == signedIn
        : signedIn != null && admins.contains(signedIn);
    if (!allowed) {
      rejected++;
      throw StateError('permission-denied: $path');
    }
    final g = gate;
    if (g != null) await g(path);
    await super.upsert(path, data);
  }
}

void main() {
  group('SyncService following the session', () {
    late LocalStore store;
    late RulesRemote cloud;
    late SyncService sync;

    /// Signed-in account as the auth repository would report it.
    String? session;

    setUp(() async {
      store = await openTestStore();
      cloud = RulesRemote();
      session = null;
      sync = SyncService(
        store,
        cloud,
        account: () => session,
        writeTimeout: const Duration(milliseconds: 100),
      );
    });
    tearDown(() => closeTestStore(store));

    Future<void> queueA() async {
      session = 'a';
      await sync.enqueue('users/a/words/star', {'v': 1, 'updatedAt': 1});
      await sync.enqueue('users/a/words/star', {'v': 2, 'updatedAt': 2});
      await sync.enqueue('users/a/xpEvents/word:star', {'xp': 10});
    }

    test('signed out or guest sends nothing and keeps the queue', () async {
      await queueA();
      session = null;
      expect(await sync.pendingCount(), 0);
      expect(await sync.flush(), 0);
      expect(cloud.attempts, isEmpty, reason: 'no write without a session');
      session = 'a';
      expect(await sync.pendingCount(), 3, reason: 'nothing was dropped');
    });

    test(
      'default flush sends only the signed-in account; A is never attempted',
      () async {
        await queueA();
        session = 'b';
        cloud.signedIn = 'b';
        await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});

        expect(await sync.pendingCount(), 1);
        expect(await sync.flush(), 1);
        expect(cloud.attempts, ['users/b/words/boat']);
        expect(
          await sync.flush(uid: 'a'),
          0,
          reason: 'another account is refused while B is signed in',
        );
        expect(cloud.rejected, 0);

        session = 'a';
        cloud.signedIn = 'a';
        expect(await sync.pendingCount(), 3);
        expect(await sync.flush(), 3);
        expect(cloud.docs['users/a/words/star']!['v'], 2, reason: 'in order');
        expect(cloud.rejected, 0);
      },
    );

    test('a shared write waits for its author instead of blocking B', () async {
      cloud.admins = {'a'};
      session = 'a';
      cloud.online = false;
      await sync.enqueue('songs/twinkle', {'title': 'Twinkle'});
      expect(await sync.flush(), 0);
      cloud.attempts.clear();

      cloud
        ..online = true
        ..signedIn = 'b';
      session = 'b';
      await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
      expect(await sync.flush(), 1);
      expect(cloud.attempts, ['users/b/words/boat']);

      cloud.signedIn = 'a';
      session = 'a';
      expect(await sync.flush(), 1);
      expect(cloud.docs.keys, contains('songs/twinkle'));
      expect(cloud.rejected, 0);
    });

    test(
      'switching account mid-flush stops A and still runs the B flush',
      () async {
        await queueA();
        cloud.signedIn = 'a';
        final release = Completer<void>();
        final started = Completer<void>();
        cloud.gate = (_) {
          if (!started.isCompleted) started.complete();
          return release.future;
        };

        final flushA = sync.flush();
        await started.future;
        // A signs out and B signs in while A's first write is on its way.
        session = 'b';
        cloud.signedIn = 'b';
        cloud.gate = null;
        await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
        var flushBDone = false;
        final flushB = sync.flush().whenComplete(() => flushBDone = true);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(flushBDone, isFalse, reason: 'B waits instead of returning 0');

        release.complete();
        expect(await flushA, 1, reason: 'only the write already sent');
        expect(await flushB, 1);
        expect(cloud.attempts, [
          'users/a/words/star',
          'users/b/words/boat',
        ], reason: 'no A write is started under B');
        expect(cloud.rejected, 0);

        session = 'a';
        cloud.signedIn = 'a';
        expect(await sync.pendingCount(), 2);
        expect(await sync.flush(), 2);
        expect(cloud.docs['users/a/words/star']!['v'], 2);
        expect(cloud.docs.keys, contains('users/a/xpEvents/word:star'));
      },
    );

    test('a write that never answers (Firestore offline) times out, does not '
        'block B and is not re-sent', () async {
      await queueA();
      cloud.signedIn = 'a';
      final answer = Completer<void>();
      cloud.gate = (path) =>
          path == 'users/a/words/star' ? answer.future : Future<void>.value();

      expect(await sync.flush(), 0, reason: 'timed out, op kept');
      expect(await sync.pendingCount(), 3);

      session = 'b';
      cloud.signedIn = 'b';
      await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
      expect(await sync.flush(), 1, reason: 'B is not held by A');

      // A is back while the first write is still unanswered.
      session = 'a';
      cloud.signedIn = 'a';
      final watch = Stopwatch()..start();
      expect(await sync.flush(), 0);
      expect(
        watch.elapsed,
        lessThan(sync.writeTimeout),
        reason: 'stops at the unanswered write instead of waiting again',
      );
      int starAttempts() =>
          cloud.attempts.where((p) => p == 'users/a/words/star').length;
      expect(starAttempts(), 1, reason: 'not re-sent');

      // Acknowledged late: it leaves the queue without being re-sent and the
      // rest of A's queue follows on its own.
      answer.complete();
      for (var i = 0; i < 100 && await sync.pendingCount() > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(starAttempts(), 2, reason: 'first and second star write once');
      expect(cloud.docs['users/a/words/star']!['v'], 2);
      expect(await sync.pendingCount(), 0);
    });

    /// Waits until [done] holds, failing after about a second.
    Future<void> eventually(
      Future<bool> Function() done,
      String reason,
    ) async {
      for (var i = 0; i < 100; i++) {
        if (await done()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail(reason);
    }

    test('a late acknowledgement resumes the rest of the queue without '
        'another trigger', () async {
      await queueA();
      cloud.signedIn = 'a';
      final answer = Completer<void>();
      var held = true;
      cloud.gate = (path) => held && path == 'users/a/words/star'
          ? answer.future
          : Future<void>.value();

      expect(await sync.flush(), 0, reason: 'first write timed out');
      // Reconnect: this flush stops at the unanswered write.
      expect(await sync.flush(), 0);
      held = false;

      // The old request is acknowledged; no third flush is called.
      answer.complete();
      await eventually(
        () async => await sync.pendingCount() == 0,
        'remaining ops should sync without a third external trigger',
      );
      expect(cloud.docs['users/a/words/star']!['v'], 2, reason: 'in order');
      expect(cloud.docs.keys, contains('users/a/xpEvents/word:star'));
      expect(
        cloud.attempts.where((p) => p == 'users/a/words/star').length,
        2,
        reason: 'each queued write sent once',
      );
    });

    test('a late acknowledgement after sign-out sends nothing more', () async {
      await queueA();
      cloud.signedIn = 'a';
      final answer = Completer<void>();
      cloud.gate = (path) =>
          path == 'users/a/words/star' ? answer.future : Future<void>.value();
      expect(await sync.flush(), 0);

      // A signs out while the first write is still unanswered.
      session = null;
      answer.complete();
      await eventually(
        () async {
          session = 'a';
          final left = await sync.pendingCount();
          session = null;
          return left == 2;
        },
        'the acknowledged write should leave the queue',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cloud.attempts, ['users/a/words/star'], reason: 'signed out');

      session = 'a';
      expect(await sync.flush(), 2, reason: 'A gets the rest on return');
    });

    test('a late failure does not start a retry loop', () async {
      await queueA();
      cloud.signedIn = 'a';
      final answer = Completer<void>();
      cloud.gate = (path) =>
          path == 'users/a/words/star' ? answer.future : Future<void>.value();
      expect(await sync.flush(), 0);

      answer.completeError(StateError('unavailable'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(cloud.attempts, ['users/a/words/star'], reason: 'no auto retry');
      expect(await sync.pendingCount(), 3, reason: 'nothing dropped');

      cloud.gate = null;
      expect(await sync.flush(), 3, reason: 'the next trigger retries');
    });

    test(
      'an old shared write without author only holds its own document',
      () async {
        // Queued by an admin before authors were recorded (no `by`).
        await store.put(SyncService.pendingBox, '0', {
          'path': 'songs/twinkle',
          'data': {'title': 'Twinkle'},
        });
        session = 'b';
        cloud.signedIn = 'b';
        await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
        expect(await sync.flush(), 1, reason: 'B is not blocked');
        expect(cloud.docs.keys, ['users/b/words/boat']);
        expect(
          await sync.pendingCount(),
          1,
          reason: 'the shared write is kept',
        );

        cloud.admins = {'a'};
        session = 'a';
        cloud.signedIn = 'a';
        expect(await sync.flush(), 1);
        expect(cloud.docs.keys, contains('songs/twinkle'));
      },
    );

    test('a skipped shared document keeps its order across admins', () async {
      cloud.admins = {'a', 'b'};
      session = 'a';
      cloud.online = false;
      await sync.enqueue('songs/twinkle', {'v': 'A edit', 'updatedAt': 1});
      cloud.online = true;

      session = 'b';
      cloud.signedIn = 'b';
      await sync.enqueue('songs/twinkle', {'v': 'B edit', 'updatedAt': 2});
      await sync.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
      cloud.attempts.clear();
      expect(await sync.flush(), 1, reason: "B's edit waits behind A's");
      expect(cloud.attempts, ['users/b/words/boat']);

      session = 'a';
      cloud.signedIn = 'a';
      expect(await sync.flush(), 1);
      session = 'b';
      cloud.signedIn = 'b';
      expect(await sync.flush(), 1);
      expect(
        cloud.docs['songs/twinkle']!['v'],
        'B edit',
        reason: 'the newer edit is applied last',
      );
    });

    test('calls made during a flush share one extra pass', () async {
      session = 'a';
      cloud.signedIn = 'a';
      await sync.enqueue('users/a/words/star', {'v': 1, 'updatedAt': 1});
      final release = Completer<void>();
      final started = Completer<void>();
      cloud.gate = (_) {
        started.complete();
        return release.future;
      };
      final first = sync.flush();
      await started.future;
      cloud.gate = null;
      await sync.enqueue('users/a/words/sky', {'v': 2, 'updatedAt': 2});
      final second = sync.flush();
      final third = sync.flush();
      expect(identical(second, third), isTrue);
      release.complete();
      expect(await first, 1);
      expect(await second, 1, reason: 'the write queued meanwhile is sent');
      expect(cloud.attempts, ['users/a/words/star', 'users/a/words/sky']);
    });
  });

  group('A -> B -> A through the app providers', () {
    late LocalStore store;
    late RulesRemote cloud;
    late ProviderContainer container;
    late LocalAuthRepository auth;

    setUp(() async {
      store = await openTestStore();
      cloud = RulesRemote()..online = false;
      auth = LocalAuthRepository(store);
      container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          remoteStoreProvider.overrideWithValue(cloud),
          authRepositoryProvider.overrideWithValue(auth),
          socialRepositoryProvider.overrideWithValue(
            LocalSocialRepository(store),
          ),
        ],
      );
      // Like the app shell: keep progress alive so it records XP events.
      container.listen(progressServiceProvider, (_, _) {});
      await auth.restore();
    });

    tearDown(() async {
      container.dispose();
      await closeTestStore(store);
    });

    /// Waits until the providers and the queue follow the new session.
    Future<void> switchedTo(String? uid) async {
      for (var i = 0; i < 100; i++) {
        final u = container.read(currentUserProvider)?.uid;
        if (u == uid && container.read(syncServiceProvider).account == uid) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('session did not switch to $uid');
    }

    Future<void> xp(int expected) async {
      for (var i = 0; i < 100; i++) {
        final snap = await container.read(progressServiceProvider).snapshot();
        if (snap.totalXp == expected) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('XP did not reach $expected');
    }

    Future<void> save(String lemma) => container
        .read(vocabularyRepositoryProvider)
        .save(lemma: lemma, ipa: '', pos: 'noun', meaning: lemma);

    Future<List<String>> words() async => [
      for (final w
          in await container.read(vocabularyRepositoryProvider).words())
        w.id,
    ];

    test('queue, data and XP follow each account', () async {
      final a = await auth.signUp(
        email: 'a@example.com',
        password: 'secret1',
        displayName: 'An',
      );
      await switchedTo(a.uid);
      await save('star');
      await xp(10);
      final sync = container.read(syncServiceProvider);
      expect(await sync.flush(), 0, reason: 'offline');
      expect(await sync.pendingCount(), 2, reason: 'word + XP event');
      cloud.attempts.clear();

      // A signs out with writes still queued.
      await auth.signOut();
      await switchedTo(null);
      cloud.online = true;
      expect(await sync.flush(), 0);
      expect(cloud.attempts, isEmpty);

      final b = await auth.signUp(
        email: 'b@example.com',
        password: 'secret2',
        displayName: 'Binh',
      );
      cloud.signedIn = b.uid;
      await switchedTo(b.uid);
      expect(await words(), isEmpty, reason: 'B does not see A words');
      expect(
        (await container.read(progressServiceProvider).snapshot()).totalXp,
        0,
      );
      await save('boat');
      await xp(10);
      expect(await sync.pendingCount(), 2);
      expect(await sync.flush(), 2);
      expect(cloud.rejected, 0, reason: 'no A write was tried under B');
      expect(
        cloud.docs.keys.every((p) => p.startsWith('users/${b.uid}/')),
        isTrue,
      );

      await auth.signOut();
      await auth.signIn(email: 'a@example.com', password: 'secret1');
      cloud.signedIn = a.uid;
      await switchedTo(a.uid);
      expect(await words(), ['star']);
      expect(await sync.pendingCount(), 2, reason: 'A queue kept');
      expect(await sync.flush(), 2);
      expect(cloud.rejected, 0);
      expect(
        cloud.docs.keys.where((p) => p.startsWith('users/${a.uid}/')),
        unorderedEquals([
          'users/${a.uid}/words/star',
          'users/${a.uid}/xpEvents/word:star',
        ]),
      );
      expect(await sync.flush(), 0, reason: 'nothing sent twice');

      // A on a new device: pulling twice restores the deck and XP once.
      final device2 = SyncService(store, cloud, account: () => a.uid);
      await store.clear('words_${a.uid}');
      await store.clear('xp_ledger_${a.uid}');
      for (var i = 0; i < 2; i++) {
        await device2.pull('users/${a.uid}/words', 'words_${a.uid}');
        await device2.pull('users/${a.uid}/xpEvents', 'xp_ledger_${a.uid}');
      }
      expect(await words(), ['star']);
      expect(
        (await container.read(progressServiceProvider).snapshot()).totalXp,
        10,
      );
    });
  });
}
