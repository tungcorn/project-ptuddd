import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/text/text_utils.dart';
import 'package:singlearn/features/practice/domain/exercises.dart';
import 'package:singlearn/features/songs/domain/song.dart';

SongLyrics lyrics() {
  const texts = [
    'Twinkle, twinkle, little star,',
    'How I wonder what you are!',
    'Up above the world so high,',
    'Like a diamond in the sky.',
    'When the blazing sun is gone,',
    'Then you show your little light,',
  ];
  return SongLyrics('s', [
    for (var i = 0; i < texts.length; i++)
      LyricLine(
        index: i,
        start: Duration(seconds: i * 4),
        end: Duration(seconds: i * 4 + 4),
        en: texts[i],
        vi: 'nghĩa $i',
      ),
  ]);
}

void main() {
  final total = lyrics().lines.expand((l) => wordsOf(l.en)).length;

  for (final d in BlankDifficulty.values) {
    test('fill blank ${d.name} hides ${d.ratio * 100}% of words', () {
      final ex = ExerciseGenerator(Random(1)).fillBlank(lyrics(), d);
      expect(ex.blanks.length, max(1, (total * d.ratio).round()));
      for (final b in ex.blanks) {
        final tok = tokenizeLine(lyrics().lines[b.lineIndex].en)[b.tokenIndex];
        expect(tok.isWord, isTrue);
        expect(tok.text, b.answer);
        expect(b.options, contains(normalizeWord(b.answer)));
        expect(b.options.toSet().length, b.options.length);
        expect(b.check(b.answer.toUpperCase()), isTrue);
        expect(b.check('zzz'), isFalse);
      }
    });
  }

  test('easy level prefers content words', () {
    final ex = ExerciseGenerator(Random(3)).fillBlank(lyrics(), BlankDifficulty.easy);
    for (final b in ex.blanks) {
      expect(b.answer.length, greaterThanOrEqualTo(3));
    }
  });

  test('line order shuffles and scores positions', () {
    final ex = ExerciseGenerator(Random(2)).lineOrder(lyrics(), count: 4);
    expect(ex.correct.length, 4);
    expect(ex.score(ex.correct), 4);
    expect(ex.score(ex.shuffled), lessThan(4));
  });

  test('word order checks the rebuilt sentence', () {
    final ex = ExerciseGenerator(Random(5)).wordOrder(lyrics())!;
    expect(ex.check(ex.words), isTrue);
    expect(ex.check(ex.tiles), isFalse);
  });

  test('meaning quiz has one correct option per question', () {
    final qs = ExerciseGenerator(Random(4)).meaningQuiz(
      lyrics(),
      keywordMeanings: {'star': 'ngôi sao', 'sky': 'bầu trời', 'light': 'ánh sáng', 'sun': 'mặt trời'},
    );
    expect(qs, isNotEmpty);
    for (final q in qs) {
      expect(q.options.length, inInclusiveRange(3, 4));
      expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
      expect(q.options.toSet().length, q.options.length);
    }
  });
}
