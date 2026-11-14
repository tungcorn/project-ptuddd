import 'dart:math';

import '../../../core/text/text_utils.dart';
import '../../songs/domain/song.dart';

/// Fill-in-the-blank difficulty: share of lyric words hidden (section 7.6).
enum BlankDifficulty {
  easy(0.10, 'Dễ'),
  medium(0.25, 'Vừa'),
  hard(0.50, 'Khó');

  const BlankDifficulty(this.ratio, this.label);

  final double ratio;
  final String label;
}

/// Very common words hidden only when there are not enough content words.
const _functionWords = {
  'a', 'an', 'the', 'and', 'or', 'but', 'of', 'to', 'in', 'on', 'at', 'is',
  'are', 'was', 'were', 'be', 'i', 'you', 'he', 'she', 'it', 'we', 'they',
  'my', 'your', 'his', 'her', 'its', 'our', 'their', 'me', 'him', 'us',
  'them', 'so', 'as', 'for', 'with', 'by', 'oh', 'o',
};

class Blank {
  const Blank({
    required this.lineIndex,
    required this.tokenIndex,
    required this.answer,
    required this.options,
  });

  final int lineIndex;

  /// Index into `tokenizeLine(line.en)`.
  final int tokenIndex;

  /// Expected word, as written in the lyric.
  final String answer;

  /// Four choices (answer + three distractors) for "choose" mode.
  final List<String> options;

  bool check(String input) => normalizeWord(input) == normalizeWord(answer);
}

class FillBlankExercise {
  const FillBlankExercise(this.difficulty, this.blanks);

  final BlankDifficulty difficulty;
  final List<Blank> blanks;

  /// Line indexes that contain at least one blank, in order.
  List<int> get lineIndexes =>
      {for (final b in blanks) b.lineIndex}.toList()..sort();

  List<Blank> blanksOf(int lineIndex) =>
      blanks.where((b) => b.lineIndex == lineIndex).toList();
}

class ExerciseGenerator {
  ExerciseGenerator([Random? random]) : _rnd = random ?? Random();

  final Random _rnd;

  /// Hides round(ratio × word count) words (at least one), preferring
  /// content words, spread over the song.
  FillBlankExercise fillBlank(SongLyrics lyrics, BlankDifficulty difficulty) {
    final candidates = <({int line, int token, String word})>[];
    for (final line in lyrics.lines) {
      final tokens = tokenizeLine(line.en);
      for (var t = 0; t < tokens.length; t++) {
        if (tokens[t].isWord) {
          candidates.add((line: line.index, token: t, word: tokens[t].text));
        }
      }
    }
    if (candidates.isEmpty) return FillBlankExercise(difficulty, const []);
    final target = max(1, (candidates.length * difficulty.ratio).round());
    final content = candidates
        .where((c) => c.word.length >= 3 && !_functionWords.contains(normalizeWord(c.word)))
        .toList()
      ..shuffle(_rnd);
    final rest = candidates.where((c) => !content.contains(c)).toList()..shuffle(_rnd);
    final chosen = [...content, ...rest].take(target).toList()
      ..sort((a, b) => a.line != b.line ? a.line.compareTo(b.line) : a.token.compareTo(b.token));

    final vocabulary = {for (final c in candidates) normalizeWord(c.word)}.toList();
    return FillBlankExercise(difficulty, [
      for (final c in chosen)
        Blank(
          lineIndex: c.line,
          tokenIndex: c.token,
          answer: c.word,
          options: _options(normalizeWord(c.word), vocabulary),
        ),
    ]);
  }

  List<String> _options(String answer, List<String> pool) {
    final others = pool.where((w) => w != answer).toList()
      ..sort((a, b) =>
          (a.length - answer.length).abs().compareTo((b.length - answer.length).abs()));
    final near = others.take(8).toList()..shuffle(_rnd);
    final opts = {answer, ...near.take(3)}.toList()..shuffle(_rnd);
    return opts;
  }

