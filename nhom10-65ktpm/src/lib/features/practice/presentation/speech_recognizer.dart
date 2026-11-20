import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Microphone permission state as needed by the pronunciation screen.
enum MicPermission { granted, denied, permanentlyDenied }

/// Why a listening session failed.
enum SpeechFailure {
  /// Nothing (intelligible) was heard.
  noSpeech,

  /// The recognizer lost the microphone permission.
  permission,

  /// Network / engine error.
  other,
}

/// One recognition update: every alternative transcript of the utterance.
class SpeechHeard {
  const SpeechHeard(this.alternatives, {required this.isFinal});

  final List<String> alternatives;
  final bool isFinal;
}

/// Speech-to-text + microphone permission behind one seam so widget tests
/// never touch platform channels.
abstract class SpeechRecognizer {
  /// Requests the microphone permission if needed.
  Future<MicPermission> ensurePermission();

  /// Opens the app's system settings page.
  Future<void> openSettings();

  /// Whether speech recognition is available on this device.
  Future<bool> initialize();

  /// Starts listening in English. [onDone] fires when the engine stops.
  Future<void> listen({
    required void Function(SpeechHeard heard) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  });

  /// Stops listening; a final result may still be delivered.
  Future<void> stop();

  /// Stops listening and discards results.
  Future<void> cancel();
}

/// Default implementation backed by `speech_to_text` and
/// `permission_handler`.
class DeviceSpeechRecognizer implements SpeechRecognizer {
  final _stt = SpeechToText();
  void Function(SpeechFailure)? _onError;
  void Function()? _onDone;

  @override
  Future<MicPermission> ensurePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }

  @override
  Future<void> openSettings() async {
    if (!await openAppSettings()) {
      throw StateError('The system settings page could not be opened');
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      return await _stt.initialize(
        onError: (SpeechRecognitionError e) => _onError?.call(_failureOf(e.errorMsg)),
        onStatus: (s) {
          if (s == SpeechToText.doneStatus) _onDone?.call();
        },
      );
    } catch (_) {
      return false;
    }
  }

  static SpeechFailure _failureOf(String msg) {
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      return SpeechFailure.noSpeech;
    }
    if (msg.contains('permission')) return SpeechFailure.permission;
    return SpeechFailure.other;
  }

  @override
  Future<void> listen({
    required void Function(SpeechHeard heard) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    await _stt.listen(
      onResult: (r) => onResult(SpeechHeard(
        [for (final a in r.alternates) a.recognizedWords],
        isFinal: r.finalResult,
      )),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        localeId: 'en_US',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() async {
    _onError = null;
    _onDone = null;
    if (_stt.isListening) await _stt.cancel();
  }
}

final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final r = DeviceSpeechRecognizer();
  ref.onDispose(r.cancel);
  return r;
});
