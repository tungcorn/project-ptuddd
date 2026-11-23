import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/account_sync.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/auth/data/auth_repository.dart';
import 'package:singlearn/features/social/data/social_repository.dart';

import '../helpers.dart';

/// Remote whose writes can be held without an answer, like Firestore
/// while offline.
class HangingRemote extends FakeRemote {
  bool hang = false;
  final held = <Completer<void>>[];

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) {
    if (!hang) return super.upsert(path, data);
    final c = Completer<void>();
    held.add(c);
    return c.future;
  }
}

/// Public profile store that never answers, like Firestore offline.
class HangingSocial extends LocalSocialRepository {
  HangingSocial(super.store);

  int calls = 0;

  @override
  Future<void> upsertProfile(profile) {
    calls++;
    return Completer<void>().future;
  }
}

/// Public profile store that counts the writes it receives.
class CountingSocial extends LocalSocialRepository {
  CountingSocial(super.store);

  int calls = 0;

  @override
  Future<void> upsertProfile(profile) {
    calls++;
    return super.upsertProfile(profile);
  }
}

void main() {
  group('SyncOutcome.message', () {
    test('never reports success while writes wait or a step failed', () {
      expect(
        const SyncOutcome(pushed: 0, remaining: 3, sendFailed: true).message,
        'còn 3 thay đổi chưa đồng bộ. Kiểm tra kết nối rồi thử lại.',
      );
      expect(
        const SyncOutcome(pushed: 2, remaining: 1).message,
        'Đã gửi 2 thay đổi; còn 1 thay đổi chưa đồng bộ. '
        'Kiểm tra kết nối rồi thử lại.',
      );
      expect(
        const SyncOutcome(pushed: 0, remaining: 0, sendFailed: true).message,
        contains('chưa gửi được'),
      );
      expect(
        const SyncOutcome(pushed: 1, remaining: 0, pullFailed: true).message,
        contains('chưa tải được dữ liệu mới'),
      );
      expect(
        const SyncOutcome(pushed: 4, remaining: 0).message,
        'Đã đồng bộ 4 thay đổi',
      );
      expect(
        const SyncOutcome(pushed: 0, remaining: 0).message,
        'Dữ liệu đã được đồng bộ',
      );
      expect(
        const SyncOutcome(pushed: 0, remaining: 0, signedIn: false).complete,
        isFalse,
      );
    });
  });

  group('AccountSync', () {
    late LocalStore store;
    late HangingRemote remote;
    late SyncService sync;
    String? account;
    late List<String> pulls;
    late List<String> published;
    Future<void> Function(String uid) pull = (_) async {};

    AccountSync make({Duration limit = const Duration(seconds: 5)}) =>
        AccountSync(
          sync: sync,
          account: () => account,
          pull: (uid) {
            pulls.add(uid);
            return pull(uid);
          },
          publishProfile: published.add,
          sendLimit: limit,
          pullLimit: limit,
        );

    setUp(() async {
      store = await openTestStore();
      remote = HangingRemote();
      sync = SyncService(store, remote);
      account = 'A';
      pulls = [];
      published = [];
      pull = (_) async {};
    });
    tearDown(() => closeTestStore(store));

    test('sends, downloads, then publishes the profile', () async {
      await sync.enqueue('users/A/words/a', {'v': 1});
      final s = make();
      expect(s.isReconciled('A'), isFalse);
      final outcome = await s.syncNow();
      expect(outcome.pushed, 1);
      expect(outcome.complete, isTrue);
      expect(pulls, ['A']);
      expect(published, ['A']);
      expect(s.isReconciled('A'), isTrue);
    });

    test(
      'an unanswered write ends the run and is reported, not hidden',
      () async {
        remote.hang = true;
        await sync.enqueue('users/A/words/a', {'v': 1});
        final s = make(limit: const Duration(milliseconds: 50));
        final outcome = await s.syncNow();
        expect(outcome.sendFailed, isTrue);
        expect(outcome.remaining, 1);
        expect(outcome.complete, isFalse);
        expect(outcome.message, contains('còn 1 thay đổi chưa đồng bộ'));
        expect(await sync.pendingCount(), 1, reason: 'the write stays queued');
      },
    );

    test('a failed or hanging download publishes nothing', () async {
      pull = (_) => Completer<void>().future;
      final s = make(limit: const Duration(milliseconds: 50));
      final outcome = await s.syncNow();
      expect(outcome.pullFailed, isTrue);
      expect(published, isEmpty);
      expect(s.isReconciled('A'), isFalse);

      pull = (_) async => throw StateError('offline');
      expect((await s.syncNow()).pullFailed, isTrue);
      expect(published, isEmpty);
    });

    test('signed out or a guest: nothing is sent or downloaded', () async {
      await sync.enqueue('users/A/words/a', {'v': 1});
      account = null;
      final s = make();
      final outcome = await s.syncNow();
      expect(outcome.signedIn, isFalse);
      expect(outcome.message, contains('Đăng nhập'));
      expect(remote.writes, 0);
      expect(pulls, isEmpty);
      expect(await s.pending(), 0);
    });

    test("counts and sends only the signed-in account's writes", () async {
      await sync.enqueue('users/A/words/a', {'v': 1});
      await sync.enqueue('users/B/words/b', {'v': 2});
      account = 'B';
      final s = make();
      expect(await s.pending(), 1);
      final outcome = await s.syncNow();
      expect(outcome.pushed, 1);
      expect(outcome.remaining, 0);
      expect(remote.docs.keys, ['users/B/words/b']);
      expect(await sync.pendingCount(uid: 'A'), 1, reason: "A's write kept");
    });

    test('a request made during a run is served after it, for the new '
        'session', () async {
      final started = Completer<void>();
      final gate = Completer<void>();
      pull = (uid) {
        if (uid != 'A') return Future.value();
        started.complete();
        return gate.future;
      };
      final s = make();
      final first = s.syncNow();
      await started.future;
      // A signs out and B signs in while A's download is running.
      account = 'B';
      final second = s.syncNow();
      gate.complete();
      final a = await first;
      final b = await second;
      expect(pulls, ['A', 'B']);
      expect(
        a.pullFailed,
        isTrue,
        reason: "A's data is not reported current after A left",
      );
      expect(published, ['B'], reason: "A's profile is not published under B");
      expect(b.complete, isTrue);
      expect(s.isReconciled('A'), isFalse);
    });

    test('local mode publishes the profile without sending', () async {
      final s = AccountSync(
        sync: SyncService(store, null),
        account: () => 'A',
        pull: (uid) async => pulls.add(uid),
        publishProfile: published.add,
      );
      expect(s.isReconciled('A'), isTrue);
      expect((await s.syncNow()).complete, isTrue);
      expect(pulls, isEmpty);
      expect(published, ['A']);
    });
  });

  group('app providers (cloud mode, fake remote)', () {
    late LocalStore store;
    late FakeRemote remote;
    late LocalAuthRepository auth;

    setUp(() async {
      store = await openTestStore();
      remote = FakeRemote();
      auth = LocalAuthRepository(store);
      await auth.restore();
    });
    tearDown(() => closeTestStore(store));

    ProviderContainer container(SocialRepository social) {
      final c = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          remoteStoreProvider.overrideWithValue(remote),
          authRepositoryProvider.overrideWithValue(auth),
          socialRepositoryProvider.overrideWithValue(social),
        ],
      );
      addTearDown(c.dispose);
      // Like the app shell: keep progress alive so it records XP events.
      c.listen(progressServiceProvider, (_, _) {});
      return c;
    }

    /// Waits until the providers follow the signed-in session, then lets
    /// background writes finish.
    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 100; i++) {
        final uid = auth.current?.uid;
        if (uid != null && c.read(progressServiceProvider).uid == uid) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test(
      'a fresh install does not overwrite the cloud XP before download',
      () async {
        final user = await auth.signUp(
          email: 'a@test.vn',
          password: 'secret1',
          displayName: 'An',
        );
        // XP the learner earned on another device, already on the server.
        for (var i = 0; i < 3; i++) {
          remote.docs['users/${user.uid}/xpEvents/old$i'] = {
            'id': 'old$i',
            'type': LearningEventType.wordSaved.name,
            'xp': 10,
            'at': DateTime(2026, 11, 1).millisecondsSinceEpoch,
            'day': '2026-11-01',
            'data': const <String, Object?>{},
            'updatedAt': 100 + i,
          };
        }
        final social = LocalSocialRepository(store);
        final c = container(social);
        await settle(c);
        final progress = c.read(progressServiceProvider);
        expect(progress.uid, user.uid);

        // Learning on the new device before its first download.
        final xp = await progress.record(
          LearningEvent(
            id: 'new1',
            type: LearningEventType.wordSaved,
            uid: user.uid,
          ),
        );
        expect(xp, isNotNull);
        await settle(c);
        expect(
          await social.profile(user.uid),
          isNull,
          reason: 'unreconciled local XP must not reach the public profile',
        );

        final outcome = await c.read(accountSyncProvider).syncNow();
        expect(outcome.complete, isTrue);
        await settle(c);
        final profile = await social.profile(user.uid);
        expect(
          profile?.xp,
          30 + xp!,
          reason: 'published from the downloaded ledger plus the new event',
        );
      },
    );

    test(
      'an offline refresh answered from the cache does not publish old XP',
      () async {
        final user = await auth.signUp(
          email: 'c@test.vn',
          password: 'secret1',
          displayName: 'Cuong',
        );
        Map<String, Object?> event(String id, int updatedAt) => {
          'id': id,
          'type': LearningEventType.wordSaved.name,
          'xp': 10,
          'at': DateTime(2026, 11, 1).millisecondsSinceEpoch,
          'day': '2026-11-01',
          'data': const <String, Object?>{},
          'updatedAt': updatedAt,
        };
        // Device A downloads 100 XP.
        for (var i = 0; i < 10; i++) {
          remote.docs['users/${user.uid}/xpEvents/a$i'] = event('a$i', 100 + i);
        }
        final social = CountingSocial(store);
        final c = container(social);
        await settle(c);
        final sync = c.read(accountSyncProvider);
        expect((await sync.syncNow()).complete, isTrue);
        await settle(c);
        expect((await social.profile(user.uid))?.xp, 100);

        // A's Firestore cache holds those 100 XP; device B then learns
        // 100 XP more on the server.
        remote.offlineCache = Map.of(remote.docs);
        for (var i = 0; i < 10; i++) {
          remote.docs['users/${user.uid}/xpEvents/b$i'] = event('b$i', 200 + i);
        }
        final published = social.calls;

        // A is offline with an empty queue and resumes / taps "Đồng bộ ngay":
        // the queries succeed from the cache only.
        remote.online = false;
        expect(await sync.pending(), 0);
        final offline = await sync.syncNow();
        await settle(c);
        expect(offline.complete, isFalse);
        expect(offline.pullFailed, isTrue);
        expect(
          social.calls,
          published,
          reason: 'no profile write from data the server did not confirm',
        );

        // Back online: the server data is downloaded, then published.
        remote.online = true;
        expect((await sync.syncNow()).complete, isTrue);
        await settle(c);
        expect((await social.profile(user.uid))?.xp, 200);
      },
    );

    test(
      'XP recording is not held up by a profile write that never answers',
      () async {
        final user = await auth.signUp(
          email: 'b@test.vn',
          password: 'secret1',
          displayName: 'Binh',
        );
        final social = HangingSocial(store);
        final c = container(social);
        await settle(c);
        expect((await c.read(accountSyncProvider).syncNow()).complete, isTrue);
        final progress = c.read(progressServiceProvider);
        for (var i = 0; i < 3; i++) {
          final xp = await progress
              .record(
                LearningEvent(
                  id: 'e$i',
                  type: LearningEventType.wordSaved,
                  uid: user.uid,
                ),
              )
              .timeout(const Duration(seconds: 2));
          expect(xp, isNotNull);
        }
        expect(social.calls, greaterThanOrEqualTo(3));
        expect((await progress.snapshot()).wordsSaved, 3);
      },
    );
  });
}
