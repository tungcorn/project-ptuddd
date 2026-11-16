import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/practice/domain/pronunciation_scorer.dart';

void main() {
  test('perfect match ignoring case and punctuation scores 100', () {
    final r = PronunciationScorer.score('Twinkle, twinkle, little star,', ['twinkle twinkle little star']);
    expect(r.score, 100);
    expect(r.rating, PronunciationRating.excellent);
    expect(r.marks.every((m) => m.correct), isTrue);
  });

  test('takes the best alternative', () {
    final r = PronunciationScorer.score('How I wonder what you are', [
      'how I wander what you',
      'how i wonder what you are',
    ]);
    expect(r.score, 100);
    expect(r.recognized, 'how i wonder what you are');
  });

  test('partial match gives a middle score and marks missing words', () {
    final r = PronunciationScorer.score('Up above the world so high', ['up above the girl']);
    expect(r.score, inInclusiveRange(40, 80));
    final missed = r.marks.where((m) => !m.correct).map((m) => m.word).toList();
    expect(missed, containsAll(['world', 'so', 'high']));
    expect(r.marks.first.correct, isTrue);
  });

  test('no recognition scores 0 and marks everything wrong', () {
    final r = PronunciationScorer.score('Row your boat', []);
    expect(r.score, 0);
    expect(r.rating, PronunciationRating.wrong);
    expect(r.marks.where((m) => m.correct), isEmpty);
  });

  test('rating bands', () {
    expect(PronunciationRating.of(90), PronunciationRating.excellent);
    expect(PronunciationRating.of(89), PronunciationRating.good);
    expect(PronunciationRating.of(70), PronunciationRating.good);
    expect(PronunciationRating.of(50), PronunciationRating.close);
    expect(PronunciationRating.of(49), PronunciationRating.wrong);
  });
}
