import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../domain/saved_word.dart';

/// Filters saved words by text (word or meaning) and song.
List<SavedWord> filterWords(List<SavedWord> words, {String query = '', String? songId}) {
  final q = query.trim().toLowerCase();
  return words.where((w) {
    if (songId != null && !w.songIds.contains(songId)) return false;
    if (q.isEmpty) return true;
    return w.word.contains(q) || w.meaning.toLowerCase().contains(q);
  }).toList();
}

/// Plays the lyric line a word was saved from ("phát lại đúng đoạn nhạc").
Future<void> playWordContext(WidgetRef ref, WordContext c) async {
  final song = await ref.read(songRepositoryProvider).byId(c.songId);
  if (song == null) {
    showMessage('Bài hát không còn trong thư viện');
    return;
  }
  final ctrl = ref.read(playerControllerProvider.notifier);
  await ctrl.open(song);
  await ctrl.playSegment(
    Duration(milliseconds: c.startMs),
    Duration(milliseconds: c.endMs),
  );
}

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  String _query = '';
  String? _songId;

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(savedWordsProvider);
    final due = ref.watch(dueWordsProvider).value ?? const [];
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Từ vựng')),
      floatingActionButton: due.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('start-review'),
              onPressed: () => context.push(Routes.review),
              icon: const Icon(Icons.style),
              label: Text('Ôn ${due.length} từ'),
            ),
      body: wordsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (words) {
          if (words.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_border,
              title: 'Chưa có từ nào',
              message: 'Mở một bài hát, chạm vào từ trong lời và chọn “Lưu vào flashcard”.',
              action: FilledButton.tonal(
                onPressed: () => context.go(Routes.songs),
                child: const Text('Đến thư viện bài hát'),
              ),
            );
          }
          final songs = <String, String>{
            for (final w in words)
              for (final c in w.contexts) c.songId: c.songTitle,
          };
          final list = filterWords(words, query: _query, songId: _songId);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  key: const Key('vocab-search'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm từ hoặc nghĩa',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _songId,
                      hint: const Text('Tất cả bài hát'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả bài hát')),
                        for (final e in songs.entries)
                          DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _songId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${list.length}/${words.length} từ · ${due.length} cần ôn',
                      style: t.textTheme.labelMedium),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.search_off, title: 'Không tìm thấy từ phù hợp')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _WordTile(word: list[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordTile extends ConsumerWidget {
  const _WordTile({required this.word});

  final SavedWord word;

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Xóa “${word.word}”?'),
          content: const Text('Từ sẽ bị xóa khỏi flashcard và lịch ôn tập.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final now = DateTime.now();
    final due = word.sm2.isDue(now);
    return Dismissible(
      key: Key('word-${word.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: t.colorScheme.errorContainer,
        child: const Icon(Icons.delete),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => ref.read(vocabularyRepositoryProvider).delete(word.id),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Row(children: [
            Flexible(
              child: Text(word.word,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            if (word.ipa.isNotEmpty)
              Flexible(child: Text(word.ipa, style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
          ]),
          subtitle: Text(
            '${word.meaning}\n${due ? 'Cần ôn ngay' : 'Ôn lại: ${DateFormat('dd/MM').format(word.sm2.dueAt)}'}'
            ' · ${word.contexts.length} câu hát',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Nghe phát âm',
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () => ref.read(speechServiceProvider).speak(word.word),
          ),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => _WordDetail(word: word, onDelete: () async {
              Navigator.pop(context);
              if (await _confirmDelete(context)) {
                await ref.read(vocabularyRepositoryProvider).delete(word.id);
              }
            }),
          ),
        ),
      ),
    );
  }
}

class _WordDetail extends ConsumerWidget {
  const _WordDetail({required this.word, required this.onDelete});

  final SavedWord word;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word.word, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('${word.ipa}  ${word.pos}', style: t.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(word.meaning, style: t.textTheme.titleMedium),
            if (word.example.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(word.example, style: const TextStyle(fontStyle: FontStyle.italic)),
              Text(word.exampleVi, style: t.textTheme.bodySmall),
            ],
            const Divider(height: 24),
            Text('Lịch ôn SM-2: EF ${word.sm2.easeFactor.toStringAsFixed(2)} · '
                'khoảng cách ${word.sm2.intervalDays} ngày · đã ôn ${word.reviewCount} lần'),
            const SizedBox(height: 12),
            Text('Câu hát chứa từ', style: t.textTheme.labelLarge),
            for (final c in word.contexts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.line),
                subtitle: Text('${c.songTitle}${c.lineVi.isNotEmpty ? '\n${c.lineVi}' : ''}'),
                trailing: IconButton(
                  tooltip: 'Phát đoạn nhạc chứa từ',
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () => playWordContext(ref, c),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa từ'),
            ),
          ],
        ),
      ),
    );
  }
}
