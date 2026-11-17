import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/text/text_utils.dart';
import 'package:singlearn/features/songs/domain/lrc_parser.dart';
import 'package:singlearn/features/songs/domain/song.dart';
import 'package:singlearn/features/vocabulary/domain/dictionary.dart';

/// Validates the bundled library against the outline requirements.
void main() {
  final catalog =
      jsonDecode(File('assets/content/catalog.json').readAsStringSync()) as Map;
  final songs = [
    for (final s in catalog['songs'] as List)
      Song.fromJson(Map<String, dynamic>.from(s as Map), bundled: true),
  ];
  final dict = SongDictionary.fromJsonString(
      File('assets/content/dictionary.json').readAsStringSync());

  test('demo catalog (8+ real recordings) covering A1-B2 with topics and genres', () {
    expect(songs.length, greaterThanOrEqualTo(8));
    expect(songs.map((s) => s.level).toSet(), containsAll(cefrLevels));
    for (final s in songs) {
      expect(s.topics, isNotEmpty);
      for (final t in s.topics) {
        expect(topicLabels.keys, contains(t));
      }
      expect(genreLabels.keys, contains(s.genre));
      // Lyrics are public domain; the recording is either the group's own
      // CC BY 4.0 track or a public-domain recording credited with its source.
      expect(s.license, contains('public domain'));
      expect(
        s.license.contains('CC BY 4.0') ||
            (s.license.contains('Public domain') && s.license.contains('https://commons.wikimedia.org/')),
        isTrue,
        reason: '${s.id}: recording licence/source missing',
      );
      expect(s.keywords.length, greaterThanOrEqualTo(5));
    }
  });

  for (final s in songs) {
    test('${s.id}: media, LRC/translation alignment, dictionary coverage', () {
      expect(File(s.audio).existsSync(), isTrue);
      expect(File(s.cover!).existsSync(), isTrue);
      final doc = LrcParser.parse(File(s.lrc).readAsStringSync());
      expect(doc.lines.length, s.translations.length);
      expect(doc.lines.length, inInclusiveRange(8, 16));
      for (var i = 1; i < doc.lines.length; i++) {
        expect(doc.lines[i].start, greaterThan(doc.lines[i - 1].start));
      }
      expect(doc.lines.last.start.inMilliseconds, lessThan(s.durationMs));
      for (final v in s.translations) {
        expect(v.trim(), isNotEmpty);
      }
      for (final l in doc.lines) {
        for (final w in wordsOf(l.text)) {
          expect(dict.lookup(w).found, isTrue, reason: 'missing "$w" in ${s.id}');
        }
      }
      for (final k in s.keywords) {
        expect(dict.lookup(k).found, isTrue, reason: 'keyword $k');
      }
    });
  }
}
