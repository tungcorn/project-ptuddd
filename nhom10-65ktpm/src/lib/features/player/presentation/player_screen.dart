import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/text/text_utils.dart';
import '../../../core/ui/widgets.dart';
import '../../practice/domain/exercises.dart';
import '../../settings/data/settings_repository.dart';
import '../../songs/domain/song.dart';
import '../../vocabulary/presentation/word_lookup_sheet.dart';
import 'player_controller.dart';

/// Music player with synchronized lyrics (section 7.4).
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _openedId;
  final _lineKeys = <int, GlobalKey>{};
  int _lastScrolled = -1;
  final Set<int> _revealed = {};

  void _ensureOpened(Song song) {
    if (_openedId == song.id) return;
    _openedId = song.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerControllerProvider.notifier).open(song, autoplay: true);
    });
  }

  void _scrollTo(int index) {
    if (index == _lastScrolled || index < 0) return;
    _lastScrolled = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _lineKeys[index]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.35, duration: const Duration(milliseconds: 300));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final songAsync = ref.watch(songByIdProvider(widget.songId));
    return songAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e)),
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.music_off, title: 'Không tìm thấy bài hát'),
          );
        }
        _ensureOpened(song);
        return _buildPlayer(context, song);
      },
    );
  }

  Widget _buildPlayer(BuildContext context, Song song) {
    final t = Theme.of(context);
    final st = ref.watch(playerControllerProvider);
    final ctrl = ref.read(playerControllerProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final progress = ref.watch(songProgressProvider).value?[song.id];
    final isCurrent = st.song?.id == song.id;
    final lyrics = isCurrent ? st.lyrics : null;
    final current = isCurrent ? st.currentLine : -1;
    if (isCurrent) _scrollTo(current);

    return PopScope(
      onPopInvokedWithResult: (_, _) => ctrl.reportListening(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: (progress?.favorite ?? false) ? 'Bỏ yêu thích' : 'Yêu thích',
              icon: Icon((progress?.favorite ?? false) ? Icons.favorite : Icons.favorite_border,
                  color: (progress?.favorite ?? false) ? Colors.pink : null),
              onPressed: () => ref.read(songProgressRepositoryProvider).toggleFavorite(song.id),
            ),
            PopupMenuButton<String>(
              tooltip: 'Luyện tập bài này',
              icon: const Icon(Icons.school_outlined),
              onSelected: (v) {
                ctrl.pause();
                context.push(v);
              },
              itemBuilder: (_) => [
                for (final d in BlankDifficulty.values)
                  PopupMenuItem(
                      value: Routes.fillBlank(song.id, d),
                      child: Text('Điền từ – ${d.label}')),
                PopupMenuItem(value: Routes.lineOrder(song.id), child: const Text('Sắp xếp câu hát')),
                PopupMenuItem(value: Routes.wordOrder(song.id), child: const Text('Sắp xếp từ')),
                PopupMenuItem(value: Routes.quiz(song.id), child: const Text('Trắc nghiệm nghĩa')),
                PopupMenuItem(
                    value: Routes.pronunciation(song.id,
                        line: current >= 0 ? current : null),
                    child: const Text('Luyện hát & chấm phát âm')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                SongCover(song: song, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      LevelBadge(song.level),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          [for (final tp in song.topics) topicLabels[tp] ?? tp].join(' · '),
                          style: t.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SegmentedButton<LyricMode>(
                showSelectedIcon: false,
                segments: [
                  for (final m in LyricMode.values)
                    ButtonSegment(value: m, label: Text(m.label)),
                ],
                selected: {settings.lyricMode},
                onSelectionChanged: (s) => ref
                    .read(settingsProvider.notifier)
                    .update(settings.copyWith(lyricMode: s.first)),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: !isCurrent || st.loading
                  ? const LoadingView()
                  : st.error != null
                      ? ErrorView(
                          error: st.error!,
                          onRetry: () {
                            _openedId = null;
                            setState(() {});
                          })
                      : _LyricsView(
                          song: song,
                          lines: lyrics?.lines ?? const [],
                          current: current,
                          mode: settings.lyricMode,
                          lineKeys: _lineKeys,
                          revealed: _revealed,
                          loopLine: st.loopLine,
                          onReveal: (i) => setState(() => _revealed.add(i)),
                          onSeek: ctrl.seekToLine,
                        ),
            ),
            if (song.keywords.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Center(child: Text('Từ khóa: ', style: t.textTheme.labelMedium)),
                    for (final k in song.keywords)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(k),
                          onPressed: () {
                            final line = lyrics?.lines
                                .where((l) => wordsOf(l.en).any((w) => w.startsWith(k)))
                                .firstOrNull;
                            showWordLookup(context, word: k, song: song, line: line);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            _Controls(song: song),
          ],
        ),
      ),
    );
  }
}

class _LyricsView extends StatelessWidget {
  const _LyricsView({
    required this.song,
    required this.lines,
    required this.current,
    required this.mode,
    required this.lineKeys,
    required this.revealed,
    required this.loopLine,
    required this.onReveal,
    required this.onSeek,
  });

  final Song song;
  final List<LyricLine> lines;
  final int current;
  final LyricMode mode;
  final Map<int, GlobalKey> lineKeys;
  final Set<int> revealed;
  final int? loopLine;
  final ValueChanged<int> onReveal;
  final ValueChanged<int> onSeek;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const EmptyState(icon: Icons.lyrics_outlined, title: 'Bài hát chưa có lời');
    }
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == LyricMode.hidden)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Chế độ luyện nghe: lời đang ẩn. Chạm vào một câu để hiện lời câu đó.',
                style: t.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          for (final line in lines)
            _LineTile(
              key: lineKeys.putIfAbsent(line.index, GlobalKey.new),
              song: song,
              line: line,
              active: line.index == current,
              looped: loopLine == line.index,
              mode: mode,
              revealed: revealed.contains(line.index),
              onTap: () {
                if (mode == LyricMode.hidden && !revealed.contains(line.index)) {
                  onReveal(line.index);
                } else {
                  onSeek(line.index);
                }
              },
            ),
          const SizedBox(height: 12),
          Text(song.license, style: t.textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LineTile extends StatefulWidget {
  const _LineTile({
    super.key,
    required this.song,
    required this.line,
    required this.active,
    required this.looped,
    required this.mode,
    required this.revealed,
    required this.onTap,
  });

  final Song song;
  final LyricLine line;
  final bool active;
  final bool looped;
  final LyricMode mode;
  final bool revealed;
  final VoidCallback onTap;

  @override
  State<_LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<_LineTile> {
  final _recognizers = <TapGestureRecognizer>[];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final song = widget.song;
    final line = widget.line;
    final active = widget.active;
    final looped = widget.looped;
    final mode = widget.mode;
    final onTap = widget.onTap;
    final t = Theme.of(context);
    final c = t.colorScheme;
    final hidden = mode == LyricMode.hidden && !widget.revealed;
    final base = t.textTheme.titleMedium!.copyWith(
      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
      color: active ? c.primary : c.onSurface.withValues(alpha: 0.75),
      height: 1.35,
    );
    Widget text;
    if (hidden) {
      text = Text(
        active ? '♪ ♪ ♪  (câu ${line.index + 1})' : '• • •',
        style: base,
      );
    } else {
      text = Text.rich(
        TextSpan(children: [
          for (final tok in tokenizeLine(line.en))
            tok.isWord
                ? TextSpan(
                    text: tok.text,
                    style: base.copyWith(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: c.outline,
                    ),
                    recognizer: _tap(() =>
                        showWordLookup(context, word: tok.text, song: song, line: line)),
                  )
                : TextSpan(text: tok.text, style: base),
        ]),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: active ? c.primaryContainer.withValues(alpha: 0.45) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: looped ? Border.all(color: c.tertiary, width: 2) : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              if (mode == LyricMode.bilingual && line.vi.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(line.vi,
                      style: t.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                )
              else if (mode == LyricMode.bilingual && line.vi.isEmpty)
                _MachineTranslation(text: line.en),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(playerControllerProvider);
    final ctrl = ref.read(playerControllerProvider.notifier);
    final c = Theme.of(context).colorScheme;
    final total = st.duration.inMilliseconds <= 0 ? song.duration : st.duration;
    final pos = st.position > total ? total : st.position;
    final enabled = st.song?.id == song.id && !st.loading && st.error == null;
    return Material(
      color: c.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                SizedBox(width: 44, child: Text(formatDuration(pos), textAlign: TextAlign.center)),
                Expanded(
                  child: Slider(
                    value: pos.inMilliseconds.toDouble().clamp(0, total.inMilliseconds.toDouble().clamp(1, double.infinity)),
                    max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
                    secondaryTrackValue: null,
                    onChanged: enabled
                        ? (v) => ctrl.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                ),
                SizedBox(width: 44, child: Text(formatDuration(total), textAlign: TextAlign.center)),
              ]),
              if (st.hasAbLoop || st.loopA != null)
                Text(
                  st.hasAbLoop
                      ? 'Lặp A–B: ${formatDuration(st.loopA!)} → ${formatDuration(st.loopB!)}'
                      : 'Điểm A: ${formatDuration(st.loopA!)} – nhấn A–B để đặt điểm B',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    key: const Key('speed'),
                    onPressed: enabled ? () => ctrl.setSpeed(st.speed == 1.0 ? 0.75 : 1.0) : null,
                    child: Text(st.speed == 1.0 ? '1x' : '0.75x',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Nghe lại câu',
                    icon: const Icon(Icons.replay),
                    onPressed: enabled
                        ? () => ctrl.playLine(st.currentLine < 0 ? 0 : st.currentLine)
                        : null,
                  ),
                  IconButton.filled(
                    key: const Key('play-pause'),
                    iconSize: 36,
                    tooltip: st.playing ? 'Tạm dừng' : 'Phát',
                    icon: Icon(st.playing ? Icons.pause : Icons.play_arrow),
                    onPressed: enabled
                        ? () {
                            ctrl.cancelSegment();
                            ctrl.togglePlay();
                          }
                        : null,
                  ),
                  IconButton(
                    key: const Key('loop-line'),
                    tooltip: st.loopLine != null ? 'Tắt lặp câu' : 'Lặp lại câu hiện tại',
                    isSelected: st.loopLine != null,
                    icon: const Icon(Icons.repeat_one),
                    selectedIcon: Icon(Icons.repeat_one_on, color: c.tertiary),
                    onPressed: enabled ? ctrl.toggleLoopLine : null,
                  ),
                  TextButton(
                    key: const Key('ab-loop'),
                    onPressed: enabled ? () => showMessage(ctrl.tapAbLoop()) : null,
                    child: Text('A–B',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: st.loopA != null ? c.tertiary : null,
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On-device ML Kit translation for lines that have no bundled translation.
class _MachineTranslation extends ConsumerStatefulWidget {
  const _MachineTranslation({required this.text});

  final String text;

  @override
  ConsumerState<_MachineTranslation> createState() => _MachineTranslationState();
}

class _MachineTranslationState extends ConsumerState<_MachineTranslation> {
  String? _result;
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final tr = ref.read(translationServiceProvider);
    try {
      if (!await tr.isModelReady()) {
        showMessage('Đang tải gói dịch Anh–Việt (một lần, cần mạng)…');
        if (!await tr.downloadModel()) throw Exception('không tải được gói dịch');
      }
      final out = await tr.translate(widget.text);
      if (mounted) setState(() => _result = out);
    } catch (e) {
      showMessage('Không dịch được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_result != null) {
      return Text('(Dịch máy) $_result',
          style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic));
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _busy ? null : _run,
        icon: const Icon(Icons.translate, size: 16),
        label: Text(_busy ? 'Đang dịch…' : 'Dịch máy câu này'),
      ),
    );
  }
}
