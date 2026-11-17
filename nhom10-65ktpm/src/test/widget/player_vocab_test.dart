import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/features/player/presentation/player_controller.dart';
import 'package:singlearn/features/player/presentation/player_screen.dart';
import 'package:singlearn/features/vocabulary/presentation/review_screen.dart';
import 'package:singlearn/features/vocabulary/presentation/word_lookup_sheet.dart';

import 'harness.dart';

const songId = 'silent-night';

void main() {
  late TestApp app;

  setUp(() async {
    app = await TestApp.create();
    await app.signIn();
  });
  tearDown(() => app.dispose());

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('player loads the song, highlights the active line and seeks by line',
      (tester) async {
    bigScreen(tester);
    final c = await app.pumpScreen(tester, const PlayerScreen(songId: songId));
    await settleIo(tester, rounds: 10);

    expect(app.audio.loadedSource, 'assets/audio/$songId.mp3');
    expect(app.audio.log, contains('play'), reason: 'autoplay on open');
    final lyrics = c.read(playerControllerProvider).lyrics!;
    expect(lyrics.lines.length, 8);
    expect(find.text('Đêm yên lặng,'), findsWidgets,
        reason: 'bilingual mode shows translations');

    // Move to the 3rd line and check the controller's active line.
    app.audio.advance(lyrics.lines[2].start + const Duration(milliseconds: 100));
    await tester.pump();
    expect(c.read(playerControllerProvider).currentLine, 2);

    // Tapping a line (outside its words) seeks to the line start.
    await settleIo(tester);
    final viText = find.text('mọi thứ đều rạng ngời').first;
    await tester.ensureVisible(viText);
    await settleIo(tester);
    await tester.tap(viText);
    await settleIo(tester);
    expect(app.audio.log.where((l) => l.startsWith('seek:')).last,
        'seek:${lyrics.lines[3].start.inMilliseconds}');

    // Speed toggle.
    await tester.tap(find.byKey(const Key('speed')));
    await tester.pump();
    expect(app.audio.speed, 0.75);
    await settleIo(tester);
  });

  testWidgets('dragging the seek bar seeks once on release and keeps playing there',
      (tester) async {
    bigScreen(tester);
    final c = await app.pumpScreen(tester, const PlayerScreen(songId: songId));
    await settleIo(tester, rounds: 10);
    expect(c.read(playerControllerProvider).playing, isTrue);
    app.audio.log.clear();

    final bar = find.byKey(const Key('seek-bar'));
    final box = tester.getRect(bar);
    // Slider track has ~24 px padding on each side; drag from the start to
    // roughly 3/4 of the track.
    final gesture = await tester.startGesture(Offset(box.left + 24, box.center.dy));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset((box.width - 48) * 0.075, 0));
      await tester.pump();
    }
    // A playback tick while dragging must not move the thumb back.
    app.audio.advance(const Duration(seconds: 1));
    await tester.pump();
    expect(app.audio.log.where((l) => l.startsWith('seek:')), isEmpty,
        reason: 'no seek while the user is still dragging');
    await gesture.up();
    await settleIo(tester);

    final seeks = app.audio.log.where((l) => l.startsWith('seek:')).toList();
    expect(seeks, hasLength(1), reason: 'exactly one seek on release');
    final target = int.parse(seeks.single.substring(5));
    final total = c.read(playerControllerProvider).duration.inMilliseconds;
    expect(target, inInclusiveRange((total * 0.65).round(), (total * 0.85).round()));
    final st = c.read(playerControllerProvider);
    expect(st.position.inMilliseconds, target, reason: 'does not jump back to 0:00');
    expect(st.playing, isTrue);
    expect(app.audio.log.any((l) => l.startsWith('load:')), isFalse,
        reason: 'seeking must not reload the song');
  });

  testWidgets('opening another song stops the old one first, then plays the new one',
      (tester) async {
    bigScreen(tester);
    final c = await app.pumpScreen(tester, const PlayerScreen(songId: songId));
    await settleIo(tester, rounds: 10);
    expect(c.read(playerControllerProvider).playing, isTrue);
    app.audio.log.clear();

    final other = (await tester.runAsync(
        () => c.read(songRepositoryProvider).byId('danny-boy')))!;
    unawaited(c.read(playerControllerProvider.notifier).open(other, autoplay: true));
    await settleUntil(tester, () => c.read(playerControllerProvider).lyrics != null &&
        c.read(playerControllerProvider).song?.id == 'danny-boy' &&
        c.read(playerControllerProvider).playing);

    final log = app.audio.log;
    expect(log.indexOf('pause'), greaterThanOrEqualTo(0), reason: 'old song paused');
    expect(log.indexOf('pause'), lessThan(log.indexOf('load:danny-boy')),
        reason: 'paused before the new song loads');
    expect(log.last, 'play');
    final st = c.read(playerControllerProvider);
    expect(st.song!.id, 'danny-boy');
    expect(st.loading, isFalse);
    expect(st.playing, isTrue);
    expect(st.lyrics, isNotNull);
  });

  testWidgets('repeat-one-line and A-B loop jump back', (tester) async {
    bigScreen(tester);
    final c = await app.pumpScreen(tester, const PlayerScreen(songId: songId));
    await settleIo(tester, rounds: 10);
    final ctrl = c.read(playerControllerProvider.notifier);
    final lines = c.read(playerControllerProvider).lyrics!.lines;

    await ctrl.seek(lines[1].start + const Duration(milliseconds: 200));
    ctrl.toggleLoopLine();
    expect(c.read(playerControllerProvider).loopLine, 1);
    app.audio.advance(lines[1].length);
    await tester.pump();
    expect(app.audio.position, lines[1].start, reason: 'loops back to line start');

    ctrl.toggleLoopLine();
    await ctrl.seek(const Duration(seconds: 10));
    expect(ctrl.tapAbLoop(), contains('điểm A'));
    await ctrl.seek(const Duration(seconds: 10, milliseconds: 200));
    expect(ctrl.tapAbLoop(), contains('sau điểm A'), reason: 'B too close to A');
    await ctrl.seek(const Duration(seconds: 14));
    expect(ctrl.tapAbLoop(), 'Đang lặp đoạn A–B');
    app.audio.advance(const Duration(seconds: 1));
    await tester.pump();
    expect(app.audio.position, const Duration(seconds: 10));
    expect(ctrl.tapAbLoop(), 'Đã tắt lặp A–B');
    await settleIo(tester);
  });

  testWidgets('tap word -> lookup -> save flashcard with context -> XP', (tester) async {
    bigScreen(tester);
    final c = await app.pumpScreen(tester, const PlayerScreen(songId: songId));
    await settleIo(tester, rounds: 10);
    c.read(progressServiceProvider); // progress module listens to events
    final song = (await tester.runAsync(() => c.read(songRepositoryProvider).byId(songId)))!;
    final line = c.read(playerControllerProvider).lyrics!.lines[3];

    final ctx = tester.element(find.byType(PlayerScreen));
    showWordLookup(ctx, word: 'bright', song: song, line: line);
    await settleIo(tester, rounds: 8);
    expect(find.byKey(const Key('lookup-lemma')), findsOneWidget);
    expect(find.text('bright'), findsWidgets);
    expect(find.byKey(const Key('lookup-meaning')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lookup-save')));
    await settleIo(tester, rounds: 8);
    final words = await tester.runAsync(() => c.read(vocabularyRepositoryProvider).words());
    expect(words!.single.id, 'bright');
    expect(words.single.contexts.single.lineIndex, 3);
    expect(words.single.contexts.single.songId, songId);
    final snap = await tester.runAsync(() => c.read(progressServiceProvider).snapshot());
    expect(snap!.totalXp, 10);
  });

  testWidgets('flashcard review: flip, grade, SM-2 schedule moves to tomorrow', (tester) async {
    bigScreen(tester);
    final c0 = ProviderContainer(overrides: app.overrides);
    await tester.runAsync(() => c0.read(vocabularyRepositoryProvider).save(
        lemma: 'star', ipa: '/stɑːr/', pos: 'noun', meaning: 'ngôi sao'));
    c0.dispose();

    final c = await app.pumpScreen(tester, const ReviewScreen());
    await settleIo(tester, rounds: 8);
    expect(find.byKey(const Key('card-front')), findsOneWidget);
    await tester.tap(find.byKey(const Key('show-answer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('card-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('grade-good')));
    await settleIo(tester, rounds: 8);
    expect(find.text('Hoàn thành phiên ôn tập!'), findsOneWidget);
    final w = await tester.runAsync(() => c.read(vocabularyRepositoryProvider).byId('star'));
    expect(w!.sm2.intervalDays, 1);
    expect(w.reviewCount, 1);
    final due = await tester.runAsync(() => c.read(vocabularyRepositoryProvider).due());
    expect(due, isEmpty);
  });
}
