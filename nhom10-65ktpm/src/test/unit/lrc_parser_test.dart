import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/songs/data/song_repository.dart';
import 'package:singlearn/features/songs/domain/lrc_parser.dart';
import 'package:singlearn/features/songs/domain/song.dart';

void main() {
  group('LrcParser', () {
    test('parses tags, timestamps with 1-3 fractional digits and sorts', () {
      final doc = LrcParser.parse('''
[ti:Song]
[ar:Someone]
[00:10.5]third
[00:01.00]first
[00:05.250]second

garbage line
[00:20.00]
''');
      expect(doc.tags['ti'], 'Song');
      expect(doc.lines.map((l) => l.text), ['first', 'second', 'third']);
      expect(doc.lines[0].start, const Duration(seconds: 1));
      expect(doc.lines[1].start, const Duration(seconds: 5, milliseconds: 250));
      expect(doc.lines[2].start, const Duration(seconds: 10, milliseconds: 500));
      expect(doc.end, const Duration(seconds: 20));
    });

    test('expands multiple timestamps on one line', () {
      final doc = LrcParser.parse('[00:01.00][00:30.00]Chorus\n[00:10.00]Verse');
      expect(doc.lines.map((l) => l.text), ['Chorus', 'Verse', 'Chorus']);
    });

    test('applies offset tag (positive = earlier) without going negative', () {
      final doc = LrcParser.parse('[offset:500]\n[00:00.20]a\n[00:02.00]b');
      expect(doc.lines[0].start, Duration.zero);
      expect(doc.lines[1].start, const Duration(milliseconds: 1500));
    });

    test('activeIndex finds the current line by binary search', () {
      final starts = [1, 5, 10].map((s) => Duration(seconds: s)).toList();
      expect(LrcParser.activeIndex(starts, Duration.zero), -1);
      expect(LrcParser.activeIndex(starts, const Duration(seconds: 1)), 0);
      expect(LrcParser.activeIndex(starts, const Duration(milliseconds: 9999)), 1);
      expect(LrcParser.activeIndex(starts, const Duration(minutes: 3)), 2);
    });

    test('format round-trips', () {
      const d = Duration(minutes: 1, seconds: 2, milliseconds: 340);
      expect(LrcParser.format(d), '[01:02.34]');
      expect(LrcParser.parse('${LrcParser.format(d)}x').lines.single.start, d);
    });
  });

  test('buildLyrics merges translations and computes line ends', () {
    const song = Song(
      id: 's', title: 't', artist: 'a', level: 'A1', topics: [], genre: 'folk',
      durationMs: 30000, audio: 'assets/a.mp3', translations: ['một', 'hai'],
    );
    final lyrics = SongRepository.buildLyrics(
      song,
      LrcParser.parse('[00:01.00]one\n[00:04.00]two\n[00:08.00]three'),
    );
    expect(lyrics.lines.length, 3);
    expect(lyrics.lines[0].end, const Duration(seconds: 4));
    expect(lyrics.lines[1].vi, 'hai');
    expect(lyrics.lines[2].vi, '');
    expect(lyrics.lines[2].end, const Duration(seconds: 30));
  });
}
