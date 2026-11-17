import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/features/progress/domain/progress_rules.dart';

LearningEvent ev(LearningEventType t, [Map<String, Object?> d = const {}]) =>
    LearningEvent(id: 'x', type: t, uid: 'u', data: d);

void main() {
  test('XP values follow the outline', () {
    expect(XpRules.xpFor(ev(LearningEventType.wordSaved)), 10);
    expect(XpRules.xpFor(ev(LearningEventType.fillBlankCompleted)), 20);
    expect(XpRules.xpFor(ev(LearningEventType.pronunciationScored, {'score': 70})), 5);
    expect(XpRules.xpFor(ev(LearningEventType.pronunciationScored, {'score': 69})), 0);
    expect(XpRules.xpFor(ev(LearningEventType.flashcardReviewed, {'quality': 4})), 5);
    expect(XpRules.xpFor(ev(LearningEventType.flashcardReviewed, {'quality': 1})), 0);
    expect(XpRules.xpFor(ev(LearningEventType.songListened, {'seconds': 60})), 0);
    expect(XpRules.xpFor(ev(LearningEventType.challengeCompleted, {'won': true})), 20);
  });

  test('level n -> n+1 needs 100*n XP', () {
    expect(LevelInfo.fromXp(0).level, 1);
    expect(LevelInfo.fromXp(99).level, 1);
    expect(LevelInfo.fromXp(100).level, 2); // 100 to reach 2
    expect(LevelInfo.fromXp(299).level, 2); // +200 to reach 3
    expect(LevelInfo.fromXp(300).level, 3);
    final l = LevelInfo.fromXp(350);
    expect(l.xpIntoLevel, 50);
    expect(l.xpForNext, 300);
  });

  group('streak', () {
    final now = DateTime(2026, 11, 16, 20);
    String k(int daysAgo) => dayKey(DateTime(2026, 11, 16 - daysAgo));

    test('counts consecutive days ending today', () {
      expect(StreakCalculator.current({k(0), k(1), k(2), k(4)}, now), 3);
    });
    test('today not yet active keeps yesterday streak', () {
      expect(StreakCalculator.current({k(1), k(2)}, now), 2);
    });
    test('gap of two days resets', () {
      expect(StreakCalculator.current({k(2), k(3)}, now), 0);
    });
    test('crosses month boundaries', () {
      final d = DateTime(2026, 12, 1, 8);
      expect(StreakCalculator.current({'2026-12-01', '2026-11-30', '2026-11-29'}, d), 3);
    });
    test('longest streak', () {
      expect(StreakCalculator.longest({k(0), k(1), k(5), k(6), k(7), k(8)}), 4);
    });
  });
}
