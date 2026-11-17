import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';

/// Shown instead of social screens to guests: friends, challenges and the
/// leaderboard need an account so other learners can find you.
class GuestSocialNotice extends StatelessWidget {
  const GuestSocialNotice({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.lock_person_outlined,
        title: 'Cần đăng nhập để dùng tính năng cộng đồng',
        message: 'Bạn đang dùng chế độ khách. Hãy đăng ký hoặc đăng nhập để '
            'kết bạn, thách đấu “Đoán tên bài hát” và xem bảng xếp hạng tuần.',
        action: FilledButton(
          onPressed: () => context.go(Routes.profile),
          child: const Text('Đến trang cá nhân'),
        ),
      );
}

/// Round avatar with the first letter of [name].
class NameAvatar extends StatelessWidget {
  const NameAvatar(this.name, {super.key, this.highlight = false, this.radius = 20});

  final String name;
  final bool highlight;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: highlight ? s.primary : s.secondaryContainer,
      foregroundColor: highlight ? s.onPrimary : s.onSecondaryContainer,
      child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Readable Vietnamese message for a failed social operation.
String socialErrorText(Object e) {
  if (e is StateError) return e.message;
  return 'Không thực hiện được. Kiểm tra kết nối mạng rồi thử lại.';
}
