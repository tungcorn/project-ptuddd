import '../../../core/events/app_event_bus.dart';

/// XP rules (section 7.11 of the outline) plus the policies the outline left
/// open, decided here and documented in the README:
///
/// * save a word: +10, once per lemma (event id `word:{lemma}`);
/// * finish a fill-in-the-blank session: +20, once per song × difficulty per
///   day (replaying the same session/day does not earn again);
/// * pronunciation >= 70: +5 per line, once per song line per day;
/// * correct flashcard review (grade >= 3): +5, once per word per day;
/// * other exercises (ordering / quiz): +10, once per song × kind per day;
/// * finishing a "guess the song" challenge: +10 (+10 bonus for a win);
/// * listening time: 0 XP, counted for streak and statistics.
class XpRules {
  static const saveWord = 10;
  static const fillBlank = 20;
  static const pronunciationLine = 5;
  static const pronunciationThreshold = 70;
  static const reviewCorrect = 5;
  static const exercise = 10;
  static const challenge = 10;
  static const challengeWinBonus = 10;

  static int xpFor(LearningEvent e) {
    switch (e.type) {
      case LearningEventType.wordSaved:
        return saveWord;
      case LearningEventType.fillBlankCompleted:
        return fillBlank;
      case LearningEventType.exerciseCompleted:
        return exercise;
      case LearningEventType.pronunciationScored:
        final score = (e.data['score'] as num?)?.toInt() ?? 0;
        return score >= pronunciationThreshold ? pronunciationLine : 0;
      case LearningEventType.flashcardReviewed:
        final q = (e.data['quality'] as num?)?.toInt() ?? 0;
        return q >= 3 ? reviewCorrect : 0;
      case LearningEventType.songListened:
        return 0;
      case LearningEventType.challengeCompleted:
        return challenge + ((e.data['won'] as bool? ?? false) ? challengeWinBonus : 0);
    }
  }
}

/// Level n → n+1 needs 100·n XP, so reaching level L needs 50·L·(L−1) XP.
class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  final int level;
  final int xpIntoLevel;
  final int xpForNext;

  double get progress => xpForNext == 0 ? 0 : xpIntoLevel / xpForNext;

  static int totalXpToReach(int level) => 50 * level * (level - 1);

  static LevelInfo fromXp(int xp) {
    var level = 1;
    while (xp >= totalXpToReach(level + 1)) {
      level++;
    }
    return LevelInfo(
      level: level,
      xpIntoLevel: xp - totalXpToReach(level),
      xpForNext: 100 * level,
    );
  }
}

/// Streak: consecutive local days with at least one learning activity,
/// ending today (or yesterday, if today has no activity yet).
class StreakCalculator {
  static int current(Set<String> activeDays, DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (!activeDays.contains(dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
      if (!activeDays.contains(dayKey(day))) return 0;
    }
    var streak = 0;
    while (activeDays.contains(dayKey(day))) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  static int longest(Set<String> activeDays) {
    final days = activeDays.map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }
}

/// Badge definitions.
enum AchievementBadge {
  firstSong('Bài hát đầu tiên', 'Nghe trọn một bài hát hoặc hoàn thành bài tập đầu tiên'),
  words10('10 từ', 'Lưu 10 từ vựng'),
  words100('100 từ', 'Lưu 100 từ vựng'),
  streak3('Chuỗi 3 ngày', 'Học 3 ngày liên tiếp'),
  streak7('Chuỗi 7 ngày', 'Học 7 ngày liên tiếp'),
  goldenVoice('Giọng ca vàng', 'Đạt từ 90 điểm phát âm ở 10 câu'),
  diligent('Chăm chỉ', 'Hoàn thành 10 phiên bài tập'),
  reviewer('Ôn tập bền bỉ', 'Ôn đúng 50 lượt flashcard'),
  challenger('Thách đấu', 'Thắng một thử thách “Đoán tên bài hát”');

  const AchievementBadge(this.title, this.description);

  final String title;
  final String description;
}
