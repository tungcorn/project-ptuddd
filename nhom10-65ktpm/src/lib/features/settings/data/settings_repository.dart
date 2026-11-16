import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';

enum LyricMode {
  english('Tiếng Anh'),
  bilingual('Song ngữ'),
  hidden('Ẩn lời');

  const LyricMode(this.label);

  final String label;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.reminderEnabled = false,
    this.reminderTime = const TimeOfDay(hour: 20, minute: 0),
    this.lyricMode = LyricMode.bilingual,
  });

  final ThemeMode themeMode;
  final bool reminderEnabled;
  final TimeOfDay reminderTime;
  final LyricMode lyricMode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? reminderEnabled,
    TimeOfDay? reminderTime,
    LyricMode? lyricMode,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        lyricMode: lyricMode ?? this.lyricMode,
      );

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        themeMode: ThemeMode.values.byName(j['themeMode'] as String? ?? 'system'),
        reminderEnabled: j['reminderEnabled'] as bool? ?? false,
        reminderTime: TimeOfDay(
          hour: (j['reminderHour'] as num?)?.toInt() ?? 20,
          minute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
        ),
        lyricMode: LyricMode.values.byName(j['lyricMode'] as String? ?? 'bilingual'),
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'reminderEnabled': reminderEnabled,
        'reminderHour': reminderTime.hour,
        'reminderMinute': reminderTime.minute,
        'lyricMode': lyricMode.name,
      };
}

class SettingsRepository {
  SettingsRepository(this._store);

  final LocalStore _store;
  static const _box = 'settings';

  Future<AppSettings> load() async {
    final j = await _store.get(_box, 'app');
    return j == null ? const AppSettings() : AppSettings.fromJson(j);
  }

  Future<void> save(AppSettings s) => _store.put(_box, 'app', s.toJson());
}
