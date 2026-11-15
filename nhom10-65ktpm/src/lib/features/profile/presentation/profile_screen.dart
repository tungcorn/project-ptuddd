import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../auth/presentation/auth_screens.dart';
import '../../player/presentation/player_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final snap = ref.watch(progressSnapshotProvider).value;
    final words = ref.watch(savedWordsProvider).value?.length ?? 0;
    final t = Theme.of(context);
    if (user == null) return const SizedBox.shrink();
    final social = !user.isGuest;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase(),
                  style: t.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName,
                      key: const Key('profile-name'),
                      style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  if (user.email.isNotEmpty) Text(user.email, style: t.textTheme.bodySmall),
                  Text('${user.roleLabel} · Trình độ ${user.level ?? 'chưa chọn'}',
                      style: t.textTheme.bodySmall),
                  if (social)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.userCode));
                        showMessage('Đã sao chép mã người dùng');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Mã kết bạn: ${user.userCode}  ⧉',
                            style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _Mini('${snap?.totalXp ?? 0}', 'XP'),
              _Mini('${snap?.level.level ?? 1}', 'Cấp'),
              _Mini('${snap?.streak ?? 0}', 'Chuỗi ngày'),
              _Mini('$words', 'Từ đã lưu'),
              _Mini('${snap?.badges.length ?? 0}', 'Huy hiệu'),
            ]),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Thống kê & huy hiệu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.stats),
          ),
          if (social) ...[
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Bạn bè'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.friends),
            ),
            ListTile(
              leading: const Icon(Icons.sports_esports_outlined),
              title: const Text('Thử thách “Đoán tên bài hát”'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.challenges),
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_outlined),
              title: const Text('Bảng xếp hạng tuần'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.leaderboard),
            ),
          ] else
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Bạn bè, thử thách, bảng xếp hạng'),
              subtitle: Text('Đăng ký tài khoản để sử dụng (khách chỉ học trên máy).'),
            ),
          if (user.isAdmin)
            ListTile(
              key: const Key('admin-entry'),
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Quản trị nội dung bài hát'),
              subtitle: Text(AppConfig.isFirebaseConfigured
                  ? 'Quyền admin (custom claim)'
                  : 'Quản trị viên cục bộ trên máy này'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.admin),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cài đặt'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.settings),
          ),
          const Divider(),
          ListTile(
            key: const Key('sign-out'),
            leading: const Icon(Icons.logout),
            title: Text(user.isGuest ? 'Thoát chế độ khách' : 'Đăng xuất'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất?'),
                  content: Text(user.isGuest
                      ? 'Dữ liệu khách vẫn được giữ trên máy này.'
                      : 'Dữ liệu học vẫn được lưu và đồng bộ khi bạn đăng nhập lại.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
                  ],
                ),
              );
              if (ok != true) return;
              final player = ref.read(playerControllerProvider.notifier);
              player.reportListening();
              await player.pause();
              await ref.read(syncServiceProvider).flush().catchError((_) => 0);
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(value, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: t.textTheme.labelSmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
