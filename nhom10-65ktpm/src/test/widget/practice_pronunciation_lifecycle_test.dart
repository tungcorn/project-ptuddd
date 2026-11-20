import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/practice/presentation/pronunciation_screen.dart';
import 'package:singlearn/features/practice/presentation/speech_recognizer.dart';

import 'harness.dart';

typedef _Callbacks = ({
  void Function(SpeechHeard) result,
  void Function(SpeechFailure) error,
  void Function() done,
});

class _Recognizer implements SpeechRecognizer {
  MicPermission permission = MicPermission.granted;
  Future<MicPermission>? permissionResponse;
  Future<bool>? initializeResponse;
  Future<void>? settingsResponse;
  Future<void>? stopResponse;
  Object? settingsError;
  Object? cancelError;
  int initializeRequests = 0;
  int cancelRequests = 0;
  int settingsRequests = 0;
  final sessions = <_Callbacks>[];

  @override
  Future<MicPermission> ensurePermission() async =>
      permissionResponse == null ? permission : await permissionResponse!;

  @override
  Future<bool> initialize() async {
    initializeRequests++;
    return initializeResponse == null ? true : await initializeResponse!;
  }

  @override
  Future<void> listen({
    required void Function(SpeechHeard) onResult,
    required void Function(SpeechFailure) onError,
    required void Function() onDone,
  }) async {
    sessions.add((result: onResult, error: onError, done: onDone));
  }

  @override
  Future<void> stop() async {
    final response = stopResponse;
    if (response != null) await response;
  }