  /// Picks up to [count] consecutive distinct lines and returns them in
  /// shuffled order (never already sorted when 2+ lines).
  LineOrderExercise lineOrder(SongLyrics lyrics, {int count = 5}) {
    final lines = <LyricLine>[];
    final seen = <String>{};
    for (final l in lyrics.lines) {
      if (seen.add(normalizeSentence(l.en))) lines.add(l);
    }
    final n = min(count, lines.length);
    final start = lines.length - n <= 0 ? 0 : _rnd.nextInt(lines.length - n + 1);
    final correct = lines.sublist(start, start + n);
    final shuffled = [...correct];
    if (n > 1) {
      do {
        shuffled.shuffle(_rnd);
      } while (_sameOrder(shuffled, correct));
    }
    return LineOrderExercise(correct, shuffled);
  }

  /// A line with 3–12 words split into shuffled word tiles.
  WordOrderExercise? wordOrder(SongLyrics lyrics) {
    final usable = lyrics.lines.where((l) {
      final n = wordsOf(l.en).length;
      return n >= 3 && n <= 12;
    }).toList();
    if (usable.isEmpty) return null;
    final line = usable[_rnd.nextInt(usable.length)];
    final words = [
      for (final t in tokenizeLine(line.en))
        if (t.isWord) t.text,
    ];
    final tiles = [...words];
    do {
      tiles.shuffle(_rnd);
    } while (words.length > 1 && _sameOrder(tiles, words));
    return WordOrderExercise(line, words, tiles);
  }

  /// Meaning quiz: keyword meanings + line translations.
  List<QuizQuestion> meaningQuiz(
    SongLyrics lyrics, {
    required Map<String, String> keywordMeanings,
    int maxQuestions = 8,
  }) {
    final questions = <QuizQuestion>[];
    final kw = keywordMeanings.entries.toList()..shuffle(_rnd);
    final allMeanings = keywordMeanings.values.toSet().toList();
    for (final e in kw.take(maxQuestions ~/ 2 + 1)) {
      final distract = allMeanings.where((m) => m != e.value).toList()..shuffle(_rnd);
      if (distract.length < 2) continue;
      final opts = [e.value, ...distract.take(3)]..shuffle(_rnd);
      questions.add(QuizQuestion(
        prompt: 'Từ “${e.key}” trong bài hát có nghĩa là gì?',
        options: opts,
        answerIndex: opts.indexOf(e.value),
      ));
    }
    final translated = lyrics.lines.where((l) => l.vi.isNotEmpty).toList();
    final uniq = <String, LyricLine>{};
    for (final l in translated) {
      uniq.putIfAbsent(normalizeSentence(l.en), () => l);
    }
    final lines = uniq.values.toList()..shuffle(_rnd);
    for (final l in lines) {
      if (questions.length >= maxQuestions) break;
      final distract = uniq.values
          .where((o) => o.vi != l.vi)
          .map((o) => o.vi)
          .toSet()
          .toList()
        ..shuffle(_rnd);
      if (distract.length < 2) continue;
      final opts = [l.vi, ...distract.take(3)]..shuffle(_rnd);
      questions.add(QuizQuestion(
        prompt: 'Chọn nghĩa đúng của câu:\n“${l.en}”',
        options: opts,
        answerIndex: opts.indexOf(l.vi),
        lineIndex: l.index,
      ));
    }
    return questions;
  }

  static bool _sameOrder<T>(List<T> a, List<T> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class LineOrderExercise {
  const LineOrderExercise(this.correct, this.shuffled);

  final List<LyricLine> correct;
  final List<LyricLine> shuffled;

  /// Number of lines placed at their correct position.
  int score(List<LyricLine> answer) {
    var ok = 0;
    for (var i = 0; i < correct.length && i < answer.length; i++) {
      if (answer[i].index == correct[i].index) ok++;
    }
    return ok;
  }
}

class WordOrderExercise {
  const WordOrderExercise(this.line, this.words, this.tiles);

  final LyricLine line;
  final List<String> words;
  final List<String> tiles;

  bool check(List<String> answer) =>
      answer.map(normalizeWord).join(' ') == words.map(normalizeWord).join(' ');
}

class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.answerIndex,
    this.lineIndex,
  });

  final String prompt;
  final List<String> options;
  final int answerIndex;
  final int? lineIndex;
}
