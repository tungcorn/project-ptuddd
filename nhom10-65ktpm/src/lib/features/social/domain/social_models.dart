import 'dart:math';

import '../../../core/events/app_event_bus.dart';
import '../../../core/text/text_utils.dart';
import '../../songs/domain/song.dart';

/// Public profile used by friends search and the leaderboard
/// (`publicProfiles/{uid}`).
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    required this.userCode,
    this.email = '',
    this.xp = 0,
    this.weekXp = 0,
    this.weekKey = '',
    this.level = 1,
    this.streak = 0,
  });

  final String uid;
  final String displayName;
  final String userCode;
  final String email;
  final int xp;
  final int weekXp;

  /// Monday of the week [weekXp] belongs to (yyyy-mm-dd).
  final String weekKey;
  final int level;
  final int streak;

  /// Weekly XP only counts if it belongs to the current week.
  int weekXpAt(DateTime now) => weekKey == weekKeyOf(now) ? weekXp : 0;

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        uid: j['uid'] as String? ?? j['id'] as String,
        displayName: j['displayName'] as String? ?? '',
        userCode: j['userCode'] as String? ?? '',
        email: j['email'] as String? ?? '',
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        weekXp: (j['weekXp'] as num?)?.toInt() ?? 0,
        weekKey: j['weekKey'] as String? ?? '',
        level: (j['level'] as num?)?.toInt() ?? 1,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'userCode': userCode,
        'email': email,
        'xp': xp,
        'weekXp': weekXp,
        'weekKey': weekKey,
        'level': level,
        'streak': streak,
      };
}

String weekKeyOf(DateTime now) =>
    dayKey(DateTime(now.year, now.month, now.day - (now.weekday - 1)));

enum FriendStatus { pending, accepted }

/// Friendship between two users (`friendships/{a_b}` with sorted uids).
class Friendship {
  const Friendship({
    required this.members,
    required this.requestedBy,
    required this.status,
    required this.updatedAt,
  });

  final List<String> members;
  final String requestedBy;
  final FriendStatus status;
  final int updatedAt;

  static String idOf(String a, String b) =>
      (a.compareTo(b) < 0 ? [a, b] : [b, a]).join('_');

  String get id => idOf(members[0], members[1]);

  String other(String uid) => members.first == uid ? members.last : members.first;

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
        members: List<String>.from(j['members'] as List),
        requestedBy: j['requestedBy'] as String,
        status: FriendStatus.values.byName(j['status'] as String),
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'members': members,
        'requestedBy': requestedBy,
        'status': status.name,
        'updatedAt': updatedAt,
      };
}

enum ChallengeQuestionType { clip, lyric }

/// One "guess the song" question.
class ChallengeQuestion {
  const ChallengeQuestion({
    required this.type,
    required this.songId,
    required this.options,
    required this.answerIndex,
    this.startMs = 0,
    this.prompt = '',
  });

  final ChallengeQuestionType type;
  final String songId;

  /// For [ChallengeQuestionType.clip]: where the 10-second clip starts.
  final int startMs;

  /// For [ChallengeQuestionType.lyric]: the line with one word hidden.
  final String prompt;
  final List<String> options;
  final int answerIndex;

  static const clipLength = Duration(seconds: 10);

