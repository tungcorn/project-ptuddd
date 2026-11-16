import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../features/songs/domain/song.dart';
import 'theme.dart';

/// Cover image of a song (asset, file or URL), falling back to a gradient.
class SongCover extends StatelessWidget {
  const SongCover({super.key, required this.song, this.size = 56, this.radius = 12});

  final Song song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cover = song.cover;
    Widget fallback() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [song.seedColor, song.seedColor.withValues(alpha: 0.6)],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.music_note, color: Colors.white, size: size * 0.45),
        );
    Widget image;
    switch (mediaKindOf(cover)) {
      case MediaKind.asset:
        image = Image.asset(cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
      case MediaKind.file:
        image = kIsWeb
            ? fallback()
            : Image.file(File(cover!), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
      case MediaKind.url:
        image = Image.network(cover!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback());
      case MediaKind.none:
        image = fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});

  final String level;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(level,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: t.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline,
        title: 'Đã xảy ra lỗi',
        message: '$error',
        action: onRetry == null
            ? null
            : FilledButton.tonal(onPressed: onRetry, child: const Text('Thử lại')),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
      );
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
