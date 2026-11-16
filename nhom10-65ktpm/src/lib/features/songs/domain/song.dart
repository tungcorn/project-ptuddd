import 'package:flutter/material.dart';

/// CEFR levels used to group songs and learners.
const cefrLevels = ['A1', 'A2', 'B1', 'B2'];

/// Topic ids → Vietnamese labels.
const topicLabels = <String, String>{
  'family': 'Gia đình',
  'friendship': 'Tình bạn',
  'nature': 'Thiên nhiên',
  'festival': 'Lễ hội',
  'animals': 'Động vật',
  'love': 'Tình yêu',
  'travel': 'Du lịch',
  'daily-life': 'Đời sống',
  'feelings': 'Cảm xúc',
  'body': 'Cơ thể',
  'work': 'Công việc',
};

/// Genre ids → Vietnamese labels.
const genreLabels = <String, String>{
  'nursery': 'Thiếu nhi',
  'folk': 'Dân ca',
  'holiday': 'Lễ hội',
  'hymn': 'Thánh ca',
  'ballad': 'Ballad',
};

/// Where a media reference points to.
enum MediaKind { asset, file, url, none }

MediaKind mediaKindOf(String? ref) {
  if (ref == null || ref.isEmpty) return MediaKind.none;
  if (ref.startsWith('assets/')) return MediaKind.asset;
  if (ref.startsWith('http://') || ref.startsWith('https://')) {
    return MediaKind.url;
  }
  return MediaKind.file;
}

/// Song metadata (Firestore `songs/{songId}` / Hive `songs_cache`).
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.level,
    required this.topics,
    required this.genre,
    required this.durationMs,
    required this.audio,
    this.lrc = '',
    this.lrcText,
    this.cover,
    this.color = '#00796b',
    this.license = '',
    this.keywords = const [],
    this.translations = const [],
    this.hidden = false,
    this.bundled = false,
    this.updatedAt = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String level;
  final List<String> topics;
  final String genre;
  final int durationMs;

  /// Asset path, local file path or https URL of the audio file.
  final String audio;

  /// Asset path / file path / URL of the `.lrc` file (bundled songs).
  final String lrc;

  /// Inline LRC text (songs created in the admin editor).
  final String? lrcText;
  final String? cover;
  final String color;
  final String license;
  final List<String> keywords;

  /// Vietnamese translation of each lyric line, by line index.
  final List<String> translations;
  final bool hidden;

  /// True for songs shipped with the app (assets).
  final bool bundled;
  final int updatedAt;

  Duration get duration => Duration(milliseconds: durationMs);

  Color get seedColor {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('ff$hex', radix: 16));
  }

  bool get isRemoteAudio => mediaKindOf(audio) == MediaKind.url;

  factory Song.fromJson(Map<String, dynamic> j, {bool bundled = false}) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String? ?? '',
        level: j['level'] as String? ?? 'A1',
        topics: List<String>.from(j['topics'] as List? ?? const []),
        genre: j['genre'] as String? ?? 'folk',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        audio: j['audio'] as String? ?? '',
        lrc: j['lrc'] as String? ?? '',
        lrcText: j['lrcText'] as String?,
        cover: j['cover'] as String?,
        color: j['color'] as String? ?? '#00796b',
        license: j['license'] as String? ?? '',
        keywords: List<String>.from(j['keywords'] as List? ?? const []),
        translations: List<String>.from(j['translations'] as List? ?? const []),
        hidden: j['hidden'] as bool? ?? false,
        bundled: j['bundled'] as bool? ?? bundled,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'level': level,
        'topics': topics,
        'genre': genre,
        'durationMs': durationMs,
        'audio': audio,
        'lrc': lrc,
        if (lrcText != null) 'lrcText': lrcText,
        if (cover != null) 'cover': cover,
        'color': color,
        'license': license,
        'keywords': keywords,
        'translations': translations,
        'hidden': hidden,
        'bundled': bundled,
        'updatedAt': updatedAt,
      };

  Song copyWith({
    String? title,
    String? artist,
    String? level,
    List<String>? topics,
    String? genre,
    int? durationMs,
    String? audio,
    String? lrc,
    String? lrcText,
    String? cover,
    String? license,
    List<String>? keywords,
    List<String>? translations,
    bool? hidden,
    int? updatedAt,
  }) =>
      Song(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        level: level ?? this.level,
        topics: topics ?? this.topics,
        genre: genre ?? this.genre,
        durationMs: durationMs ?? this.durationMs,
        audio: audio ?? this.audio,
        lrc: lrc ?? this.lrc,
        lrcText: lrcText ?? this.lrcText,
        cover: cover ?? this.cover,
        color: color,
        license: license ?? this.license,
        keywords: keywords ?? this.keywords,
        translations: translations ?? this.translations,
        hidden: hidden ?? this.hidden,
        bundled: bundled,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// A lyric line with timing and translation. [index] is the stable line id
/// within a song (contract shared by player, vocabulary and practice).
class LyricLine {
  const LyricLine({
    required this.index,
    required this.start,
    required this.end,
    required this.en,
    this.vi = '',
  });

  final int index;
  final Duration start;
  final Duration end;
  final String en;
  final String vi;

  Duration get length => end - start;
}

/// Lyrics of one song, ready for the player and exercises.
class SongLyrics {
  const SongLyrics(this.songId, this.lines);

  final String songId;
  final List<LyricLine> lines;

  List<Duration> get starts => [for (final l in lines) l.start];
}
