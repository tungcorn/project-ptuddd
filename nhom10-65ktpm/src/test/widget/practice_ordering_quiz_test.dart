import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/practice/domain/exercises.dart';
import 'package:singlearn/features/practice/presentation/ordering_screens.dart';
import 'package:singlearn/features/practice/presentation/practice_common.dart';
import 'package:singlearn/features/practice/presentation/practice_screen.dart';
import 'package:singlearn/features/practice/presentation/quiz_screen.dart';

import 'harness.dart';

const songId = 'silent-night';

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<(ProviderContainer, List<LearningEvent>)> pump(WidgetTester tester, Widget screen) async {
    final container = ProviderContainer(overrides: [
      ...app.overrides,
      exerciseGeneratorProvider.overrideWithValue(ExerciseGenerator(Random(5))),
    ]);
    addTearDown(container.dispose);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    // Open/seed Hive boxes in the real zone: opening or first-writing a box
    // inside fake async never completes and blocks Hive.close in tearDown.
    await tester.runAsync(() async {
      await app.store.get('downloads', '_');
      await container.read(songRepositoryProvider).allSongs();
      await container.read(songProgressRepositoryProvider).all();
      await container.read(vocabularyRepositoryProvider).words();
      await container.read(dictionaryProvider.future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: screen,
      ),
    ));
    await settleIo(tester);
    return (container, events);
  }

  testWidgets('line order: checking reports an exercise event', (tester) async {
    final (_, events) = await pump(tester, const LineOrderScreen(songId: songId));
    expect(find.byIcon(Icons.drag_handle), findsWidgets);
    await tester.tap(find.text('Kiểm tra'));
    await settleIo(tester);
    expect(find.byKey(const Key('line-order-status')), findsOneWidget);
    final e = events.singleWhere((e) => e.type == LearningEventType.exerciseCompleted);
    expect(e.id, startsWith('exercise:$songId:lines:'));
    expect(e.data['total'], 5);
    expect(find.text('Làm bài khác'), findsOneWidget);
    await closeStore(tester, app);
  });

  testWidgets('word order: building the right sentence is correct', (tester) async {
    final (container, events) = await pump(tester, const WordOrderScreen(songId: songId));
    final lyrics = (await tester.runAsync(() => container.read(lyricsProvider(songId).future)))!;
    final gen = ExerciseGenerator(Random(5));
    final first = gen.wordOrder(lyrics)!;

    // Tap tiles in the correct order (first unused tile with each word).
    final used = <int>{};
    for (final w in first.words) {
      final i = Iterable<int>.generate(first.tiles.length)
          .firstWhere((i) => !used.contains(i) && first.tiles[i] == w);
      used.add(i);
      await tester.tap(find.byKey(Key('tile-$i')));
      await tester.pump();
    }
    await tester.tap(find.text('Kiểm tra'));
    await tester.pump();
    expect(find.text('Chính xác!'), findsOneWidget);
    expect(events, isEmpty);
    await closeStore(tester, app);
  });

  testWidgets('quiz: answering all questions shows the summary', (tester) async {
    final (_, events) = await pump(tester, const MeaningQuizScreen(songId: songId));
    expect(find.byKey(const Key('quiz-option-0')), findsOneWidget);
    var guard = 0;
    while (find.byKey(const Key('summary-score')).evaluate().isEmpty && guard++ < 20) {
      await tester.tap(find.byKey(const Key('quiz-option-0')));
      await tester.pump();
      final next = find.text('Câu tiếp').evaluate().isNotEmpty ? 'Câu tiếp' : 'Xem kết quả';
      await tester.tap(find.text(next));
      await settleIo(tester, rounds: 2);
    }
    expect(find.byKey(const Key('summary-score')), findsOneWidget);
    final e = events.singleWhere((e) => e.type == LearningEventType.exerciseCompleted);
    expect(e.id, startsWith('exercise:$songId:quiz:'));
    await closeStore(tester, app);
  });

  testWidgets('practice hub lists the modes and switches song', (tester) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (container, _) = await pump(tester, const PracticeScreen());
    final songs = (await tester.runAsync(() => container.read(songsProvider.future)))!;
    expect(songs.length, greaterThan(1));
    expect(find.text(songs.first.title), findsOneWidget);
    for (final t in ['Dễ', 'Vừa', 'Khó', 'Sắp xếp câu hát', 'Sắp xếp từ thành câu',
        'Trắc nghiệm nghĩa', 'Luyện hát & chấm phát âm', 'Thử thách đoán tên bài hát']) {
      await tester.scrollUntilVisible(find.text(t), 150);
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('practice-song-picker')));
    await tester.pumpAndSettle();
    final other = songs[1];
    await tester.enterText(find.byType(TextField), other.title.substring(0, 4));
    await tester.pump();
    await tester.tap(find.text(other.title).last);
    await tester.pumpAndSettle();
    expect(find.text(other.title), findsOneWidget);
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
