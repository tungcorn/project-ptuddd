import 'dart:math' as math;

/// A piece of a lyric line: either a word the learner can tap, or the
/// punctuation/whitespace between words.
class LyricToken {
  const LyricToken(this.text, {required this.isWord});

  final String text;
  final bool isWord;

  /// Lower-case form used for dictionary lookup and answer checking.
  String get normalized => normalizeWord(text);
}

final RegExp _wordPattern = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");

/// Splits [line] into word and non-word tokens, preserving every character so
/// that joining the token texts reproduces the original line.
List<LyricToken> tokenizeLine(String line) {
  final tokens = <LyricToken>[];
  var last = 0;
  for (final m in _wordPattern.allMatches(line)) {
    if (m.start > last) {
      tokens.add(LyricToken(line.substring(last, m.start), isWord: false));
    }
    tokens.add(LyricToken(m.group(0)!, isWord: true));
    last = m.end;
  }
  if (last < line.length) {
    tokens.add(LyricToken(line.substring(last), isWord: false));
  }
  return tokens;
}

/// Only the words of [line], normalized.
List<String> wordsOf(String line) =>
    _wordPattern.allMatches(line).map((m) => normalizeWord(m.group(0)!)).toList();

/// Lower-cases and unifies apostrophes so "You’re" and "you're" match.
String normalizeWord(String word) =>
    word.toLowerCase().replaceAll('’', "'").trim();

/// Normalizes a whole sentence for comparison: lower case, unified
/// apostrophes, punctuation removed, single spaces.
String normalizeSentence(String text) => wordsOf(text).join(' ');

/// Classic Levenshtein edit distance over arbitrary sequences.
int levenshtein<T>(List<T> a, List<T> b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }
  return prev[b.length];
}

/// Character-level Levenshtein distance between two strings.
int stringDistance(String a, String b) =>
    levenshtein(a.split(''), b.split(''));

/// Similarity in [0, 1]: 1 - distance / max(length).
double similarity(String a, String b) {
  final maxLen = math.max(a.length, b.length);
  if (maxLen == 0) return 1;
  return 1 - stringDistance(a, b) / maxLen;
}