  @override
  Future<void> cancel() async {
    cancelRequests++;
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> openSettings() async {
    settingsRequests++;
    if (settingsError != null) throw settingsError!;
    final response = settingsResponse;
    if (response != null) await response;
  }
}

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    _Recognizer recognizer,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final app = await TestApp.create();
    final container = ProviderContainer(overrides: [
      ...app.overrides,
      speechRecognizerProvider.overrideWithValue(recognizer),
    ]);
    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Unmount before disposing providers: State.dispose still cancels speech.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await app.dispose();
    });
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
        home: const PronunciationScreen(
          songId: 'silent-night',
          initialLine: 2,
        ),
      ),
    ));
    await settleIo(tester);
    return container;
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);
  }

  Future<void> background(WidgetTester tester,
      {AppLifecycleState state = AppLifecycleState.paused}) async {
    tester.binding.handleAppLifecycleStateChanged(state);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('background discards a late permission response', (tester) async {
    final permission = Completer<MicPermission>();
    final rec = _Recognizer()..permissionResponse = permission.future;
    await pump(tester, rec);
    await tapMic(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await background(tester);
    permission.complete(MicPermission.granted);
    await settleIo(tester);
    expect(rec.cancelRequests, 1);
    expect(rec.initializeRequests, 0);
    expect(rec.sessions, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    rec.permissionResponse = null;
    await tapMic(tester);
    expect(rec.sessions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive permission dialog can still start recognition',
      (tester) async {
    final permission = Completer<MicPermission>();
    final rec = _Recognizer()..permissionResponse = permission.future;
    await pump(tester, rec);
    await tapMic(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    permission.complete(MicPermission.granted);
    await settleIo(tester);
    expect(rec.cancelRequests, 0);
    expect(rec.initializeRequests, 1);
    expect(rec.sessions, hasLength(1));
  });

  testWidgets('detaching during initialization discards its late response',
      (tester) async {
    final initialized = Completer<bool>();
    final rec = _Recognizer()..initializeResponse = initialized.future;
    await pump(tester, rec);
    await tapMic(tester);
    expect(rec.initializeRequests, 1);

    await background(tester, state: AppLifecycleState.detached);
    initialized.complete(true);
    await settleIo(tester);
    expect(rec.cancelRequests, 1);
    expect(rec.sessions, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    rec.initializeResponse = null;
    await tapMic(tester);
    expect(rec.initializeRequests, 2);
    expect(rec.sessions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background drops old callbacks and a new attempt scores once',
      (tester) async {
    final rec = _Recognizer();
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    await tapMic(tester);
    final old = rec.sessions.single;
    old.result(const SpeechHeard(['all is'], isFinal: false));
    await tester.pump();

    await background(tester);
    old.result(const SpeechHeard(['all is calm'], isFinal: true));
    old.error(SpeechFailure.other);
    old.done();
    await settleIo(tester);
    expect(rec.cancelRequests, 1);
    expect(find.byKey(const Key('pron-result')), findsNothing);
    expect(events, isEmpty);

    await tapMic(tester);
    expect(rec.sessions, hasLength(2));
    final fresh = rec.sessions.last;
    fresh.result(const SpeechHeard(['all is calm'], isFinal: true));
    fresh.done();
    await settleIo(tester);
    expect(find.text('100'), findsOneWidget);
    expect(events.where((e) => e.type == LearningEventType.pronunciationScored),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background contains a late stop failure before retry',
      (tester) async {
    final stop = Completer<void>();
    final rec = _Recognizer()..stopResponse = stop.future;
    await pump(tester, rec);
    await tapMic(tester);
    await tapMic(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await background(tester);
    stop.completeError(StateError('old stop failed'));
    await settleIo(tester);
    expect(find.byKey(const Key('pron-result')), findsNothing);
    expect(tester.takeException(), isNull);
    rec.stopResponse = null;
    await tapMic(tester);
    expect(rec.sessions, hasLength(2));
  });

  testWidgets('background cleanup failure is contained and allows retry',
      (tester) async {
    final rec = _Recognizer()..cancelError = StateError('cancel failed');
    await pump(tester, rec);
    await tapMic(tester);
    await background(tester);
    await settleIo(tester);

    expect(rec.cancelRequests, 1);
    expect(tester.takeException(), isNull);
    rec.cancelError = null;
    await tapMic(tester);
    expect(rec.sessions, hasLength(2));
  });

  testWidgets('settings failure explains manual recovery and permits retry',
      (tester) async {
    final rec = _Recognizer()
      ..permission = MicPermission.permanentlyDenied
      ..settingsError = StateError('cannot open settings');
    await pump(tester, rec);
    await tapMic(tester);
    final settings = find.text('Mở cài đặt');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    await settleIo(tester);

    expect(rec.settingsRequests, 1);
    expect(find.textContaining('Không mở được cài đặt.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    rec.permission = MicPermission.granted;
    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await settleIo(tester);
    expect(rec.sessions, hasLength(1));
  });

  testWidgets('settings failure after leaving cannot show a late message',
      (tester) async {
    final settings = Completer<void>();
    final rec = _Recognizer()
      ..permission = MicPermission.permanentlyDenied
      ..settingsResponse = settings.future;
    await pump(tester, rec);
    await tapMic(tester);
    final button = find.text('Mở cài đặt');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    settings.completeError(StateError('settings failed after exit'));
    await settleIo(tester);
    expect(rec.settingsRequests, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('device settings adapter', () {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');

    void reply(Future<Object?> Function(MethodCall) handler) {
      final messenger = TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, handler);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }

    testWidgets('false from the platform is a recoverable failure', (_) async {
      reply((call) async {
        expect(call.method, 'openAppSettings');
        return false;
      });
      await expectLater(DeviceSpeechRecognizer().openSettings(),
          throwsA(isA<StateError>()));
    });

    testWidgets('platform exceptions reach the UI error handler', (_) async {
      reply((_) async => throw PlatformException(code: 'settings_unavailable'));
      await expectLater(DeviceSpeechRecognizer().openSettings(),
          throwsA(isA<PlatformException>()));
    });

    testWidgets('true from the platform completes successfully', (_) async {
      reply((_) async => true);
      await expectLater(DeviceSpeechRecognizer().openSettings(), completes);
    });
  });
}
