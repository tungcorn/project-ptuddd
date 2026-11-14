import '../../../core/text/text_utils.dart';

/// Rating bands of section 6.3 of the outline.
enum PronunciationRating {
  excellent('Xuất sắc'),
  good('Khá tốt'),
  close('Gần đúng'),
  wrong('Chưa đúng');

  const PronunciationRating(this.label);

  final String label;

  static PronunciationRating of(int score) {
    if (score >= 90) return excellent;
    if (score >= 70) return good;
    if (score >= 50) return close;
    return wrong;
  }
}

/// Per-word result for colouring the target sentence.
class WordMark {
  const WordMark(this.word, this.correct);

  final String word;
  final bool correct;
}

class PronunciationResult {
  const PronunciationResult({
    required this.score,
    required this.recognized,
    required this.marks,
  });

  /// 0–100.
  final int score;

  /// The recognition alternative that produced the best score.
  final String recognized;

  /// Target words with correct / missed flags.
  final List<WordMark> marks;

  PronunciationRating get rating => PronunciationRating.of(score);
}

/// Approximate pronunciation scoring from speech-to-text output.
///
/// score = round(100 × (1 − Levenshtein(target, heard) / max length)) on
/// normalized text (lower case, no punctuation), taking the best of the
/// recognizer's alternatives. This measures how intelligible the sentence was
/// to the recognizer, not phonetic accuracy or pitch — a documented limit.
class PronunciationScorer {
  static PronunciationResult score(String target, List<String> alternatives) {
    final t = normalizeSentence(target);
    var best = -1.0;
    var bestText = '';
    for (final alt in alternatives) {
      final s = similarity(t, normalizeSentence(alt));
      if (s > best) {
        best = s;
        bestText = alt;
      }
    }
    if (best < 0) best = 0;
    final score = (best * 100).round().clamp(0, 100);
    return PronunciationResult(
      score: score,
      recognized: bestText,
      marks: markWords(target, bestText),
    );
  }

  /// Aligns target and heard words (word-level edit distance with backtrace)
  /// and marks each target word as matched or not. A word also counts as
  /// matched when it differs by at most one character from the heard word
  /// (recognizer spelling variants such as "colour"/"color").
  static List<WordMark> markWords(String target, String heard) {
    final tw = [
      for (final tok in tokenizeLine(target))
        if (tok.isWord) tok.text,
    ];
    final a = tw.map(normalizeWord).toList();
    final b = wordsOf(heard);
    bool eq(String x, String y) =>
        x == y || (x.length > 3 && stringDistance(x, y) <= 1);

    final n = a.length, m = b.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = eq(a[i - 1], b[j - 1]) ? 0 : 1;
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
      }
    }
    final ok = List<bool>.filled(n, false);
    var i = n, j = m;
    while (i > 0 && j > 0) {
      final cost = eq(a[i - 1], b[j - 1]) ? 0 : 1;
      if (d[i][j] == d[i - 1][j - 1] + cost) {
        ok[i - 1] = cost == 0;
        i--;
        j--;
      } else if (d[i][j] == d[i - 1][j] + 1) {
        i--;
      } else {
        j--;
      }
    }
    return [for (var k = 0; k < n; k++) WordMark(tw[k], ok[k])];
  }
}
