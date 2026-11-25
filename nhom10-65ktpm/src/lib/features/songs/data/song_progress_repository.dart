import '../../../core/storage/local_store.dart';
import '../../../core/sync/sync_service.dart';

/// Per-user progress on one song (`users/{uid}/songProgress/{songId}`).
class SongProgress {
  const SongProgress({
    required this.songId,
    this.listens = 0,
    this.bestExerciseScore = 0,
    this.bestPronunciationScore = 0,
    this.lineBestScores = const {},
    this.favorite = false,
    this.favoriteAt = 0,
    this.lastStudiedAt = 0,
    this.updatedAt = 0,
  });

  final String songId;
  final int listens;

  /// Best exercise result in percent (0–100).
  final int bestExerciseScore;

  /// Best average pronunciation score of the song (0–100).
  final int bestPronunciationScore;

  /// Best pronunciation score per lyric line index.
  final Map<int, int> lineBestScores;
  final bool favorite;

  /// When [favorite] was last changed (ms), 0 if never: merging devices
  /// keeps the latest change instead of the default of a new install.
  final int favoriteAt;
  final int lastStudiedAt;
  final int updatedAt;

  bool get started =>
      listens > 0 || bestExerciseScore > 0 || lineBestScores.isNotEmpty;

  factory SongProgress.fromJson(Map<String, dynamic> j) => SongProgress(
        songId: j['id'] as String,
        listens: (j['listens'] as num?)?.toInt() ?? 0,
        bestExerciseScore: (j['bestExerciseScore'] as num?)?.toInt() ?? 0,
        bestPronunciationScore:
            (j['bestPronunciationScore'] as num?)?.toInt() ?? 0,
        lineBestScores: {
          for (final e in (j['lineBestScores'] as Map? ?? const {}).entries)
            int.parse(e.key.toString()): (e.value as num).toInt(),
        },
        favorite: j['favorite'] as bool? ?? false,
        favoriteAt: (j['favoriteAt'] as num?)?.toInt() ?? 0,
        lastStudiedAt: (j['lastStudiedAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  /// Combines two versions of the same song progress from different devices
  /// (sync merge rule of `users/{uid}/songProgress`), so progress made on a
  /// new device before its first download never lowers the cloud progress:
  /// counters, best scores and dates take the highest value, per lyric line
  /// too; `favorite` follows the later toggle ([favoriteAt]; set on either
  /// side when both changed in the same instant or never).
  ///
  /// Listens made offline on two devices are not added up: the larger count
  /// is kept. Order-independent and idempotent.
  static Map<String, dynamic> mergeJson(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final a = SongProgress.fromJson(current);
    final b = SongProgress.fromJson(incoming);
    int max(int x, int y) => x > y ? x : y;
    return SongProgress(
      songId: a.songId,
      listens: max(a.listens, b.listens),
      bestExerciseScore: max(a.bestExerciseScore, b.bestExerciseScore),
      bestPronunciationScore: max(
        a.bestPronunciationScore,
        b.bestPronunciationScore,
      ),
      lineBestScores: {
        for (final line in {...a.lineBestScores.keys, ...b.lineBestScores.keys})
          line: max(a.lineBestScores[line] ?? 0, b.lineBestScores[line] ?? 0),
      },
      favorite: a.favoriteAt == b.favoriteAt
          ? a.favorite || b.favorite
          : (a.favoriteAt > b.favoriteAt ? a.favorite : b.favorite),
      favoriteAt: max(a.favoriteAt, b.favoriteAt),
      lastStudiedAt: max(a.lastStudiedAt, b.lastStudiedAt),
      updatedAt: max(a.updatedAt, b.updatedAt),
    ).toJson();
  }

  Map<String, dynamic> toJson() => {
        'id': songId,
        'listens': listens,
        'bestExerciseScore': bestExerciseScore,
        'bestPronunciationScore': bestPronunciationScore,
        'lineBestScores': {
          for (final e in lineBestScores.entries) e.key.toString(): e.value,
        },
        'favorite': favorite,
        'favoriteAt': favoriteAt,
        'lastStudiedAt': lastStudiedAt,
        'updatedAt': updatedAt,
      };
}

class SongProgressRepository {
  SongProgressRepository(this._store, this._sync, this.uid);

  final LocalStore _store;
  final SyncService _sync;
  final String uid;

  String get _box => 'song_progress_$uid';

  Future<Map<String, SongProgress>> all() async => {
        for (final e in (await _store.entries(_box)).entries)
          e.key: SongProgress.fromJson(e.value),
      };

  Future<SongProgress> get(String songId) async {
    final j = await _store.get(_box, songId);
    return j == null ? SongProgress(songId: songId) : SongProgress.fromJson(j);
  }

  Stream<void> watch() => _store.watch(_box);

  Future<SongProgress> _update(
    String songId,
    Map<String, dynamic> Function(Map<String, dynamic> current) change,
  ) async {
    final current = (await get(songId)).toJson();
    final next = change(current)
      ..['id'] = songId
      ..['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _store.put(_box, songId, next);
    if (!uid.startsWith('guest')) {
      await _sync.enqueue('users/$uid/songProgress/$songId', next);
    }
    return SongProgress.fromJson(next);
  }

  Future<SongProgress> toggleFavorite(String songId) =>
      _update(
        songId,
        (c) => c
          ..['favorite'] = !(c['favorite'] as bool? ?? false)
          ..['favoriteAt'] = DateTime.now().millisecondsSinceEpoch,
      );

  Future<SongProgress> recordListen(String songId) => _update(
        songId,
        (c) => c
          ..['listens'] = ((c['listens'] as num?)?.toInt() ?? 0) + 1
          ..['lastStudiedAt'] = DateTime.now().millisecondsSinceEpoch,
      );

  Future<SongProgress> recordExercise(String songId, int percent) => _update(
        songId,
        (c) => c
          ..['bestExerciseScore'] =
              percent > ((c['bestExerciseScore'] as num?)?.toInt() ?? 0)
                  ? percent
                  : c['bestExerciseScore']
          ..['lastStudiedAt'] = DateTime.now().millisecondsSinceEpoch,
      );

  /// Stores the best score of a line and recomputes the song average.
  Future<SongProgress> recordPronunciation(
    String songId,
    int lineIndex,
    int score, {
    required int lineCount,
  }) =>
      _update(songId, (c) {
        final lines = Map<String, dynamic>.from(c['lineBestScores'] as Map? ?? {});
        final prev = (lines['$lineIndex'] as num?)?.toInt() ?? 0;
        if (score > prev) lines['$lineIndex'] = score;
        final avg = lineCount == 0
            ? 0
            : (lines.values.fold<int>(0, (a, v) => a + (v as num).toInt()) / lineCount)
                .round();
        final best = (c['bestPronunciationScore'] as num?)?.toInt() ?? 0;
        return c
          ..['lineBestScores'] = lines
          ..['bestPronunciationScore'] = avg > best ? avg : best
          ..['lastStudiedAt'] = DateTime.now().millisecondsSinceEpoch;
      });

  Future<void> pull() => _sync.pull('users/$uid/songProgress', _box);
}
