import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/features/auth/domain/app_user.dart';
import 'package:singlearn/features/social/data/social_repository.dart';
import 'package:singlearn/features/social/domain/social_models.dart';
import 'package:singlearn/features/social/presentation/challenge_screens.dart';

import 'harness.dart';

PublicProfile profileOf(AppUser u) => PublicProfile(
      uid: u.uid,
      displayName: u.displayName,
      userCode: u.userCode,
      email: u.email,
    );

/// Answers every question; the one at [wrongAt] (if any) is answered wrong.
Future<void> playThrough(
  WidgetTester tester,
  List<ChallengeQuestion> questions, {
  int? wrongAt,
}) async {
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    expect(find.text('Câu ${i + 1}/${questions.length}'), findsOneWidget);
    for (var o = 0; o < q.options.length; o++) {
      expect(find.descendant(of: find.byKey(Key('option-$o')), matching: find.text(q.options[o])),
          findsOneWidget);
    }
    if (q.type == ChallengeQuestionType.lyric) {
      expect(find.textContaining('_____'), findsOneWidget);
    } else {
      expect(find.text('Nghe 10 giây và đoán tên bài hát'), findsOneWidget);
      // The 10-second clip starts automatically once the song is loaded.
      await pumpUntil(tester, find.text('Nghe lại từ đầu'));
      expect(find.text('Nghe lại từ đầu'), findsOneWidget);
    }
    final pick = i == wrongAt ? (q.answerIndex + 1) % q.options.length : q.answerIndex;
    await tester.tap(find.byKey(Key('option-$pick')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quiz-next')));
    if (i + 1 < questions.length) {
      await pumpUntil(tester, find.text('Câu ${i + 2}/${questions.length}'));
    }
  }
}

/// Drives async I/O (file reads) until [finder] matches (machine speed varies a lot).
Future<void> pumpUntil(WidgetTester tester, Finder finder, {int max = 200}) async {
  for (var i = 0; i < max && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}


void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  testWidgets('create a challenge, friend plays it, result saved and event emitted',
      (tester) async {
    late AppUser a;
    late AppUser b;
    late LocalSocialRepository repo;
    await tester.runAsync(() async {
      repo = LocalSocialRepository(app.store);
      b = await app.auth.signUp(email: 'binh@test.vn', password: 'secret1', displayName: 'Bình');
      await app.auth.signOut();
      await app.signIn(email: 'an@test.vn', name: 'An');
      a = app.auth.current!;
      await repo.upsertProfile(profileOf(a));
      await repo.upsertProfile(profileOf(b));
      await repo.sendFriendRequest(a.uid, b.uid);
      await repo.respondFriendRequest(b.uid, a.uid, accept: true);
    });

    // --- A creates the challenge (questions from a seeded Random) ---
    final containerA = await app.pumpScreen(
        tester, NewChallengeScreen(friendUid: b.uid, random: Random(7)));
    await pumpUntil(tester, find.text('Bình'));
    expect(find.text('Bình'), findsOneWidget);

    // Same seed -> same questions as the screen will generate.
    final expected = (await tester.runAsync(() async {
      // Same source and order as songsProvider (awaiting the provider's
      // future here would wait on the fake-async zone).
      final songRepo = containerA.read(songRepositoryProvider);
      final songs = await songRepo.visibleSongs();
      return ChallengeGenerator(Random(7)).generate(songs, songRepo.lyrics);
    }))!;
    expect(expected.length, greaterThanOrEqualTo(4));
    expect(expected.any((q) => q.type == ChallengeQuestionType.clip), isTrue);
    expect(expected.any((q) => q.type == ChallengeQuestionType.lyric), isTrue);

    await tester.tap(find.byKey(const Key('challenge-start')));
    await pumpUntil(tester, find.text('Câu 1/${expected.length}'));

    // A misses the first question.
    await playThrough(tester, expected, wrongAt: 0);
    await pumpUntil(tester, find.text('Đã gửi thử thách'));

    final sent = (await tester.runAsync(() => repo.challenges(a.uid)))!;
    expect(sent, hasLength(1));
    final c = sent.single;
    expect(c.fromUid, a.uid);
    expect(c.toUid, b.uid);
    expect(c.toName, 'Bình');
    expect(c.status, ChallengeStatus.waiting);
    expect(c.fromScore, expected.length - 1);
    expect(c.toScore, isNull);
    expect([for (final q in c.questions) q.toJson()], [for (final q in expected) q.toJson()]);
    expect(find.text('Đã gửi thử thách'), findsOneWidget);
    // Clips were played as 10-second segments from the question start.
    expect(app.audio.log, contains('seek:${expected.first.startMs}'));

    await tester.pumpWidget(const SizedBox());

    // --- B plays the same questions ---
    await tester.runAsync(() => app.auth.signIn(email: 'binh@test.vn', password: 'secret1'));
    final containerB = await app.pumpScreen(tester, ChallengePlayScreen(challengeId: c.id));
    final events = <LearningEvent>[];
    final sub = containerB.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    await pumpUntil(tester, find.byKey(const Key('challenge-play')));
    expect(find.textContaining('An thách bạn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('challenge-play')));
    await pumpUntil(tester, find.text('Câu 1/${c.questions.length}'));
    await playThrough(tester, c.questions);
    await pumpUntil(tester, find.text('Bạn thắng!'));

    final done = (await tester.runAsync(() => repo.challenges(b.uid)))!.single;
    expect(done.status, ChallengeStatus.completed);
    expect(done.toScore, expected.length);
    expect(done.fromScore, expected.length - 1);
    expect(done.winner, b.uid);
    expect(find.text('Bạn thắng!'), findsOneWidget);

    final ev = events.where((e) => e.type == LearningEventType.challengeCompleted).toList();
    expect(ev, hasLength(1));
    expect(ev.single.id, 'challenge:${c.id}:${b.uid}');
    expect(ev.single.uid, b.uid);
    expect(ev.single.data, {'challengeId': c.id, 'score': expected.length, 'won': true});

    // Re-opening a completed challenge shows the result instead of replaying.
    await tester.pumpWidget(const SizedBox());
    await app.pumpScreen(tester, ChallengePlayScreen(challengeId: c.id));
    await pumpUntil(tester, find.text('Bạn đã chơi thử thách này rồi'));
    expect(find.text('Bạn đã chơi thử thách này rồi'), findsOneWidget);
    expect(find.byKey(const Key('challenge-play')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a challenge addressed to someone else cannot be played', (tester) async {
    late String id;
    await tester.runAsync(() async {
      final repo = LocalSocialRepository(app.store);
      await app.signIn(email: 'cuong@test.vn', name: 'Cường');
      id = newChallengeId();
      await repo.saveChallenge(Challenge(
        id: id,
        fromUid: 'x',
        fromName: 'X',
        toUid: 'y',
        toName: 'Y',
        questions: const [
          ChallengeQuestion(
              type: ChallengeQuestionType.lyric,
              songId: 's',
              options: ['a', 'b', 'c', 'd'],
              answerIndex: 0),
        ],
        fromScore: 1,
        status: ChallengeStatus.waiting,
        createdAt: 1,
        updatedAt: 1,
      ));
    });
    await app.pumpScreen(tester, ChallengePlayScreen(challengeId: id));
    await pumpUntil(tester, find.text('Không tìm thấy thử thách'));
    // Only members can read a challenge, so it is not even listed.
    expect(find.text('Không tìm thấy thử thách'), findsOneWidget);
    expect(find.byKey(const Key('challenge-play')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
