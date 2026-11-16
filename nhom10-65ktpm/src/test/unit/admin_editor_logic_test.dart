import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/admin/data/admin_media_store.dart';
import 'package:singlearn/features/admin/domain/song_editor_logic.dart';
import 'package:singlearn/features/songs/domain/lrc_parser.dart';

SongDraft _draft({
  String title = 'Bài hát',
  String artist = 'Ca sĩ',
  String license = 'Public domain',
  String audio = 'https://example.com/a.mp3',
  String cover = '',
  String lrc = '[00:01.00]one\n[00:02.00]two\n',
  List<String> translations = const ['một', 'hai'],
  String level = 'A1',
}) => SongDraft(
  title: title,
  artist: artist,
  level: level,
  topics: const ['family'],
  genre: 'folk',
  license: license,
  keywords: const [],
  audio: audio,
  cover: cover,
  lrcText: lrc,
  translations: translations,
);

void main() {
  group('slugify / newSongId', () {
    test('removes Vietnamese accents and punctuation', () {
      expect(slugify('Chúc Mừng Năm Mới!'), 'chuc-mung-nam-moi');
      expect(slugify('  Đi học  '), 'di-hoc');
      expect(slugify('Ỷ ỹ ữ ở ặ ệ'), 'y-y-u-o-a-e');
      expect(slugify('Twinkle, Twinkle Little Star'), 'twinkle-twinkle-little-star');
      expect(slugify('!!!'), 'song');
      expect(slugify('a' * 80).length, 40);
    });

    test('id is slug + 4-char suffix and unique against existing ids', () {
      final id = newSongId('Hello World', const [], random: Random(1));
      expect(id, matches(RegExp(r'^hello-world-[a-z0-9]{4}$')));
      final again = newSongId('Hello World', [id], random: Random(1));
      expect(again, isNot(id));
      expect(again, startsWith('hello-world-'));
    });
  });

  test('resizeTranslations pads and truncates by line index', () {
    expect(resizeTranslations(['a'], 3), ['a', '', '']);
    expect(resizeTranslations(['a', 'b', 'c'], 2), ['a', 'b']);
    expect(resizeTranslations(const [], 0), isEmpty);
  });

  test('parseKeywords trims, drops empties and duplicates', () {
    expect(parseKeywords(' love, Family ,,love , family, sun'), ['love', 'Family', 'sun']);
    expect(parseKeywords(''), isEmpty);
  });

  group('retimeLine', () {
    const lrc = '[ti:Demo]\n[00:01.00]one\n[00:05.00]two\n[00:09.00]three\n[00:12.00]\n';

    List<Duration> starts(String text) => [for (final l in LrcParser.parse(text).lines) l.start];

    test('sets the start of one line and keeps tags, text and end marker', () {
      final out = retimeLine(lrc, 1, const Duration(milliseconds: 4321));
      final doc = LrcParser.parse(out);
      expect(doc.tags['ti'], 'Demo');
      expect(doc.lines.map((l) => l.text), ['one', 'two', 'three']);
      expect(starts(out), const [
        Duration(seconds: 1),
        Duration(milliseconds: 4320),
        Duration(seconds: 9),
      ]);
      expect(doc.end, const Duration(seconds: 12));
      expect(out, contains('[00:04.32]two'));
    });

    test('keeps line order by pushing later lines and pulling earlier ones', () {
      final pushed = retimeLine(lrc, 0, const Duration(seconds: 10));
      expect(LrcParser.parse(pushed).lines.map((l) => l.text), ['one', 'two', 'three']);
      expect(starts(pushed), const [
        Duration(seconds: 10),
        Duration(milliseconds: 10010),
        Duration(milliseconds: 10020),
      ]);
      final pulled = retimeLine(lrc, 2, const Duration(milliseconds: 500));
      expect(LrcParser.parse(pulled).lines.map((l) => l.text), ['one', 'two', 'three']);
      expect(starts(pulled), const [
        Duration(milliseconds: 480),
        Duration(milliseconds: 490),
        Duration(milliseconds: 500),
      ]);
    });

    test('drops an end marker that is no longer after the last line', () {
      final out = retimeLine(lrc, 2, const Duration(seconds: 13));
      expect(LrcParser.parse(out).end, isNull);
    });

    test('applies a previous offset once and does not re-write the offset tag', () {
      final out = retimeLine(
        '[offset:500]\n[00:02.00]a\n[00:04.00]b\n',
        1,
        const Duration(seconds: 6),
      );
      expect(out, isNot(contains('offset')));
      expect(starts(out), const [Duration(milliseconds: 1500), Duration(seconds: 6)]);
    });

    test('out-of-range index returns the text unchanged', () {
      expect(retimeLine(lrc, 5, Duration.zero), lrc);
      expect(retimeLine(lrc, -1, Duration.zero), lrc);
    });
  });

  group('validateDraft', () {
    test('valid draft passes without warnings', () {
      final v = validateDraft(_draft());
      expect(v.ok, isTrue);
      expect(v.warnings, isEmpty);
    });

    test('required fields', () {
      final v = validateDraft(_draft(title: ' ', artist: '', license: '', audio: ''));
      expect(v.ok, isFalse);
      expect(v.errors, hasLength(4));
      expect(v.errors.join(' '), contains('giấy phép'));
    });

    test('LRC must contain at least one timed line', () {
      final v = validateDraft(_draft(lrc: 'no timestamps here', translations: const []));
      expect(v.errors.single, contains('LRC'));
    });

    test('translation count must equal line count; empty ones only warn', () {
      expect(
        validateDraft(_draft(translations: const ['một'])).errors.single,
        contains('Số bản dịch'),
      );
      final v = validateDraft(_draft(translations: const ['một', ' ']));
      expect(v.ok, isTrue);
      expect(v.warnings.single, contains('1/2'));
    });

    test('media references: http(s) URL or local path, other schemes rejected', () {
      expect(mediaRefError('https://x.com/a.mp3', required: true, label: 'x'), isNull);
      expect(mediaRefError('/data/user/0/a.mp3', required: true, label: 'x'), isNull);
      expect(mediaRefError('ftp://x/a.mp3', required: true, label: 'x'), isNotNull);
      expect(mediaRefError('https://', required: true, label: 'x'), isNotNull);
      expect(mediaRefError('', required: false, label: 'x'), isNull);
      expect(validateDraft(_draft(cover: 'ftp://x/c.png')).ok, isFalse);
    });

    test('toSong copies form values and keeps base-only fields', () {
      final song = _draft(cover: ' ').toSong('demo-1234', durationMs: 1000);
      expect(song.id, 'demo-1234');
      expect(song.cover, isNull);
      expect(song.lrcText, contains('[00:01.00]one'));
      expect(song.translations, ['một', 'hai']);
      expect(song.durationMs, 1000);
      expect(song.bundled, isFalse);
    });
  });

  group('AdminMediaStore (local mode)', () {
    late Directory docs;
    setUp(() async => docs = await Directory.systemTemp.createTemp('admin_media_'));
    tearDown(() => docs.delete(recursive: true));

    test('copies picked files into admin_media/<songId>_<name>, leaves URLs alone', () async {
      final picked = File('${docs.path}/picked.mp3')..writeAsStringSync('audio');
      final store = AdminMediaStore(documentsDir: () async => docs);
      final stored = await store.persist(picked.path, 'song-1');
      expect(stored.replaceAll('\\', '/'), endsWith('/admin_media/song-1_picked.mp3'));
      expect(File(stored).readAsStringSync(), 'audio');
      // Persisting the stored copy again is a no-op.
      expect(await store.persist(stored, 'song-1'), stored);
      expect(await store.persist('https://x.com/a.mp3', 'song-1'), 'https://x.com/a.mp3');
      expect(await store.persist('assets/audio/a.mp3', 'song-1'), 'assets/audio/a.mp3');
    });
  });
}
