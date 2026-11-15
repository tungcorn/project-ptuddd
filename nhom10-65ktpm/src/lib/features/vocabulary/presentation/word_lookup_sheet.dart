import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../songs/domain/song.dart';
import '../data/vocabulary_repository.dart';
import '../domain/dictionary.dart';
import '../domain/saved_word.dart';

/// Opens the lookup sheet for [word] tapped in [line] of [song].
Future<void> showWordLookup(
  BuildContext context, {
  required String word,
  Song? song,
  LyricLine? line,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WordLookupSheet(word: word, song: song, line: line),
    );

/// Dictionary card: lemma, IPA, meaning, example, TTS and "save to
/// flashcards" with the lyric line as context (section 7.5).
class WordLookupSheet extends ConsumerStatefulWidget {
  const WordLookupSheet({super.key, required this.word, this.song, this.line});

  final String word;
  final Song? song;
  final LyricLine? line;

  @override
  ConsumerState<WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends ConsumerState<WordLookupSheet> {
  bool _saving = false;
  bool? _saved;
  String? _machineMeaning;
  bool _translating = false;
  final _manualMeaning = TextEditingController();

  @override
  void dispose() {
    _manualMeaning.dispose();
    super.dispose();
  }

  Future<void> _translateWord(String text) async {
    setState(() => _translating = true);
    final tr = ref.read(translationServiceProvider);
    try {
      if (!await tr.isModelReady()) {
        showMessage('Đang tải gói dịch Anh–Việt (một lần, cần mạng)…');
        if (!await tr.downloadModel()) throw Exception('không tải được gói dịch');
      }
      final out = await tr.translate(text);
      if (mounted) setState(() => _machineMeaning = out);
    } catch (e) {
      showMessage('Không dịch được: $e');
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _save(LookupResult r) async {
    final entry = r.entry;
    final meaning = entry?.vi ?? _machineMeaning ?? _manualMeaning.text.trim();
    if (meaning.isEmpty) {
      showMessage('Nhập hoặc dịch nghĩa trước khi lưu');
      return;
    }
    setState(() => _saving = true);
    final song = widget.song;
    final line = widget.line;
    try {
      final outcome = await ref.read(vocabularyRepositoryProvider).save(
            lemma: r.lemma,
            ipa: entry?.ipa ?? '',
            pos: entry?.pos ?? '',
            meaning: meaning,
            example: entry?.example ?? '',
            exampleVi: entry?.exampleVi ?? '',
            context: song == null || line == null
                ? null
                : WordContext(
                    songId: song.id,
                    songTitle: song.title,
                    lineIndex: line.index,
                    line: line.en,
                    lineVi: line.vi,
                    startMs: line.start.inMilliseconds,
                    endMs: line.end.inMilliseconds,
                  ),
          );
      showMessage(switch (outcome) {
        SaveWordOutcome.created => 'Đã lưu “${r.lemma}” vào flashcard',
        SaveWordOutcome.contextAdded => 'Đã thêm câu hát mới cho “${r.lemma}”',
        SaveWordOutcome.alreadySaved => '“${r.lemma}” đã có trong flashcard',
        SaveWordOutcome.restored => 'Đã khôi phục “${r.lemma}” vào flashcard',
      });
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      showMessage('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dictAsync = ref.watch(dictionaryProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: dictAsync.when(
          loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Không mở được từ điển: $e'),
          data: (dict) {
            final r = dict.lookup(widget.word);
            final e = r.entry;
            final savedAsync = ref.watch(savedWordsProvider);
            final alreadySaved = _saved ??
                (savedAsync.value?.any((w) => w.id == r.lemma) ?? false);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.lemma,
                            key: const Key('lookup-lemma'),
                            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        if (r.surface != r.lemma)
                          Text('Dạng trong bài: “${r.surface}”', style: t.textTheme.bodySmall),
                      ]),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Nghe phát âm',
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => ref.read(speechServiceProvider).speak(r.lemma),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (e != null) ...[
                    Wrap(spacing: 8, children: [
                      if (e.ipa.isNotEmpty) Text(e.ipa, style: t.textTheme.titleMedium),
                      if (e.pos.isNotEmpty)
                        Chip(label: Text(e.pos), visualDensity: VisualDensity.compact),
                    ]),
                    const SizedBox(height: 8),
                    Text(e.vi, key: const Key('lookup-meaning'), style: t.textTheme.titleMedium),
                    if (e.example.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Ví dụ', style: t.textTheme.labelLarge),
                      Text(e.example, style: const TextStyle(fontStyle: FontStyle.italic)),
                      if (e.exampleVi.isNotEmpty)
                        Text(e.exampleVi, style: t.textTheme.bodySmall),
                    ],
                  ] else ...[
                    Text('Từ này chưa có trong từ điển offline.',
                        style: t.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    if (_machineMeaning != null)
                      Text('Dịch máy: $_machineMeaning', style: t.textTheme.titleMedium)
                    else
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _manualMeaning,
                            decoration: const InputDecoration(labelText: 'Tự nhập nghĩa'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _translating ? null : () => _translateWord(r.surface),
                          child: Text(_translating ? 'Đang dịch…' : 'Dịch máy'),
                        ),
                      ]),
                  ],
                  if (widget.line != null) ...[
                    const Divider(height: 24),
                    Text('Trong câu hát', style: t.textTheme.labelLarge),
                    Text(widget.line!.en),
                    if (widget.line!.vi.isNotEmpty)
                      Text(widget.line!.vi, style: t.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('lookup-save'),
                      onPressed: _saving || (alreadySaved && widget.line == null)
                          ? null
                          : () => _save(r),
                      icon: Icon(alreadySaved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
                      label: Text(alreadySaved ? 'Đã lưu · thêm ngữ cảnh câu này' : 'Lưu vào flashcard'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
