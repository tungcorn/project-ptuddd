import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../songs/domain/song.dart';

/// Content admin: every song (hidden ones included) with search, hide/show
/// and entry points to add or edit songs (section 7.12).
class AdminSongsScreen extends ConsumerStatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  ConsumerState<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends ConsumerState<AdminSongsScreen> {
  String _query = '';
  final Set<String> _busy = {};

  bool _matches(Song s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.level.toLowerCase() == q ||
        s.keywords.any((k) => k.toLowerCase().contains(q));
  }

  Future<void> _toggleHidden(Song song) async {
    setState(() => _busy.add(song.id));
    try {
      await ref.read(songRepositoryProvider).save(song.copyWith(hidden: !song.hidden));
      showMessage(song.hidden ? 'Đã hiện "${song.title}"' : 'Đã ẩn "${song.title}"');
    } catch (e) {
      showMessage('Không cập nhật được: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(song.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authStateProvider) is AsyncLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý bài hát')),
        body: const LoadingView(),
      );
    }
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý bài hát')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Chỉ quản trị viên nội dung mới truy cập được',
        ),
      );
    }
    final songs = ref.watch(allSongsProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý bài hát')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.editSong(null)),
        icon: const Icon(Icons.add),
        label: const Text('Thêm bài hát'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên, ca sĩ, từ khóa, trình độ',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: songs.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(allSongsProvider)),
              data: (all) {
                final list = all.where(_matches).toList();
                final hiddenCount = all.where((s) => s.hidden).length;
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'Không có bài hát phù hợp',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Text(
                          '${all.length} bài hát · $hiddenCount đang ẩn',
                          style: t.textTheme.bodySmall,
                        ),
                      );
                    }
                    final s = list[i - 1];
                    final busy = _busy.contains(s.id);
                    return ListTile(
                      key: ValueKey('admin_song_${s.id}'),
                      leading: Opacity(
                        opacity: s.hidden ? 0.4 : 1,
                        child: SongCover(song: s, size: 48, radius: 8),
                      ),
                      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        children: [
                          LevelBadge(s.level),
                          const SizedBox(width: 6),
                          if (s.hidden) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: t.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Đang ẩn',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      trailing: busy
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              key: ValueKey('toggle_hidden_${s.id}'),
                              tooltip: s.hidden ? 'Hiện bài hát' : 'Ẩn bài hát',
                              icon: Icon(
                                s.hidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => _toggleHidden(s),
                            ),
                      onTap: () => context.push(Routes.editSong(s.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
