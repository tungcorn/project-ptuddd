import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../songs/domain/song.dart';
import '../domain/exercises.dart';

/// The "Luyện tập" tab: pick a song, then an exercise mode.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  /// Song chosen by the learner; null = follow the last played song.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Luyện tập')),
      body: songs.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(songsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.library_music_outlined,
              title: 'Chưa có bài hát nào',
              message: 'Thư viện bài hát đang trống.',
            );
          }
          final lastPlayed = ref.watch(playerControllerProvider.select((s) => s.song?.id));
          final id = _selectedId ?? lastPlayed;
          final song = list.where((s) => s.id == id).firstOrNull ?? list.first;
          return _content(context, list, song);
        },
      ),
    );
  }

  Widget _content(BuildContext context, List<Song> songs, Song song) {
    final t = Theme.of(context);
    final progress = ref.watch(songProgressProvider).value?[song.id];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            child: InkWell(
              key: const Key('practice-song-picker'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => _pickSong(songs, song),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SongCover(song: song, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bài hát luyện tập', style: t.textTheme.labelMedium),
                          Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              LevelBadge(song.level),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.swap_horiz),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (progress != null && progress.started)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: Text('Bài tập tốt nhất: ${progress.bestExerciseScore}%'),
                ),
                Chip(
                  avatar: const Icon(Icons.record_voice_over_outlined, size: 18),
                  label: Text('Phát âm: ${progress.bestPronunciationScore}/100'),
                ),
              ],
            ),
          ),
        const SectionTitle('Điền từ khi nghe'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: t.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nghe từng câu, nhạc tự dừng để bạn điền từ còn thiếu.',
                          style: t.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final d in BlankDifficulty.values) ...[
                        if (d != BlankDifficulty.values.first) const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            key: Key('fill-${d.name}'),
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4)),
                            onPressed: () => context.push(Routes.fillBlank(song.id, d)),
                            child: FittedBox(
                              child: Column(
                                children: [
                                  Text(d.label),
                                  Text('${(d.ratio * 100).round()}% từ',
                                      style: t.textTheme.labelSmall),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionTitle('Chế độ khác'),
        _ModeTile(
          icon: Icons.low_priority,
          title: 'Sắp xếp câu hát',
          subtitle: 'Kéo thả các câu về đúng thứ tự trong bài',
          onTap: () => context.push(Routes.lineOrder(song.id)),
        ),
        _ModeTile(
          icon: Icons.sort_by_alpha,
          title: 'Sắp xếp từ thành câu',
          subtitle: 'Ghép các từ xáo trộn thành câu hát',
          onTap: () => context.push(Routes.wordOrder(song.id)),
        ),
        _ModeTile(
          icon: Icons.quiz_outlined,
          title: 'Trắc nghiệm nghĩa',
          subtitle: 'Chọn nghĩa đúng của từ khóa và câu hát',
          onTap: () => context.push(Routes.quiz(song.id)),
        ),
        _ModeTile(
          icon: Icons.mic_none,
          title: 'Luyện hát & chấm phát âm',
          subtitle: 'Hát/đọc từng câu và nhận điểm 0–100',
          onTap: () => context.push(Routes.pronunciation(song.id)),
        ),
        const SectionTitle('Thử thách'),
        _ModeTile(
          icon: Icons.sports_esports_outlined,
          title: 'Thử thách đoán tên bài hát',
          subtitle: 'Nghe đoạn nhạc ngắn và thách đấu bạn bè',
          onTap: () => context.push(Routes.challenges),
        ),
      ],
    );
  }

  Future<void> _pickSong(List<Song> songs, Song current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SongPickerSheet(songs: songs, currentId: current.id),
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            backgroundColor: t.colorScheme.primaryContainer,
            foregroundColor: t.colorScheme.onPrimaryContainer,
            child: Icon(icon),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SongPickerSheet extends StatefulWidget {
  const _SongPickerSheet({required this.songs, required this.currentId});

  final List<Song> songs;
  final String currentId;

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.songs
        .where((s) =>
            q.isEmpty ||
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm bài hát hoặc ca sĩ',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off, title: 'Không tìm thấy bài hát phù hợp')
                  : ListView.builder(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        return ListTile(
                          leading: SongCover(song: s, size: 44, radius: 8),
                          title: Text(s.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(s.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: s.id == widget.currentId
                              ? const Icon(Icons.check)
                              : LevelBadge(s.level),
                          onTap: () => Navigator.of(context).pop(s.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
