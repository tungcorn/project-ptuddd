// On-device end-to-end test (real Android plugins: just_audio/audio_service,
// Hive, notifications). Run on an emulator or phone:
//   flutter test integration_test/app_e2e_test.dart -d <device-id>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:singlearn/core/config/app_config.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/router.dart';
import 'package:singlearn/features/auth/presentation/placement_screen.dart';
import 'package:singlearn/features/player/presentation/player_controller.dart';
import 'package:singlearn/main.dart';
import 'package:singlearn/singlearn_app.dart';

Future<void> waitFor(WidgetTester tester, Finder f, {int seconds = 20}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (f.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where((t) => t.isNotEmpty)
      .take(40)
      .join(' | ');
  // ignore: avoid_print
  print('E2E_TIMEOUT $f -- $texts');
  final app = find.byType(SingLearnApp);
  if (app.evaluate().isNotEmpty) {
    final container = ProviderScope.containerOf(tester.element(app));
    final dueState = container.read(dueWordsProvider);
    final repo = container.read(vocabularyRepositoryProvider);
    final words = await repo.words();
    // ignore: avoid_print
    print(
      'E2E_DUE state=$dueState repositoryDue=${(await repo.due()).length} '
      'now=${DateTime.now().toIso8601String()} '
      'cards=${words.map((w) => '${w.id}:${w.sm2.dueAt.toIso8601String()}').join(',')}',
    );
  }
  throw TestFailure('Timed out waiting for $f -- Visible: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'learner flow on device: register, placement, play song, save word, review',
    (tester) async {
      expect(
        AppConfig.isFirebaseConfigured,
        isFalse,
        reason: 'this learner smoke must not create real cloud accounts',
      );
      await tester.pumpWidget(await bootstrap());
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SingLearnApp)),
      );

      // Start signed out.
      if (container.read(currentUserProvider) != null) {
        await container.read(authRepositoryProvider).signOut();
      }
      await waitFor(tester, find.byKey(const Key('login-submit')));

      // Register a fresh account.
      final email =
          'e2e${DateTime.now().millisecondsSinceEpoch}@example.invalid';
      // On a compact emulator the registration link starts below the viewport.
      final register = find.text('Chưa có tài khoản? Đăng ký');
      await tester.ensureVisible(register);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(register);
      await waitFor(tester, find.byKey(const Key('reg-name')));
      await tester.enterText(find.byKey(const Key('reg-name')), 'Tester');
      await tester.enterText(find.byKey(const Key('reg-email')), email);
      await tester.enterText(find.byKey(const Key('reg-password')), 'secret1');
      await tester.enterText(find.byKey(const Key('reg-confirm')), 'secret1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('reg-submit')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('reg-submit')));

      // Placement test: answer all correctly -> B2? Answer only first two -> A2.
      await waitFor(tester, find.text(placementQuestions.first.prompt));
      for (var i = 0; i < placementQuestions.length; i++) {
        final q = placementQuestions[i];
        final pick = i < 2 ? q.answer : (q.answer + 1) % q.options.length;
        // The ListView is lazy and retains its offset between questions.
        await tester.scrollUntilVisible(find.text(q.options[pick]), -120);
        await tester.tap(find.text(q.options[pick]));
        await tester.pump();
        final next = find.byKey(const Key('placement-next'));
        await tester.scrollUntilVisible(next, 120);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(next);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Trình độ gợi ý: A2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('placement-accept')));
      await waitFor(tester, find.text('Gợi ý cho trình độ A2'));

      // Library -> open a song -> real audio plays and lyrics sync.
      await tester.tap(find.text('Bài hát').last);
      await waitFor(tester, find.byKey(const Key('library-search')));
      await tester.enterText(find.byKey(const Key('library-search')), 'silent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('song-silent-night')));
      await waitFor(tester, find.byKey(const Key('play-pause')));
      final end = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(end) &&
          container.read(playerControllerProvider).currentLine < 1) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      final st = container.read(playerControllerProvider);
      expect(st.playing, isTrue, reason: 'audio is playing');
      expect(st.position, greaterThan(const Duration(seconds: 5)));
      expect(
        st.currentLine,
        greaterThanOrEqualTo(1),
        reason: 'lyrics advanced with playback',
      );

      // Speed 0.75x and repeat-one-line.
      await tester.tap(find.byKey(const Key('speed')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(playerControllerProvider).speed, 0.75);
      await tester.tap(find.byKey(const Key('loop-line')));
      await tester.pump();
      final loopLine = container.read(playerControllerProvider).loopLine!;
      final lines = container.read(playerControllerProvider).lyrics!.lines;
      final loopEnd = DateTime.now().add(
        Duration(
          milliseconds: (lines[loopLine].length.inMilliseconds * 2.2).round(),
        ),
      );
      while (DateTime.now().isBefore(loopEnd)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        container.read(playerControllerProvider).currentLine,
        loopLine,
        reason: 'repeat-one-line keeps playback inside the line',
      );
      await tester.tap(find.byKey(const Key('loop-line')));
      await tester.tap(find.byKey(const Key('speed')));
      await tester.pump();

      // Keyword -> lookup -> save with the lyric line as context.
      // (Lyric words are TextSpans; the keyword chip is a stable tap target.)
      // Keywords are built lazily in a horizontal ListView. On a phone, 'peace'
      // starts offscreen, so scroll the keyword row before trying to tap it.
      final peaceChip = find.widgetWithText(ActionChip, 'peace');
      await tester.scrollUntilVisible(
        peaceChip,
        160,
        scrollable: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        ),
      );
      await tester.tap(peaceChip);
      await waitFor(tester, find.byKey(const Key('lookup-save')));
      expect(find.byKey(const Key('lookup-meaning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lookup-save')));
      await tester.pump(const Duration(seconds: 1));
      final words = await container.read(vocabularyRepositoryProvider).words();
      expect(words.map((w) => w.id), contains('peace'));
      expect(words.firstWhere((w) => w.id == 'peace').contexts, isNotEmpty);
      await tester.tapAt(const Offset(20, 100)); // close sheet
      await tester.pump(const Duration(seconds: 1));
      if (find.byKey(const Key('lookup-save')).evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(20, 100));
        await tester.pump(const Duration(seconds: 1));
      }

      // XP awarded through the event bus + ledger.
      final snap = await container.read(progressServiceProvider).snapshot();
      expect(snap.totalXp, greaterThanOrEqualTo(10));
      expect(snap.streak, 1);

      // Review the saved card.
      container.read(routerProvider).go(Routes.vocabulary);
      await tester.pump(const Duration(seconds: 1));
      final startReview = find.byKey(const Key('start-review'));
      // The FAB animates into place when the paused due query resumes. Its
      // presence in the tree alone does not mean its tap target is ready.
      await waitFor(tester, startReview.hitTestable());
      await tester.tap(startReview);
      await waitFor(tester, find.byKey(const Key('show-answer')));
      await tester.tap(find.byKey(const Key('show-answer')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('grade-good')));
      await waitFor(tester, find.text('Hoàn thành phiên ôn tập!'));
      final w = await container
          .read(vocabularyRepositoryProvider)
          .byId('peace');
      expect(w!.sm2.intervalDays, 1);

      // Re-read the saved card from the current store; this is not a restart test.
      final again = await container
          .read(vocabularyRepositoryProvider)
          .byId('peace');
      expect(again!.reviewCount, 1);
    },
  );
}
