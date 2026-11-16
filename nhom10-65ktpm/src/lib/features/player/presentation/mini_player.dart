import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import 'player_controller.dart';

/// Compact player shown above the bottom navigation while a song is loaded.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(playerControllerProvider);
    final song = st.song;
    if (song == null || song.id.contains('__preview')) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    final total = st.duration.inMilliseconds;
    final line = st.currentLine >= 0 && st.lyrics != null
        ? st.lyrics!.lines[st.currentLine].en
        : song.artist;
    return Material(
      color: c.secondaryContainer,
      child: InkWell(
        key: const Key('mini-player'),
        onTap: () => context.push(Routes.player(song.id)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: total <= 0 ? 0 : (st.position.inMilliseconds / total).clamp(0, 1),
              minHeight: 2,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(children: [
                SongCover(song: song, size: 40, radius: 8),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(line, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: st.playing ? 'Tạm dừng' : 'Phát',
                  icon: Icon(st.playing ? Icons.pause : Icons.play_arrow),
                  onPressed: st.loading
                      ? null
                      : () {
                          final ctrl = ref.read(playerControllerProvider.notifier);
                          ctrl.cancelSegment();
                          ctrl.togglePlay();
                        },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
