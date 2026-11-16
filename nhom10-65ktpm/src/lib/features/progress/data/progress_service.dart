import 'dart:async';

import '../../../core/events/app_event_bus.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/sync/sync_service.dart';
import '../domain/progress_rules.dart';

/// XP awarded for one accepted event (for "+10 XP" feedback in the UI).
class XpAward {
  const XpAward(this.event, this.xp, this.newBadges, {this.levelUp});

  final LearningEvent event;
  final int xp;
  final List<AchievementBadge> newBadges;
  final int? levelUp;
}

/// One day of statistics for the weekly charts.
class DayStats {
  const DayStats({
    required this.day,
    this.xp = 0,
    this.wordsSaved = 0,
    this.listenSeconds = 0,
    this.pronunciationAvg,
    this.reviews = 0,
  });

  final DateTime day;
  final int xp;
  final int wordsSaved;
  final int listenSeconds;
  final double? pronunciationAvg;
  final int reviews;

  double get listenMinutes => listenSeconds / 60;
}

/// Aggregated progress of a user.
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.totalXp,
    required this.level,
    required this.streak,
    required this.longestStreak,
    required this.badges,
    required this.wordsSaved,
    required this.exercisesDone,
    required this.week,
    required this.todayXp,
    required this.weekXp,
    required this.activeToday,
  });

  final int totalXp;
  final LevelInfo level;
  final int streak;
  final int longestStreak;
  final Map<AchievementBadge, DateTime> badges;
  final int wordsSaved;
  final int exercisesDone;

  /// Last 7 days, oldest first.
  final List<DayStats> week;
  final int todayXp;

  /// XP earned in the current ISO week (Monday–Sunday) for the leaderboard.
  final int weekXp;
  final bool activeToday;
}

