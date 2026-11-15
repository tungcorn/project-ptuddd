import 'dart:math' as math;

/// Review buttons and their SM-2 quality grades (section 7.9 of the outline).
enum ReviewGrade {
  forgot(1, 'Quên'),
  hard(3, 'Khó'),
  good(4, 'Nhớ'),
  easy(5, 'Dễ');

  const ReviewGrade(this.quality, this.label);

  final int quality;
  final String label;

  /// Grades >= 3 count as a successful recall.
  bool get isCorrect => quality >= 3;
}

/// Spaced-repetition state of one card.
class Sm2State {
  const Sm2State({
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    required this.dueAt,
  });

  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueAt;

  bool isDue(DateTime now) => !dueAt.isAfter(now);
}

/// SuperMemo-2 scheduling (Wozniak, 1990).
///
/// * q < 3: the card is relearned — repetitions reset, interval 1 day.
/// * q >= 3: interval 1, then 6, then round(previous interval × EF).
/// * EF' = EF + (0.1 − (5 − q)(0.08 + (5 − q)·0.02)), never below 1.3.
class Sm2 {
  static const double minEase = 1.3;

  static Sm2State review(Sm2State s, int quality, DateTime now) {
    assert(quality >= 0 && quality <= 5);
    final q = quality.clamp(0, 5);
    var ef = s.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    ef = math.max(minEase, ef);

    int reps;
    int interval;
    if (q < 3) {
      reps = 0;
      interval = 1;
    } else {
      reps = s.repetitions + 1;
      if (reps == 1) {
        interval = 1;
      } else if (reps == 2) {
        interval = 6;
      } else {
        interval = (s.intervalDays * ef).round();
      }
    }
    return Sm2State(
      easeFactor: double.parse(ef.toStringAsFixed(4)),
      intervalDays: interval,
      repetitions: reps,
      dueAt: now.add(Duration(days: interval)),
    );
  }
}
