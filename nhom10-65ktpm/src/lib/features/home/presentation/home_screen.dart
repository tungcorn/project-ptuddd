import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/presentation/placement_screen.dart';
import '../../progress/data/progress_service.dart';
import '../../songs/data/song_progress_repository.dart';
import '../../songs/domain/song.dart';

/// Suggests songs for [level]: same level first (not yet studied), then the
/// next level, then the rest.
List<Song> suggestSongs(
  List<Song> songs,
  String level,
  Map<String, SongProgress> progress, {
  int count = 6,
}) {
  final idx = cefrLevels.indexOf(level);
  final next = idx >= 0 && idx + 1 < cefrLevels.length ? cefrLevels[idx + 1] : null;
  int rank(Song s) {
    final studied = progress[s.id]?.started ?? false;
    if (s.level == level) return studied ? 2 : 0;
    if (s.level == next) return studied ? 3 : 1;
    return 4;
  }

  final list = [...songs]..sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : a.title.compareTo(b.title);
    });
  return list.take(count).toList();
}

/// Home tab: XP / level / streak, words due today, suggestions, recent song.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final snap = ref.watch(progressSnapshotProvider).value;
    final due = ref.watch(dueWordsProvider).value ?? const [];
    final songs = ref.watch(songsProvider);
    final progress = ref.watch(songProgressProvider).value ?? const {};
    final level = userLevel(user);
    final t = Theme.of(context);

    final recent = (progress.values.where((p) => p.lastStudiedAt > 0).toList()
          ..sort((a, b) => b.lastStudiedAt.compareTo(a.lastStudiedAt)))
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Xin chào, ${user?.displayName ?? ''}!'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(songsProvider);
          final outcome = await ref.read(accountSyncProvider).syncNow();
          if (outcome.signedIn && !outcome.complete) {
            showMessage(outcome.message);
          }
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StatsCard(snap: snap, level: level),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                color: due.isEmpty ? null : t.colorScheme.tertiaryContainer,
                child: ListTile(
                  key: const Key('home-due'),
                  leading: const Icon(Icons.style),
                  title: Text(due.isEmpty
                      ? 'Không có từ cần ôn hôm nay'
                      : '${due.length} từ cần ôn hôm nay'),
                  subtitle: Text(due.isEmpty
                      ? 'Chạm vào từ trong lời bài hát để lưu flashcard'
                      : 'Ôn theo lịch lặp lại ngắt quãng SM-2'),
                  trailing: due.isEmpty ? null : const Icon(Icons.chevron_right),
                  onTap: due.isEmpty ? null : () => context.push(Routes.review),
                ),
              ),
            ),
            if (recent != null)
              songs.maybeWhen(
                data: (list) {
                  final s = list.where((x) => x.id == recent.songId).firstOrNull;
                  if (s == null) return const SizedBox.shrink();
                  return Column(children: [
                    const SectionTitle('Tiếp tục học'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: ListTile(
                          leading: SongCover(song: s, size: 48),
                          title: Text(s.title),
                          subtitle: Text('${recent.listens} lượt nghe'
                              '${recent.bestExerciseScore > 0 ? ' · bài tập ${recent.bestExerciseScore}%' : ''}'),
                          trailing: const Icon(Icons.play_circle_fill, size: 36),
                          onTap: () => context.push(Routes.player(s.id)),
                        ),
                      ),
                    ),
                  ]);
                },
                orElse: () => const SizedBox.shrink(),
              ),
            SectionTitle('Gợi ý cho trình độ $level',
                trailing: TextButton(
                  onPressed: () => context.go(Routes.songs),
                  child: const Text('Tất cả'),
                )),
            songs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(error: e),
              data: (list) {
                final suggestions = suggestSongs(list, level, progress);
                return SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final s = suggestions[i];
                      return SizedBox(
                        width: 140,
                        child: InkWell(
                          key: Key('suggest-${s.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(Routes.player(s.id)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SongCover(song: s, size: 140),
                              const SizedBox(height: 6),
                              Text(s.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              LevelBadge(s.level),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SectionTitle('Học nhanh'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.school, size: 18),
                    label: const Text('Luyện tập'),
                    onPressed: () => context.go(Routes.practice),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.bar_chart, size: 18),
                    label: const Text('Thống kê tuần'),
                    onPressed: () => context.push(Routes.stats),
                  ),
                  if (!(user?.isGuest ?? true)) ...[
                    ActionChip(
                      avatar: const Icon(Icons.sports_esports, size: 18),
                      label: const Text('Thử thách bạn bè'),
                      onPressed: () => context.push(Routes.challenges),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.leaderboard, size: 18),
                      label: const Text('Bảng xếp hạng'),
                      onPressed: () => context.push(Routes.leaderboard),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.snap, required this.level});

  final ProgressSnapshot? snap;
  final String level;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final s = snap;
    Widget stat(IconData icon, String value, String label, Color color, {Key? key}) => Expanded(
          child: Column(children: [
            Icon(icon, color: color),
            Text(value,
                key: key,
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: t.textTheme.labelSmall),
          ]),
        );
    return Card(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            stat(Icons.bolt, '${s?.totalXp ?? 0}', 'XP', Colors.amber.shade700,
                key: const Key('home-xp')),
            stat(Icons.military_tech, '${s?.level.level ?? 1}', 'Cấp độ', c.primary),
            stat(Icons.local_fire_department, '${s?.streak ?? 0}', 'Ngày liên tiếp',
                Colors.deepOrange, key: const Key('home-streak')),
            stat(Icons.translate, level, 'Trình độ', c.tertiary),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: s?.level.progress ?? 0,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s == null
                ? ''
                : '${s.level.xpIntoLevel}/${s.level.xpForNext} XP tới cấp ${s.level.level + 1}'
                    ' · Hôm nay +${s.todayXp} XP',
            style: t.textTheme.labelSmall,
          ),
        ]),
      ),
    );
  }
}
