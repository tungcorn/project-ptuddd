import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../domain/social_models.dart';
import 'social_widgets.dart';

/// Weekly XP ranking of me and my accepted friends (M4).
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  static const _medalColors = [Color(0xFFFFC107), Color(0xFF9E9E9E), Color(0xFFB87333)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bảng xếp hạng tuần')),
      body: user == null || user.isGuest
          ? const GuestSocialNotice()
          : ref.watch(leaderboardProvider).when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: socialErrorText(e),
                  onRetry: () => ref.invalidate(leaderboardProvider),
                ),
                data: (list) => _list(context, ref, user.uid, list),
              ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, String me, List<PublicProfile> list) {
    final now = DateTime.now();
    final t = Theme.of(context);
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    String dm(DateTime d) => '${d.day}/${d.month}';
    final onlyMe = list.every((p) => p.uid == me);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider);
        await ref.read(leaderboardProvider.future).catchError((_) => <PublicProfile>[]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Tuần ${dm(monday)} – ${dm(sunday)} · XP kiếm được trong tuần, '
              'tính lại từ đầu mỗi thứ Hai',
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final p in list) ...[
            _row(context, p, rankOf(list, p, now), p.uid == me, now),
            const SizedBox(height: 8),
          ],
          if (list.isEmpty || onlyMe)
            EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'Chưa có ai để so tài',
              message: 'Kết bạn để cùng đua XP mỗi tuần. Bảng xếp hạng chỉ gồm '
                  'bạn và những người bạn đã chấp nhận lời mời.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.friends),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Thêm bạn bè'),
              ),
            ),
        ],
      ),
    );
  }

  /// Competition ranking: equal XP shares a rank.
  static int rankOf(List<PublicProfile> list, PublicProfile p, DateTime now) =>
      1 + list.where((o) => o.weekXpAt(now) > p.weekXpAt(now)).length;

  Widget _row(BuildContext context, PublicProfile p, int rank, bool isMe, DateTime now) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final medal = rank <= 3 && p.weekXpAt(now) > 0;
    return Card(
      key: Key('rank-${p.uid}'),
      color: isMe ? s.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMe ? BorderSide(color: s.primary, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: medal
                  ? Icon(Icons.emoji_events, color: _medalColors[rank - 1], size: 28,
                      semanticLabel: 'Hạng $rank')
                  : Text('$rank',
                      textAlign: TextAlign.center,
                      style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            NameAvatar(p.displayName, highlight: isMe),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isMe ? '${p.displayName} (bạn)' : p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isMe ? s.onPrimaryContainer : null)),
                  Text('Cấp ${p.level} · chuỗi ${p.streak} ngày',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                          color: isMe ? s.onPrimaryContainer : s.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${p.weekXpAt(now)} XP',
                style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: isMe ? s.onPrimaryContainer : s.primary)),
          ],
        ),
      ),
    );
  }
}
