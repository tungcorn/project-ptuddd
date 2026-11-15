import 'dart:async';

/// Kinds of learning activity reported by feature modules (M1–M3) to the
/// progress module (M4). Feature modules never write XP themselves.
enum LearningEventType {
  /// A word was saved to the flashcard deck (data: lemma, songId).
  wordSaved,

  /// A listening fill-in-the-blank session finished (data: songId, difficulty,
  /// correct, total).
  fillBlankCompleted,

  /// A line ordering / word ordering / meaning quiz session finished
  /// (data: songId, kind, correct, total).
  exerciseCompleted,

  /// A sung/read line was scored (data: songId, lineIndex, score).
  pronunciationScored,

  /// A flashcard was reviewed (data: lemma, quality).
  flashcardReviewed,

  /// Listening time in the player (data: songId, seconds, completed).
  songListened,

  /// A "guess the song" challenge was played (data: challengeId, score, won).
  challengeCompleted,
}

/// A learning event. [id] is an idempotency key chosen by the producer so
/// that retries, double taps or re-syncs never award XP twice: the progress
/// ledger stores at most one entry per id.
class LearningEvent {
  LearningEvent({
    required this.id,
    required this.type,
    required this.uid,
    Map<String, Object?>? data,
    DateTime? at,
  })  : data = data ?? const {},
        at = at ?? DateTime.now();

  final String id;
  final LearningEventType type;
  final String uid;
  final Map<String, Object?> data;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'uid': uid,
        'data': data,
        'at': at.millisecondsSinceEpoch,
      };

  factory LearningEvent.fromJson(Map<String, dynamic> json) => LearningEvent(
        id: json['id'] as String,
        type: LearningEventType.values.byName(json['type'] as String),
        uid: json['uid'] as String,
        data: Map<String, Object?>.from(json['data'] as Map? ?? const {}),
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
      );
}

/// In-memory broadcast bus. Durable "exactly once" is guaranteed by the
/// ledger in the progress module, not by the bus itself.
class AppEventBus {
  final _controller = StreamController<LearningEvent>.broadcast();

  Stream<LearningEvent> get stream => _controller.stream;

  void emit(LearningEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}

/// Local calendar day key (yyyy-mm-dd) used for streaks and per-day
/// idempotency keys. Streaks follow the device's local time zone.
String dayKey(DateTime t) {
  final d = t.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