/// Progress module (M4). Consumes learning events, keeps an idempotent XP
/// ledger (`xp_ledger_{uid}`; Firestore `users/{uid}/xpEvents/{eventId}`)
/// and derives XP, level, streak, badges and statistics from it.
class ProgressService {
  ProgressService({
    required this._store,
    required this._sync,
    required this.uid,
    this.onPublicProfileChanged,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final LocalStore _store;
  final SyncService _sync;
  final DateTime Function() _now;
  final String uid;

  /// Called after each accepted event with fresh public stats (XP, weekly
  /// XP, level, streak) so the social module can update leaderboards.
  final Future<void> Function(ProgressSnapshot snapshot)? onPublicProfileChanged;

  final _awards = StreamController<XpAward>.broadcast();

  Stream<XpAward> get awards => _awards.stream;

  String get _ledgerBox => 'xp_ledger_$uid';
  String get _badgeBox => 'badges_$uid';
  bool get _syncs => !uid.startsWith('guest');

  Stream<void> watch() => _store.watch(_ledgerBox);

  /// Records [event] once. Returns the XP awarded, or null if the event id
  /// was already in the ledger (duplicate/retry).
  Future<int?> record(LearningEvent event) {
    // Serialize: the duplicate check and the write must not interleave.
    final next = _tail.then((_) => _record(event));
    _tail = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _tail = Future.value();

  Future<int?> _record(LearningEvent event) async {
    if (event.uid != uid) return null;
    if (await _store.get(_ledgerBox, event.id) != null) return null;
    final before = await snapshot();
    final xp = XpRules.xpFor(event);
    final entry = {
      'id': event.id,
      'type': event.type.name,
      'xp': xp,
      'at': event.at.millisecondsSinceEpoch,
      'day': dayKey(event.at),
      'data': event.data,
      'updatedAt': _now().millisecondsSinceEpoch,
    };
    await _store.put(_ledgerBox, event.id, entry);
    if (_syncs) await _sync.enqueue('users/$uid/xpEvents/${event.id}', entry);

    final after = await snapshot();
    final newBadges = await _unlockBadges(after);
    final finalSnap = newBadges.isEmpty ? after : await snapshot();
    await onPublicProfileChanged?.call(finalSnap);
    _awards.add(XpAward(
      event,
      xp,
      newBadges,
      levelUp: after.level.level > before.level.level ? after.level.level : null,
    ));
    return xp;
  }

  Future<List<Map<String, dynamic>>> _ledger() => _store.values(_ledgerBox);

  Future<List<AchievementBadge>> _unlockBadges(ProgressSnapshot s) async {
    final ledger = await _ledger();
    int count(String type, [bool Function(Map<String, dynamic>)? where]) => ledger
        .where((e) => e['type'] == type && (where == null || where(e)))
        .length;
    Map<String, dynamic> data(Map<String, dynamic> e) =>
        Map<String, dynamic>.from(e['data'] as Map? ?? const {});

    final earned = <AchievementBadge>{
      if (count(LearningEventType.songListened.name,
                  (e) => data(e)['completed'] == true) >
              0 ||
          count(LearningEventType.fillBlankCompleted.name) +
                  count(LearningEventType.exerciseCompleted.name) >
              0)
        AchievementBadge.firstSong,
      if (s.wordsSaved >= 10) AchievementBadge.words10,
      if (s.wordsSaved >= 100) AchievementBadge.words100,
      if (s.longestStreak >= 3) AchievementBadge.streak3,
      if (s.longestStreak >= 7) AchievementBadge.streak7,
      if (count(LearningEventType.pronunciationScored.name,
              (e) => ((data(e)['score'] as num?) ?? 0) >= 90) >=
          10)
        AchievementBadge.goldenVoice,
      if (s.exercisesDone >= 10) AchievementBadge.diligent,
      if (count(LearningEventType.flashcardReviewed.name,
              (e) => ((data(e)['quality'] as num?) ?? 0) >= 3) >=
          50)
        AchievementBadge.reviewer,
      if (count(LearningEventType.challengeCompleted.name,
              (e) => data(e)['won'] == true) >
          0)
        AchievementBadge.challenger,
    };
    final fresh = <AchievementBadge>[];
    for (final b in earned) {
      if (await _store.get(_badgeBox, b.name) == null) {
        final doc = {
          'id': b.name,
          'at': _now().millisecondsSinceEpoch,
          'updatedAt': _now().millisecondsSinceEpoch,
        };
        await _store.put(_badgeBox, b.name, doc);
        if (_syncs) await _sync.enqueue('users/$uid/badges/${b.name}', doc);
        fresh.add(b);
      }
    }
    return fresh;
  }

  Future<ProgressSnapshot> snapshot() async {
    final ledger = await _ledger();
    final now = _now();
    final today = dayKey(now);
    var total = 0, todayXp = 0, weekXp = 0, words = 0, exercises = 0;
    final activeDays = <String>{};
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];
    final perDay = {for (final d in days) dayKey(d): <Map<String, dynamic>>[]};

    for (final e in ledger) {
      final xp = (e['xp'] as num).toInt();
      final day = e['day'] as String;
      final at = DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt());
      total += xp;
      activeDays.add(day);
      if (day == today) todayXp += xp;
      if (!at.isBefore(weekStart)) weekXp += xp;
      final type = e['type'];
      if (type == LearningEventType.wordSaved.name) words++;
      if (type == LearningEventType.fillBlankCompleted.name ||
          type == LearningEventType.exerciseCompleted.name) {
        exercises++;
      }
      perDay[day]?.add(e);
    }

    final week = [
      for (final d in days)
        () {
          final list = perDay[dayKey(d)]!;
          var xp = 0, w = 0, listen = 0, reviews = 0;
          final pron = <int>[];
          for (final e in list) {
            xp += (e['xp'] as num).toInt();
            final data = Map<String, dynamic>.from(e['data'] as Map? ?? const {});
            switch (e['type']) {
              case 'wordSaved':
                w++;
              case 'songListened':
                listen += (data['seconds'] as num?)?.toInt() ?? 0;
              case 'pronunciationScored':
                pron.add((data['score'] as num?)?.toInt() ?? 0);
              case 'flashcardReviewed':
                reviews++;
            }
          }
          return DayStats(
            day: d,
            xp: xp,
            wordsSaved: w,
            listenSeconds: listen,
            reviews: reviews,
            pronunciationAvg:
                pron.isEmpty ? null : pron.reduce((a, b) => a + b) / pron.length,
          );
        }(),
    ];

    final badges = <AchievementBadge, DateTime>{};
    for (final e in (await _store.entries(_badgeBox)).entries) {
      final b = AchievementBadge.values.where((x) => x.name == e.key);
      if (b.isNotEmpty) {
        badges[b.first] =
            DateTime.fromMillisecondsSinceEpoch((e.value['at'] as num).toInt());
      }
    }

    return ProgressSnapshot(
      totalXp: total,
      level: LevelInfo.fromXp(total),
      streak: StreakCalculator.current(activeDays, now),
      longestStreak: StreakCalculator.longest(activeDays),
      badges: badges,
      wordsSaved: words,
      exercisesDone: exercises,
      week: week,
      todayXp: todayXp,
      weekXp: weekXp,
      activeToday: activeDays.contains(today),
    );
  }

  /// Pulls the ledger and badges from Firestore (cloud mode).
  Future<void> pull() async {
    await _sync.pull('users/$uid/xpEvents', _ledgerBox);
    await _sync.pull('users/$uid/badges', _badgeBox);
  }

  Future<void> dispose() => _awards.close();
}
