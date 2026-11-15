import 'sm2.dart';

/// Where a saved word was met: song + lyric line (the "context").
class WordContext {
  const WordContext({
    required this.songId,
    required this.songTitle,
    required this.lineIndex,
    required this.line,
    this.lineVi = '',
    required this.startMs,
    required this.endMs,
  });

  final String songId;
  final String songTitle;
  final int lineIndex;
  final String line;
  final String lineVi;
  final int startMs;
  final int endMs;

  String get key => '$songId#$lineIndex';

  factory WordContext.fromJson(Map<String, dynamic> j) => WordContext(
        songId: j['songId'] as String,
        songTitle: j['songTitle'] as String? ?? '',
        lineIndex: (j['lineIndex'] as num).toInt(),
        line: j['line'] as String? ?? '',
        lineVi: j['lineVi'] as String? ?? '',
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'songTitle': songTitle,
        'lineIndex': lineIndex,
        'line': line,
        'lineVi': lineVi,
        'startMs': startMs,
        'endMs': endMs,
      };
}

/// A flashcard (`users/{uid}/words/{wordId}`). [id] is the normalized lemma,
/// so saving "stars" and "star" ends up on the same card.
class SavedWord {
  const SavedWord({
    required this.id,
    required this.word,
    required this.ipa,
    required this.pos,
    required this.meaning,
    this.example = '',
    this.exampleVi = '',
    this.contexts = const [],
    required this.sm2,
    this.reviewCount = 0,
    this.lapses = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  final String id;

  /// Display form (the lemma).
  final String word;
  final String ipa;
  final String pos;
  final String meaning;
  final String example;
  final String exampleVi;
  final List<WordContext> contexts;
  final Sm2State sm2;
  final int reviewCount;
  final int lapses;
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;

  Set<String> get songIds => {for (final c in contexts) c.songId};

  factory SavedWord.fromJson(Map<String, dynamic> j) => SavedWord(
        id: j['id'] as String,
        word: j['word'] as String,
        ipa: j['ipa'] as String? ?? '',
        pos: j['pos'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        example: j['example'] as String? ?? '',
        exampleVi: j['exampleVi'] as String? ?? '',
        contexts: [
          for (final c in j['contexts'] as List? ?? const [])
            WordContext.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        sm2: Sm2State(
          easeFactor: (j['ef'] as num?)?.toDouble() ?? 2.5,
          intervalDays: (j['interval'] as num?)?.toInt() ?? 0,
          repetitions: (j['repetitions'] as num?)?.toInt() ?? 0,
          dueAt: DateTime.fromMillisecondsSinceEpoch(
            (j['dueAt'] as num?)?.toInt() ?? 0,
          ),
        ),
        reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
        lapses: (j['lapses'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        isDeleted: j['isDeleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'ipa': ipa,
        'pos': pos,
        'meaning': meaning,
        'example': example,
        'exampleVi': exampleVi,
        'contexts': [for (final c in contexts) c.toJson()],
        'ef': sm2.easeFactor,
        'interval': sm2.intervalDays,
        'repetitions': sm2.repetitions,
        'dueAt': sm2.dueAt.millisecondsSinceEpoch,
        'reviewCount': reviewCount,
        'lapses': lapses,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
      };

  SavedWord copyWith({
    List<WordContext>? contexts,
    Sm2State? sm2,
    int? reviewCount,
    int? lapses,
    int? updatedAt,
    bool? isDeleted,
    String? meaning,
    int? createdAt,
  }) =>
      SavedWord(
        id: id,
        word: word,
        ipa: ipa,
        pos: pos,
        meaning: meaning ?? this.meaning,
        example: example,
        exampleVi: exampleVi,
        contexts: contexts ?? this.contexts,
        sm2: sm2 ?? this.sm2,
        reviewCount: reviewCount ?? this.reviewCount,
        lapses: lapses ?? this.lapses,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}
