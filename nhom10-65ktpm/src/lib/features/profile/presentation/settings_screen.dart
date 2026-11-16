import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../settings/data/settings_repository.dart';
import '../../songs/domain/song.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final n = await ref.read(syncServiceProvider).pendingCount();
    if (mounted) setState(() => _pending = n);
  }

  Future<void> _setReminder(bool enabled) async {
    final s = ref.read(settingsProvider);
    final timeLabel = s.reminderTime.format(context);
    if (enabled) {
      final ok = await ref.read(notificationServiceProvider).requestPermission();
      if (!ok) {
        showMessage('Chưa được cấp quyền thông báo. Hãy bật trong Cài đặt Android.');
        return;
      }
    }
    await ref.read(settingsProvider.notifier).update(s.copyWith(reminderEnabled: enabled));
    if (enabled) {
      showMessage('Sẽ nhắc học lúc $timeLabel mỗi ngày');
    }
  }

  Future<void> _editName(AppUser user) async {
    final ctrl = TextEditingController(text: user.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 40),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Lưu')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null) return;
    final err = AuthValidators.displayName(name);
    if (err != null) return showMessage(err);
    try {
      await ref.read(authRepositoryProvider).updateProfile(displayName: name);
      showMessage('Đã cập nhật tên');
    } catch (e) {
      showMessage('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(syncServiceProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          const _Header('Giao diện'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Theo máy'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Sáng'), icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Tối'), icon: Icon(Icons.dark_mode)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => ctrl.update(s.copyWith(themeMode: v.first)),
            ),
          ),
          ListTile(
            title: const Text('Chế độ lời mặc định'),
            trailing: DropdownButton<LyricMode>(
              value: s.lyricMode,
              items: [
                for (final m in LyricMode.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (m) => m == null ? null : ctrl.update(s.copyWith(lyricMode: m)),
            ),
          ),
          const _Header('Nhắc học hằng ngày'),
          SwitchListTile(
            key: const Key('reminder-switch'),
            title: const Text('Bật nhắc học'),
            subtitle: const Text('Thông báo nhắc ôn từ và nghe bài hát'),
            value: s.reminderEnabled,
            onChanged: _setReminder,
          ),
          ListTile(
            enabled: s.reminderEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Giờ nhắc'),
            trailing: Text(s.reminderTime.format(context),
                style: Theme.of(context).textTheme.titleMedium),
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: s.reminderTime);
              if (picked != null) await ctrl.update(s.copyWith(reminderTime: picked));
            },
          ),
          if (user != null) ...[
            const _Header('Tài khoản'),
            if (!user.isGuest)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Tên hiển thị'),
                subtitle: Text(user.displayName),
                trailing: const Icon(Icons.edit),
                onTap: () => _editName(user),
              ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Trình độ'),
              trailing: DropdownButton<String>(
                value: user.level,
                hint: const Text('Chọn'),
                items: [for (final l in cefrLevels) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (l) => ref.read(authRepositoryProvider).updateProfile(level: l),
              ),
            ),
          ],
          const _Header('Dữ liệu & đồng bộ'),
          ListTile(
            leading: Icon(AppConfig.isFirebaseConfigured ? Icons.cloud_done_outlined : Icons.phone_android),
            title: Text(AppConfig.isFirebaseConfigured ? 'Chế độ đám mây (Firebase)' : 'Chế độ demo (lưu trên máy)'),
            subtitle: Text(sync.isEnabled
                ? 'Thay đổi chờ đồng bộ: ${_pending ?? '…'}'
                : 'Dữ liệu lưu cục bộ bằng Hive; không gửi lên máy chủ.'),
            trailing: sync.isEnabled
                ? IconButton(
                    tooltip: 'Đồng bộ ngay',
                    icon: const Icon(Icons.sync),
                    onPressed: () async {
                      try {
                        final n = await sync.flush();
                        showMessage('Đã đồng bộ $n thay đổi');
                      } catch (e) {
                        showMessage('Chưa đồng bộ được: $e');
                      }
                      _refreshPending();
                    },
                  )
                : null,
          ),
          const _Header('Thông tin'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('SingLearn – Nhóm 10 · 65KTPM'),
            subtitle: Text(
              'Lời bài hát thuộc phạm vi công cộng. Bản ghi do nhóm tự tạo '
              '(nhạc nền tổng hợp + giọng đọc TTS), phát hành CC BY 4.0.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Giấy phép phần mềm mã nguồn mở'),
            onTap: () => showLicensePage(context: context, applicationName: 'SingLearn'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
