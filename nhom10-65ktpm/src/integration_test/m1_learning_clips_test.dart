// Real Android audio/UI smoke for M1 content. No Firebase defines.
// flutter test integration_test/m1_learning_clips_test.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singlearn/core/config/app_config.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/router.dart';
import 'package:singlearn/features/player/presentation/player_controller.dart';
import 'package:singlearn/main.dart';
import 'package:singlearn/singlearn_app.dart';

Future<void> until(
  WidgetTester tester,
  bool Function() ready, {
  int seconds = 20,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(ready(), isTrue, reason: 'condition reached within $seconds seconds');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M1: three learning clips play, translate, look up and complete; cloze replays a line',
    (tester) async {
      expect(
        AppConfig.isFirebaseConfigured,
        isFalse,
        reason: 'this smoke must stay local, not exercise real cloud services',
      );
      await tester.pumpWidget(await bootstrap());
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SingLearnApp)),
      );
      // Do not depend on a previous E2E run having finished placement.
      if (container.read(currentUserProvider) != null) {
        await container.read(authRepositoryProvider).signOut();
      }
      await until(
        tester,
        () => find.byKey(const Key('guest-button')).evaluate().isNotEmpty,
      );
      await tester.ensureVisible(find.byKey(const Key('guest-button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('guest-button')));
      await until(
        tester,
        () => find.text('Xin chào, Khách!').evaluate().isNotEmpty,
      );
      final router = container.read(routerProvider);
      final ctrl = container.read(playerControllerProvider.notifier);
      PlayerState state() => container.read(playerControllerProvider);

      const clips = [
        (
          id: 'coffee-learning-clip',
          query: 'Coffee',
          duration: 77,
          word: 'coffee',
        ),
        (
          id: 'learn-to-fly-learning-clip',
          query: 'Learn To Fly',
          duration: 61,
          word: 'eagle',
        ),
        (
          id: 'little-tomcat-learning-clip',
          query: 'Little Tomcat',
          duration: 47,
          word: 'tomcat',
        ),
      ];
      for (final clip in clips) {
        router.go(Routes.songs);
        await until(
          tester,
          () => find.byKey(const Key('library-search')).evaluate().isNotEmpty,
        );
        await tester.enterText(
          find.byKey(const Key('library-search')),
          clip.query,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump(const Duration(milliseconds: 600));
        final tile = find.byKey(Key('song-${clip.id}'));
        await tester.scrollUntilVisible(
          tile,
          100,
          scrollable: find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(tile);
        await until(
          tester,
          () => state().song?.id == clip.id && !state().loading,
        );
        expect(state().error, isNull, reason: '${clip.id} loaded real audio');
        await until(tester, () => state().currentLine >= 1, seconds: 30);
        expect(state().playing, isTrue);
        expect(
          state().duration.inMilliseconds,
          closeTo(clip.duration * 1000, 250),
        );
        expect(
          state().position,
          greaterThan(const Duration(seconds: 3)),
          reason: 'real plugin position progressed into the second lyric line',
        );
        await tester.tap(find.byKey(const Key('play-pause')));
        await until(tester, () => !state().playing);
        await tester.tap(find.text('Song ngữ'));
        await tester.pump(const Duration(milliseconds: 400));
        final line = state().lyrics!.lines[state().currentLine];
        expect(line.vi, isNotEmpty);
        expect(find.text(line.vi), findsWidgets);
        expect(find.text(state().song!.license), findsOneWidget);

        final chip = find.widgetWithText(ActionChip, clip.word);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        final meaning = find.byKey(const Key('lookup-meaning'));
        await until(tester, () => meaning.evaluate().isNotEmpty);
        expect(tester.widget<Text>(meaning).data, isNotEmpty);
        expect(
          tester.widget<Text>(find.byKey(const Key('lookup-lemma'))).data,
          clip.word,
        );
        Navigator.of(tester.element(meaning)).pop();
        await tester.pump(const Duration(milliseconds: 400));

        // Exercise the visible seek bar near the end, then let the actual
        // recording reach completion. This does not verify sound by listening.
        final bar = tester.getRect(find.byKey(const Key('seek-bar')));
        final fraction = (clip.duration - 3) / clip.duration;
        await tester.tapAt(
          Offset(bar.left + 24 + (bar.width - 48) * fraction, bar.center.dy),
        );
        await until(
          tester,
          () => state().position.inSeconds >= clip.duration - 7,
        );
        await tester.tap(find.byKey(const Key('play-pause')));
        await until(
          tester,
          () => !state().playing && state().position.inMilliseconds < 1000,
          seconds: 15,
        );
        expect(state().error, isNull);
        // ignore: avoid_print
        print(
          'M1_CLIP_PASS ${clip.id}: audio advanced, bilingual, lookup, completion reset',
        );
      }

      // One representative new-content exercise: real segment playback must
      // pause at the line boundary and the UI's replay must start it again.
      await tester.tap(find.byTooltip('Luyện tập bài này'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Điền từ – Dễ'));
      await until(tester, () => find.text('Nghe lại').evaluate().isNotEmpty);
      await until(
        tester,
        () =>
            find.text('Nhạc đã dừng. Điền từ còn thiếu.').evaluate().isNotEmpty,
      );
      expect(state().song?.id, clips.last.id);
      expect(state().playing, isFalse);
      final stoppedAt = state().position;
      await tester.tap(find.text('Nghe lại'));
      await until(
        tester,
        () => state().playing && state().position < stoppedAt,
      );
      await until(tester, () => !state().playing);
      expect(state().error, isNull);
      await ctrl.pause();
      // ignore: avoid_print
      print('M1_CLOZE_PASS: line segment stopped and replayed through the UI');
    },
  );
}
