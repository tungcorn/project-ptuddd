import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../storage/local_store.dart';

/// Text-to-speech for word / sentence pronunciation (flutter_tts).
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await _init();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}

/// Quick on-device English → Vietnamese translation (Google ML Kit). The
/// language model (~30 MB) is downloaded once, then works offline.
class TranslationService {
  OnDeviceTranslator? _translator;
  final _models = OnDeviceTranslatorModelManager();

  Future<bool> isModelReady() async => !kIsWeb &&
      await _models.isModelDownloaded(TranslateLanguage.english.bcpCode) &&
      await _models.isModelDownloaded(TranslateLanguage.vietnamese.bcpCode);

  Future<bool> downloadModel() async {
    if (kIsWeb) throw UnsupportedError('Dịch máy ML Kit chỉ hỗ trợ trên Android/iOS');
    final en = await _models.downloadModel(TranslateLanguage.english.bcpCode,
        isWifiRequired: false);
    final vi = await _models.downloadModel(TranslateLanguage.vietnamese.bcpCode,
        isWifiRequired: false);
    return en && vi;
  }

  Future<String> translate(String text) async {
    if (kIsWeb) throw UnsupportedError('Dịch máy ML Kit chỉ hỗ trợ trên Android/iOS');
    _translator ??= OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.vietnamese,
    );
    return _translator!.translateText(text);
  }

  Future<void> dispose() async => _translator?.close();
}

/// Local notifications: daily study reminder and challenge updates.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _reminderId = 1001;
  static const _channelReminder = AndroidNotificationDetails(
    'study_reminder',
    'Nhắc học hằng ngày',
    channelDescription: 'Nhắc ôn từ vựng và học bài hát mỗi ngày',
    importance: Importance.defaultImportance,
  );
  static const _channelSocial = AndroidNotificationDetails(
    'social',
    'Bạn bè và thử thách',
    channelDescription: 'Lời mời và kết quả thử thách',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks for POST_NOTIFICATIONS (Android 13+). Returns true if allowed.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Next occurrence of [time] in the local time zone.
  static tz.TZDateTime nextInstanceOf(TimeOfDay time, tz.TZDateTime now) {
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    if (kIsWeb) return; // No local notifications on the web build.
    await init();
    await _plugin.cancel(id: _reminderId);
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Đến giờ học SingLearn rồi! 🎵',
      body: 'Ôn vài flashcard và nghe một bài hát để giữ chuỗi ngày học nhé.',
      scheduledDate: nextInstanceOf(time, tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(android: _channelReminder),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: _reminderId);
  }

  Future<void> show(String title, String body, {int? id}) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _channelSocial),
    );
  }

  Future<List<PendingNotificationRequest>> pending() async {
    if (kIsWeb) return const [];
    await init();
    return _plugin.pendingNotificationRequests();
  }
}

/// Downloads remote song audio to app storage for offline listening.
class DownloadService {
  DownloadService(this._store, {http.Client? client}) : _http = client ?? http.Client();

  static const _box = 'downloads';
  final LocalStore _store;
  final http.Client _http;

  Future<String?> localPath(String songId) async {
    if (kIsWeb) return null;
    final j = await _store.get(_box, songId);
    final path = j?['path'] as String?;
    if (path == null || !File(path).existsSync()) return null;
    return path;
  }

  Future<Set<String>> downloadedIds() async {
    if (kIsWeb) return <String>{};
    final out = <String>{};
    for (final e in (await _store.entries(_box)).entries) {
      if (File(e.value['path'] as String).existsSync()) out.add(e.key);
    }
    return out;
  }

  Stream<void> watch() => _store.watch(_box);

  /// Downloads [url] (streaming, with progress 0..1) and registers the file.
  Future<String> download(
    String songId,
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) throw UnsupportedError('Tải bài để nghe offline chỉ hỗ trợ trên ứng dụng Android');
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/songs');
    await dir.create(recursive: true);
    final ext = Uri.parse(url).path.split('.').last;
    final file = File('${dir.path}/$songId.${ext.length <= 4 ? ext : 'mp3'}');
    final tmp = File('${file.path}.part');
    final res = await _http.send(http.Request('GET', Uri.parse(url)));
    if (res.statusCode != 200) {
      throw HttpException('Tải thất bại (HTTP ${res.statusCode})');
    }
    final total = res.contentLength ?? 0;
    var received = 0;
    final sink = tmp.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    await tmp.rename(file.path);
    await _store.put(_box, songId, {'path': file.path, 'url': url});
    return file.path;
  }

  Future<void> remove(String songId) async {
    final path = await localPath(songId);
    if (path != null) await File(path).delete();
    await _store.delete(_box, songId);
  }
}
