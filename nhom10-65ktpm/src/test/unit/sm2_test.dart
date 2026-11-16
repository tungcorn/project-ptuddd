import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/features/vocabulary/domain/sm2.dart';

void main() {
  final now = DateTime(2026, 11, 16, 9);
  Sm2State fresh() => Sm2State(dueAt: now);

  test('intervals follow 1, 6, round(I*EF) for good answers', () {
    var s = Sm2.review(fresh(), ReviewGrade.good.quality, now);
    expect(s.intervalDays, 1);
    expect(s.repetitions, 1);
    expect(s.easeFactor, 2.5); // q=4 keeps EF
    s = Sm2.review(s, 4, now);
    expect(s.intervalDays, 6);
    s = Sm2.review(s, 4, now);
    expect(s.intervalDays, 15); // 6 * 2.5
    expect(s.dueAt, now.add(const Duration(days: 15)));
  });

  test('easy raises EF by 0.1, hard lowers it by 0.14', () {
    expect(Sm2.review(fresh(), 5, now).easeFactor, closeTo(2.6, 1e-9));
    expect(Sm2.review(fresh(), 3, now).easeFactor, closeTo(2.36, 1e-9));
  });

  test('forgot resets repetitions, interval 1 day, EF floor 1.3', () {
    var s = Sm2State(easeFactor: 1.4, intervalDays: 20, repetitions: 5, dueAt: now);
    s = Sm2.review(s, ReviewGrade.forgot.quality, now);
    expect(s.repetitions, 0);
    expect(s.intervalDays, 1);
    expect(s.easeFactor, 1.3);
    expect(s.isDue(now), isFalse);
    expect(s.isDue(now.add(const Duration(days: 1))), isTrue);
  });

  test('grades map to qualities 1/3/4/5', () {
    expect(ReviewGrade.values.map((g) => g.quality), [1, 3, 4, 5]);
    expect(ReviewGrade.forgot.isCorrect, isFalse);
    expect(ReviewGrade.hard.isCorrect, isTrue);
  });
}

