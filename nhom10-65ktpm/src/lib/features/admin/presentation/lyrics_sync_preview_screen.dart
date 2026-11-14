import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../songs/data/song_repository.dart';
import '../../songs/domain/lrc_parser.dart';
import '../../songs/domain/song.dart';
import '../domain/song_editor_logic.dart';

/// What the sync preview hands back to the editor.
class SyncPreviewResult {
  const SyncPreviewResult(this.lrcText, this.duration);

  final String lrcText;

  /// Track length reported by the audio engine (zero if unknown).
  final Duration duration;
}

/// "Kiểm tra lời đồng bộ": plays an unsaved [song] (built from the editor
/// form) with highlighted lyrics, and lets the admin re-time lines on the
/// device ("Gán mốc"). Pops with a [SyncPreviewResult].
class LyricsSyncPreviewScreen extends ConsumerStatefulWidget {
  const LyricsSyncPreviewScreen({super.key, required this.song});

  /// Temporary song; its [Song.lrcText] is the LRC being checked.
  final Song song;

  @override
  ConsumerState<LyricsSyncPreviewScreen> createState() => _LyricsSyncPreviewScreenState();
}

class _LyricsSyncPreviewScreenState extends ConsumerState<LyricsSyncPreviewScreen> {
  late String _lrc = widget.song.lrcText ?? '';
  late SongLyrics _lyrics;
  int _selected = 0;
  bool _changed = false;
  late final PlayerController _player;

  @override
  void initState() {
    super.initState();
    _rebuildLyrics();
    _player = ref.read(playerControllerProvider.notifier);
    // A fresh id per preview session: the repository caches lyrics by id and
    // the player ignores open() for the song it already has.
    final temp = Song.fromJson({
      ...widget.song.toJson(),
      'id': '${widget.song.id}__preview_${DateTime.now().millisecondsSinceEpoch}',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    Future.microtask(() => _player.open(temp, autoplay: true));
  }

  void _rebuildLyrics() {
    _lyrics = SongRepository.buildLyrics(
      widget.song.copyWith(lrcText: _lrc),
      LrcParser.parse(_lrc),
    );
  }

  void _finish() {
    final duration = ref.read(playerControllerProvider).duration;
    _player.pause();
    Navigator.of(context).pop(SyncPreviewResult(_lrc, duration));
  }

  void _mark(Duration position) {
    if (_lyrics.lines.isEmpty) return;
    setState(() {
      _lrc = retimeLine(_lrc, _selected, position);
      _rebuildLyrics();
      _changed = true;
      if (_selected < _lyrics.lines.length - 1) _selected++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    final t = Theme.of(context);
    final active = LrcParser.activeIndex(_lyrics.starts, state.position);
    final lines = _lyrics.lines;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kiểm tra lời đồng bộ'),
          actions: [TextButton(onPressed: _finish, child: const Text('Xong'))],
        ),
        body: Column(
          children: [
            if (state.error != null)
              MaterialBanner(
                content: Text(state.error!),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(SyncPreviewResult(_lrc, Duration.zero)),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            if (state.loading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Đánh dấu thời gian: chạm một câu để chọn và tua tới câu đó. Khi nhạc đến đầu câu đã chọn, '
                'nhấn "Gán mốc" để đặt lại thời gian (tự chuyển sang câu tiếp theo).',
                style: t.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: lines.isEmpty
                  ? const EmptyState(icon: Icons.lyrics_outlined, title: 'Chưa có dòng lời nào')
                  : ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (context, i) {
                        final l = lines[i];
                        final isActive = i == active;
                        final isSelected = i == _selected;
                        return ListTile(
                          key: ValueKey('preview_line_$i'),
                          selected: isSelected,
                          selectedTileColor: t.colorScheme.secondaryContainer,
                          leading: Text(
                            LrcParser.format(l.start),
                            style: t.textTheme.labelSmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          title: Text(
                            l.en,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                              color: isActive ? t.colorScheme.primary : null,
                            ),
                          ),
                          subtitle: l.vi.isEmpty ? null : Text(l.vi),
                          onTap: () {
                            setState(() => _selected = i);
                            _player.seek(l.start);
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: state.playing ? 'Tạm dừng' : 'Phát',
                      onPressed: state.loading ? null : _player.togglePlay,
                      icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatDuration(state.position)} / ${formatDuration(state.duration)}',
                      style: t.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    if (_changed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('Đã sửa', style: TextStyle(color: t.colorScheme.tertiary)),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('mark_time'),
                      onPressed: lines.isEmpty ? null : () => _mark(state.position),
                      icon: const Icon(Icons.timer_outlined),
                      label: Text('Gán mốc câu ${_selected + 1}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
