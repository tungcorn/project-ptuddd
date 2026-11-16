import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/storage/local_store.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/lrc_parser.dart';
import '../domain/song.dart';

typedef AssetStringLoader = Future<String> Function(String path);

/// Song catalogue: bundled songs (assets) merged with admin edits and songs
/// pulled from Firestore (Hive box `songs_cache`, last-write-wins on
/// `updatedAt`).
class SongRepository {
  SongRepository({
    required this._store,
    required this._sync,
    required this._loadAsset,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const cacheBox = 'songs_cache';
  static const _lrcCacheBox = 'lrc_cache';
  static const catalogAsset = 'assets/content/catalog.json';

  final LocalStore _store;
  final SyncService _sync;
  final AssetStringLoader _loadAsset;
  final http.Client _http;
  List<Song>? _bundled;
  final Map<String, SongLyrics> _lyricsCache = {};

  Future<List<Song>> _bundledSongs() async {
    if (_bundled != null) return _bundled!;
    final json = jsonDecode(await _loadAsset(catalogAsset)) as Map<String, dynamic>;
    _bundled = [
      for (final s in json['songs'] as List)
        Song.fromJson(Map<String, dynamic>.from(s as Map), bundled: true),
    ];
    return _bundled!;
  }

  /// All songs including hidden ones (for the admin screen).
  Future<List<Song>> allSongs() async {
    final byId = {for (final s in await _bundledSongs()) s.id: s};
    for (final doc in await _store.values(cacheBox)) {
      final song = Song.fromJson(doc);
      final existing = byId[song.id];
      if (existing == null || song.updatedAt >= existing.updatedAt) {
        byId[song.id] = song;
      }
    }
    final levelOrder = {for (var i = 0; i < cefrLevels.length; i++) cefrLevels[i]: i};
    final list = byId.values.toList()
      ..sort((a, b) {
        final c = (levelOrder[a.level] ?? 9).compareTo(levelOrder[b.level] ?? 9);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    return list;
  }

  /// Songs visible to learners.
  Future<List<Song>> visibleSongs() async =>
      (await allSongs()).where((s) => !s.hidden).toList();

  Future<Song?> byId(String id) async {
    for (final s in await allSongs()) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Creates or updates a song (admin). Stored locally first and queued for
  /// Firestore `songs/{id}`.
  Future<Song> save(Song song) async {
    final updated = song.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    await _store.put(cacheBox, updated.id, updated.toJson());
    await _sync.enqueue('songs/${updated.id}', updated.toJson());
    _lyricsCache.remove(updated.id);
    await _store.delete(_lrcCacheBox, updated.id);
    return updated;
  }

  Future<void> pullRemote() => _sync.pull('songs', cacheBox);

  /// Raw LRC text for [song].
  Future<String> lrcSource(Song song) async {
    final inline = song.lrcText;
    if (inline != null && inline.trim().isNotEmpty) return inline;
    switch (mediaKindOf(song.lrc)) {
      case MediaKind.asset:
        return _loadAsset(song.lrc);
      case MediaKind.file:
        return File(song.lrc).readAsString();
      case MediaKind.url:
        final cached = await _store.get(_lrcCacheBox, song.id);
        if (cached != null && cached['url'] == song.lrc) {
          return cached['text'] as String;
        }
        final res = await _http.get(Uri.parse(song.lrc));
        if (res.statusCode != 200) {
          throw HttpException('LRC HTTP ${res.statusCode}');
        }
        final text = utf8.decode(res.bodyBytes);
        await _store.put(_lrcCacheBox, song.id, {'url': song.lrc, 'text': text});
        return text;
      case MediaKind.none:
        return '';
    }
  }

  /// Timed lyric lines with translations, merged by line index.
  Future<SongLyrics> lyrics(Song song) async {
    final cached = _lyricsCache[song.id];
    if (cached != null) return cached;
    final doc = LrcParser.parse(await lrcSource(song));
    final result = buildLyrics(song, doc);
    if (!song.id.contains('__preview')) _lyricsCache[song.id] = result;
    return result;
  }

  /// Pure merge of LRC timing + translations (exposed for tests and for the
  /// admin live preview).
  static SongLyrics buildLyrics(Song song, LrcDocument doc) {
    final lines = <LyricLine>[];
    for (var i = 0; i < doc.lines.length; i++) {
      final start = doc.lines[i].start;
      Duration end;
      if (i + 1 < doc.lines.length) {
        end = doc.lines[i + 1].start;
      } else {
        end = doc.end ?? (song.durationMs > 0 ? song.duration : start + const Duration(seconds: 5));
      }
      lines.add(LyricLine(
        index: i,
        start: start,
        end: end,
        en: doc.lines[i].text,
        vi: i < song.translations.length ? song.translations[i] : '',
      ));
    }
    return SongLyrics(song.id, lines);
  }
}
