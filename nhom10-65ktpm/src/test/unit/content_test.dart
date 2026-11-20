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
    File('assets/content/dictionary.json').readAsStringSync(),
  );

  const learningSources = {
    'coffee-learning-clip': 'https://www.joshwoodward.com/song/Coffee',
    'learn-to-fly-learning-clip':
        'https://www.joshwoodward.com/song/LearnToFly',
    'little-tomcat-learning-clip':
        'https://www.joshwoodward.com/song/LittleTomcat',
  };

  test(
    'catalog retains eight originals and adds three licensed learning clips',
    () {
      expect(songs.length, greaterThanOrEqualTo(11));
      final ids = songs.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate song ids');
      expect(
        ids,
        containsAll([
          'silent-night',
          'my-bonnie-lies-over-the-ocean',
          'america-the-beautiful',
          'o-little-town-of-bethlehem',
          'take-me-out-to-the-ball-game',
          'amazing-grace',
          'danny-boy',
          'hark-the-herald-angels-sing',
          ...learningSources.keys,
        ]),
      );
      expect(songs.map((s) => s.level).toSet(), containsAll(cefrLevels));
      for (final s in songs) {
        expect(s.topics, isNotEmpty);
        for (final t in s.topics) {
          expect(topicLabels.keys, contains(t));
        }
        expect(genreLabels.keys, contains(s.genre));
        if (learningSources.containsKey(s.id)) {
          // These originals license both lyrics/composition and recording;
          // they must not be described as public domain.
          expect(s.license, contains('lời và nhạc CC BY 4.0'));
          expect(s.license, contains('Bản thu: Josh Woodward — CC BY 4.0'));
          expect(s.license, contains(learningSources[s.id]!));
          expect(
            s.license,
            contains('https://creativecommons.org/licenses/by/4.0/'),
          );
          expect(s.license.toLowerCase(), isNot(contains('public domain')));
          expect(s.license, contains('không phải toàn bộ bài hát'));
          expect(s.license, contains('dịch tiếng Việt'));
          expect(s.license, contains('cắt đoạn, chuyển mã'));
          expect(s.title, endsWith('(đoạn học)'));
        } else {
          expect(s.license, contains('public domain'));
          expect(
            s.license.contains('CC BY 4.0') ||
                (s.license.contains('Public domain') &&
                    s.license.contains('https://commons.wikimedia.org/')),
            isTrue,
            reason: '${s.id}: recording licence/source missing',
          );
        }
        expect(s.keywords.length, greaterThanOrEqualTo(5));
      }
    },
  );

  final clips = jsonDecode(
    File('../tools/learning_clips.json').readAsStringSync(),
  ) as List;
  test('learning manifest contains exactly the three credited sources', () {
    expect(
      clips.map((c) => (c as Map)['id']),
      unorderedEquals(learningSources.keys),
    );
  });
  for (final raw in clips) {
    final clip = raw as Map;
    final s = songs.singleWhere((s) => s.id == clip['id']);
    test('${s.id}: canonical lyrics, excerpt timing and attribution agree', () {
      final canonical = jsonDecode(
        File('assets/content/songs/${s.id}.json').readAsStringSync(),
      ) as Map;
      final lines = canonical['lines'] as List;
      final doc = LrcParser.parse(File(s.lrc).readAsStringSync());
      expect(doc.lines.map((l) => l.text), lines.map((l) => (l as Map)['en']));
      expect(s.translations, lines.map((l) => (l as Map)['vi']));
      for (final key in [
        'title',
        'artist',
        'level',
        'topics',
        'genre',
        'keywords',
      ]) {
        final entry = (catalog['songs'] as List).singleWhere(
          (e) => (e as Map)['id'] == s.id,
        ) as Map;
        expect(entry[key], canonical[key], reason: '$key in ${s.id}');
      }
      final start = (clip['startSec'] as num).toDouble();
      final end = (clip['endSec'] as num).toDouble();
      final starts = clip['lineStartsSec'] as List;
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      expect(s.durationMs, ((end - start) * 1000).round());
      expect(starts.length, lines.length);
      for (var i = 0; i < starts.length; i++) {
        final expectedMs = (((starts[i] as num) - start) * 1000).round();
        expect(doc.lines[i].start.inMilliseconds, closeTo(expectedMs, 10));
      }
      expect(
        doc.end!.inMilliseconds,
        closeTo(((clip['lineEndSec'] as num) - start) * 1000, 10),
      );
      expect(doc.end!, greaterThan(doc.lines.last.start));
      expect(doc.end!, lessThan(s.duration));
      expect(clip['sourceUrl'], learningSources[s.id]);
      expect(clip['license'], 'CC BY 4.0');
      expect(
        clip['licenseUrl'],
        'https://creativecommons.org/licenses/by/4.0/',
      );
      expect(clip['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
      final lemmas = {
        for (final l in doc.lines)
          for (final w in wordsOf(l.text)) dict.lookup(w).lemma,
      };
      expect(lemmas, containsAll(s.keywords));
      for (final lemma in lemmas) {
        expect(dict.entry(lemma)!.vi.trim(), isNotEmpty, reason: lemma);
        expect(dict.entry(lemma)!.ipa.trim(), isNotEmpty, reason: lemma);
      }
    });
  }

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
          expect(
            dict.lookup(w).found,
            isTrue,
            reason: 'missing "$w" in ${s.id}',
          );
        }
      }
      for (final k in s.keywords) {
        expect(dict.lookup(k).found, isTrue, reason: 'keyword $k');
      }
    });
  }
}
