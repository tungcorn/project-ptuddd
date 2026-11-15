import 'dart:convert';

import '../../../core/text/text_utils.dart';

/// A dictionary entry (English → Vietnamese).
class DictionaryEntry {
  const DictionaryEntry({
    required this.lemma,
    required this.ipa,
    required this.pos,
    required this.vi,
    this.example = '',
    this.exampleVi = '',
  });

  final String lemma;
  final String ipa;
  final String pos;
  final String vi;
  final String example;
  final String exampleVi;

  factory DictionaryEntry.fromJson(String lemma, Map<String, dynamic> j) =>
      DictionaryEntry(
        lemma: lemma,
        ipa: j['ipa'] as String? ?? '',
        pos: j['pos'] as String? ?? '',
        vi: j['vi'] as String? ?? '',
        example: j['example'] as String? ?? '',
        exampleVi: j['exampleVi'] as String? ?? '',
      );
}

/// Result of looking up a word tapped in the lyrics.
class LookupResult {
  const LookupResult({required this.surface, required this.lemma, this.entry});

  /// The word as it appears in the lyric (normalized).
  final String surface;

  /// Base form used as the flashcard identity (duplicate handling).
  final String lemma;

  /// Null when the word is not in the offline dictionary.
  final DictionaryEntry? entry;

  bool get found => entry != null;
}

/// Offline learner dictionary bundled as `assets/content/dictionary.json`
/// (`forms`: surface → lemma, `entries`: lemma → entry). Words outside the
/// bundled list fall back to a rule-based lemmatizer.
class SongDictionary {
  SongDictionary._(this._forms, this._entries);

  factory SongDictionary.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return SongDictionary._(
      Map<String, String>.from(json['forms'] as Map),
      {
        for (final e in (json['entries'] as Map).entries)
          e.key as String: DictionaryEntry.fromJson(
            e.key as String,
            Map<String, dynamic>.from(e.value as Map),
          ),
      },
    );
  }

  final Map<String, String> _forms;
  final Map<String, DictionaryEntry> _entries;

  int get size => _entries.length;

  DictionaryEntry? entry(String lemma) => _entries[normalizeWord(lemma)];

  LookupResult lookup(String word) {
    final w = normalizeWord(word);
    final lemma = _forms[w];
    if (lemma != null && _entries.containsKey(lemma)) {
      return LookupResult(surface: w, lemma: lemma, entry: _entries[lemma]);
    }
    if (_entries.containsKey(w)) {
      return LookupResult(surface: w, lemma: w, entry: _entries[w]);
    }
    for (final candidate in guessLemmas(w)) {
      final viaForm = _forms[candidate] ?? candidate;
      final e = _entries[viaForm];
      if (e != null) return LookupResult(surface: w, lemma: viaForm, entry: e);
    }
    final guesses = guessLemmas(w);
    return LookupResult(surface: w, lemma: guesses.isEmpty ? w : guesses.first);
  }

  /// Candidate base forms for an inflected word, most likely first.
  static List<String> guessLemmas(String w) {
    final out = <String>[];
    void add(String s) {
      if (s.length >= 2 && s != w && !out.contains(s)) out.add(s);
    }

    if (w.endsWith("'s")) add(w.substring(0, w.length - 2));
    if (w.endsWith('ies')) add('${w.substring(0, w.length - 3)}y');
    if (w.endsWith('es')) add(w.substring(0, w.length - 2));
    if (w.endsWith('s') && !w.endsWith('ss')) add(w.substring(0, w.length - 1));
    if (w.endsWith('ied')) add('${w.substring(0, w.length - 3)}y');
    if (w.endsWith('ed')) {
      final stem = w.substring(0, w.length - 2);
      add(stem);
      add('${stem}e');
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1));
      }
    }
    if (w.endsWith('ing')) {
      final stem = w.substring(0, w.length - 3);
      add(stem);
      add('${stem}e');
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        add(stem.substring(0, stem.length - 1));
      }
    }
    if (w.endsWith('est')) add(w.substring(0, w.length - 3));
    if (w.endsWith('er')) add(w.substring(0, w.length - 2));
    if (w.endsWith('ly')) add(w.substring(0, w.length - 2));
    return out;
  }
}