  factory ChallengeQuestion.fromJson(Map<String, dynamic> j) => ChallengeQuestion(
        type: ChallengeQuestionType.values.byName(j['type'] as String),
        songId: j['songId'] as String,
        options: List<String>.from(j['options'] as List),
        answerIndex: (j['answerIndex'] as num).toInt(),
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        prompt: j['prompt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'songId': songId,
        'options': options,
        'answerIndex': answerIndex,
        'startMs': startMs,
        'prompt': prompt,
      };
}

enum ChallengeStatus { waiting, completed, declined }

/// A challenge sent from one friend to another (`challenges/{id}`).
class Challenge {
  const Challenge({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.questions,
    required this.fromScore,
    this.toScore,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final List<ChallengeQuestion> questions;
  final int fromScore;
  final int? toScore;
  final ChallengeStatus status;
  final int createdAt;
  final int updatedAt;

  /// Winner uid, null for a draw or while waiting.
  String? get winner {
    final t = toScore;
    if (status != ChallengeStatus.completed || t == null || t == fromScore) {
      return null;
    }
    return t > fromScore ? toUid : fromUid;
  }

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        fromUid: j['fromUid'] as String,
        fromName: j['fromName'] as String? ?? '',
        toUid: j['toUid'] as String,
        toName: j['toName'] as String? ?? '',
        questions: [
          for (final q in j['questions'] as List)
            ChallengeQuestion.fromJson(Map<String, dynamic>.from(q as Map)),
        ],
        fromScore: (j['fromScore'] as num).toInt(),
        toScore: (j['toScore'] as num?)?.toInt(),
        status: ChallengeStatus.values.byName(j['status'] as String),
        createdAt: (j['createdAt'] as num).toInt(),
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'toName': toName,
        'members': [fromUid, toUid],
        'questions': [for (final q in questions) q.toJson()],
        'fromScore': fromScore,
        'toScore': toScore,
        'status': status.name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// Builds "guess the song" questions from the song library.
class ChallengeGenerator {
  ChallengeGenerator([Random? random]) : _rnd = random ?? Random();

  final Random _rnd;

  /// [lyricsOf] returns lyric lines of a song (only needed for lyric
  /// questions). Half the questions are 10-second clips, half hidden words.
  Future<List<ChallengeQuestion>> generate(
    List<Song> songs,
    Future<SongLyrics> Function(Song) lyricsOf, {
    int count = 6,
  }) async {
    if (songs.length < 4) {
      throw StateError('Cần ít nhất 4 bài hát để tạo thử thách');
    }
    final pool = [...songs]..shuffle(_rnd);
    final picked = pool.take(count).toList();
    final questions = <ChallengeQuestion>[];
    for (var i = 0; i < picked.length; i++) {
      final song = picked[i];
      if (i.isEven) {
        final others = songs.where((s) => s.id != song.id).toList()..shuffle(_rnd);
        final options = [song.title, ...others.take(3).map((s) => s.title)]..shuffle(_rnd);
        final maxStart = max(0, song.durationMs - ChallengeQuestion.clipLength.inMilliseconds - 2000);
        // Start inside the sung part, not the instrumental intro.
        final lyrics = await lyricsOf(song);
        final minStart = lyrics.lines.isEmpty ? 0 : lyrics.lines.first.start.inMilliseconds;
        final start = maxStart <= minStart ? minStart : minStart + _rnd.nextInt(maxStart - minStart);
        questions.add(ChallengeQuestion(
          type: ChallengeQuestionType.clip,
          songId: song.id,
          startMs: start,
          options: options,
          answerIndex: options.indexOf(song.title),
        ));
      } else {
        final lyrics = await lyricsOf(song);
        final lines = lyrics.lines.where((l) => wordsOf(l.en).length >= 4).toList();
        if (lines.isEmpty) continue;
        final line = lines[_rnd.nextInt(lines.length)];
        final tokens = tokenizeLine(line.en);
        final wordIdx = [
          for (var t = 0; t < tokens.length; t++)
            if (tokens[t].isWord && tokens[t].text.length >= 3) t,
        ];
        if (wordIdx.isEmpty) continue;
        final hide = wordIdx[_rnd.nextInt(wordIdx.length)];
        final answer = normalizeWord(tokens[hide].text);
        final prompt = [
          for (var t = 0; t < tokens.length; t++) t == hide ? '_____' : tokens[t].text,
        ].join();
        final distractors = <String>{};
        final allWords = [
          for (final l in lyrics.lines) ...wordsOf(l.en),
        ].where((w) => w != answer && w.length >= 3).toSet().toList()
          ..shuffle(_rnd);
        distractors.addAll(allWords.take(3));
        final options = [answer, ...distractors]..shuffle(_rnd);
        if (options.length < 3) continue;
        questions.add(ChallengeQuestion(
          type: ChallengeQuestionType.lyric,
          songId: song.id,
          prompt: '${song.title}\n$prompt',
          options: options,
          answerIndex: options.indexOf(answer),
        ));
      }
    }
    return questions;
  }
}
