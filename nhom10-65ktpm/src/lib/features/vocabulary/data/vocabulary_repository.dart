import '../../../core/events/app_event_bus.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/text/text_utils.dart';
import '../domain/saved_word.dart';
import '../domain/sm2.dart';

/// Outcome of saving a word, so the UI can say what happened.
enum SaveWordOutcome {
  /// New flashcard created.
  created,

  /// The lemma was already saved; the new song line was added as context.
  contextAdded,

  /// Same lemma and same line already saved: nothing changed.
  alreadySaved,

  /// The card had been deleted earlier and is restored with a fresh schedule.
  restored,
}

/// Flashcard deck of one user: Hive box `words_{uid}` + Firestore
/// `users/{uid}/words/{wordId}` (soft delete with `isDeleted`).
class VocabularyRepository {
  VocabularyRepository({
    required this._store,
    required this._sync,
    required this._bus,
    required this.uid,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final LocalStore _store;
  final SyncService _sync;
  final AppEventBus _bus;
  final DateTime Function() _now;
  final String uid;

  String get _box => 'words_$uid';
  bool get _syncs => !uid.startsWith('guest');

  Stream<void> watch() => _store.watch(_box);

  /// Active (non-deleted) words, newest first.
  Future<List<SavedWord>> words() async {
    final list = [
      for (final j in await _store.values(_box)) SavedWord.fromJson(j),
    ].where((w) => !w.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<SavedWord?> byId(String id) async {
    final j = await _store.get(_box, normalizeWord(id));
    return j == null ? null : SavedWord.fromJson(j);
  }

  Future<bool> isSaved(String lemma) async {
    final w = await byId(lemma);
    return w != null && !w.isDeleted;
  }

  /// Words due for review now.
  Future<List<SavedWord>> due() async {
    final now = _now();
    return (await words()).where((w) => w.sm2.isDue(now)).toList()
      ..sort((a, b) => a.sm2.dueAt.compareTo(b.sm2.dueAt));
  }

  Future<void> _write(SavedWord w) async {
    await _store.put(_box, w.id, w.toJson());
    if (_syncs) await _sync.enqueue('users/$uid/words/${w.id}', w.toJson());
  }

  /// Saves [lemma] with its dictionary data and the lyric [context].
  ///
  /// Duplicate policy: one card per lemma. Saving again from another line
  /// adds that line as a new context and keeps the SM-2 schedule; saving the
  /// same line twice changes nothing; a deleted card is restored with a new
  /// schedule. XP is requested with id `word:{lemma}`, so a lemma earns the
  /// "save word" XP at most once per user.
  Future<SaveWordOutcome> save({
    required String lemma,
    required String ipa,
    required String pos,
    required String meaning,
    String example = '',
    String exampleVi = '',
    WordContext? context,
  }) async {
    final id = normalizeWord(lemma);
    final nowMs = _now().millisecondsSinceEpoch;
    final existing = await byId(id);
    SaveWordOutcome outcome;
    SavedWord next;
    if (existing == null || existing.isDeleted) {
      next = SavedWord(
        id: id,
        word: id,
        ipa: ipa,
        pos: pos,
        meaning: meaning,
        example: example,
        exampleVi: exampleVi,
        contexts: [?context],
        sm2: Sm2State(dueAt: _now()),
        createdAt: nowMs,
        updatedAt: nowMs,
      );
      outcome = existing == null ? SaveWordOutcome.created : SaveWordOutcome.restored;
    } else {
      final hasContext =
          context == null || existing.contexts.any((c) => c.key == context.key);
      if (hasContext) return SaveWordOutcome.alreadySaved;
      next = existing.copyWith(
        contexts: [...existing.contexts, context],
        updatedAt: nowMs,
      );
      outcome = SaveWordOutcome.contextAdded;
    }
    await _write(next);
    _bus.emit(LearningEvent(
      id: 'word:$id',
      type: LearningEventType.wordSaved,
      uid: uid,
      data: {'lemma': id, 'songId': context?.songId},
    ));
    return outcome;
  }

  /// Applies a review grade and reschedules the card with SM-2.
  Future<SavedWord> review(String id, ReviewGrade grade) async {
    final w = await byId(id);
    if (w == null) throw StateError('Word $id not found');
    final now = _now();
    final next = w.copyWith(
      sm2: Sm2.review(w.sm2, grade.quality, now),
      reviewCount: w.reviewCount + 1,
      lapses: grade.isCorrect ? w.lapses : w.lapses + 1,
      updatedAt: now.millisecondsSinceEpoch,
    );
    await _write(next);
    _bus.emit(LearningEvent(
      // One rewarded correct review per word per day; misses are recorded
      // separately (activity/statistics only).
      id: 'review:$id:${dayKey(now)}:${grade.isCorrect ? 'ok' : 'miss'}',
      type: LearningEventType.flashcardReviewed,
      uid: uid,
      data: {'lemma': id, 'quality': grade.quality},
      at: now,
    ));
    return next;
  }

  /// Soft delete (tombstone) so the deletion also syncs.
  Future<void> delete(String id) async {
    final w = await byId(id);
    if (w == null) return;
    await _write(w.copyWith(
      isDeleted: true,
      updatedAt: _now().millisecondsSinceEpoch,
    ));
  }

  Future<void> pull() => _sync.pull('users/$uid/words', _box);
}
