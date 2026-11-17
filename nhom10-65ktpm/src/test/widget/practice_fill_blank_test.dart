import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/practice/domain/exercises.dart';
import 'package:singlearn/features/practice/presentation/fill_blank_screen.dart';
import 'package:singlearn/features/practice/presentation/practice_common.dart';

import 'harness.dart';

const songId = 'silent-night';

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<ProviderContainer> pump(WidgetTester tester, int seed) async {
    final container = ProviderContainer(overrides: [
      ...app.overrides,
      exerciseGeneratorProvider.overrideWithValue(ExerciseGenerator(Random(seed))),
    ]);
    addTearDown(container.dispose);
    // Open/seed Hive boxes in the real zone: opening or first-writing a box
    // inside fake async never completes and blocks Hive.close in tearDown.
    await tester.runAsync(() async {
      await app.store.get('downloads', '_');
      await container.read(songRepositoryProvider).allSongs();
      await container.read(songProgressRepositoryProvider).all();
      await container.read(vocabularyRepositoryProvider).words();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const FillBlankScreen(songId: songId, difficulty: BlankDifficulty.easy),
      ),
    ));
    return container;
  }

  testWidgets('plays each line, grades answers and reports the result', (tester) async {
    final container = await pump(tester, 7);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    await settleIo(tester);

    final lyrics = (await tester.runAsync(() => container.read(lyricsProvider(songId).future)))!;
    final expected = ExerciseGenerator(Random(7)).fillBlank(lyrics, BlankDifficulty.easy);
    expect(expected.blanks, isNotEmpty);

    // The first line with blanks is played as a segment.
    final first = lyrics.lines[expected.lineIndexes.first];
    expect(app.audio.log, contains('seek:${first.start.inMilliseconds}'));
    expect(app.audio.log.last, 'play');

    // Reaching the end of the line pauses the music.
    app.audio.advance(first.length + const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(); // playing=false arrives one stream hop later
    expect(app.audio.playing, isFalse);
    expect(find.textContaining('Nhạc đã dừng'), findsOneWidget);

    // Answer all lines; the first blank of the first line is answered wrong.
    var firstBlank = true;
    for (final li in expected.lineIndexes) {
      for (final b in expected.blanksOf(li)) {
        final answer = firstBlank ? 'zzz' : b.answer;
        firstBlank = false;
        await tester.enterText(find.byKey(Key('blank-${b.lineIndex}-${b.tokenIndex}')), answer);
      }
      await tester.tap(find.text('Kiểm tra'));
      await tester.pump();
      final last = li == expected.lineIndexes.last;
      await tester.tap(find.text(last ? 'Xem kết quả' : 'Tiếp'));
      await tester.pump();
    }
    await settleIo(tester);

    final total = expected.blanks.length;
    expect(find.text('${total - 1}/$total'), findsOneWidget);
    expect(find.text('Từ cần ôn lại'), findsOneWidget);
    expect(find.text(expected.blanks.first.answer), findsWidgets);

    final done = events.where((e) => e.type == LearningEventType.fillBlankCompleted).single;
    expect(done.id, startsWith('fill:$songId:easy:'));
    expect(done.data['correct'], total - 1);
    expect(done.data['total'], total);

    final progress = (await tester.runAsync(
        () => container.read(songProgressRepositoryProvider).get(songId)))!;
    expect(progress.bestExerciseScore, ((total - 1) * 100 / total).round());

    // Save the missed word to the flashcards.
    await tester.tap(find.byTooltip('Lưu vào flashcard').first);
    await settleIo(tester);
    final words = (await tester.runAsync(() => container.read(vocabularyRepositoryProvider).words()))!;
    expect(words, hasLength(1));
    expect(words.single.contexts.single.songId, songId);
    expect(events.any((e) => e.type == LearningEventType.wordSaved), isTrue);
    await closeStore(tester, app);
  });

  testWidgets('choose mode offers four options and grades them', (tester) async {
    final container = await pump(tester, 3);
    await settleIo(tester);
    final lyrics = (await tester.runAsync(() => container.read(lyricsProvider(songId).future)))!;
    final expected = ExerciseGenerator(Random(3)).fillBlank(lyrics, BlankDifficulty.easy);
    final li = expected.lineIndexes.first;

    await tester.tap(find.text('Chọn từ'));
    await tester.pump();
    for (final b in expected.blanksOf(li)) {
      expect(b.options.length, lessThanOrEqualTo(4));
      await tester.tap(find.byKey(Key('option-${b.lineIndex}-${b.tokenIndex}-${b.answer.toLowerCase()}')));
      await tester.pump();
    }
    await tester.tap(find.text('Kiểm tra'));
    await tester.pump();
    expect(find.textContaining('Chính xác!'), findsOneWidget);
    await closeStore(tester, app);
  });
}

/// Hive writes started by the screen run inside fake async and only finish
/// while the test pumps, so the store is closed here (tearDown would hang).
Future<void> closeStore(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox());
  var closed = false;
  app.store.close().then((_) => closed = true);
  for (var i = 0; i < 40 && !closed; i++) {
    await settleIo(tester, rounds: 1);
  }
  expect(closed, isTrue, reason: 'Hive boxes closed');
}
