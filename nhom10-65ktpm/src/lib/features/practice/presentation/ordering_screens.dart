import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/widgets.dart';
import '../../songs/domain/song.dart';
import '../domain/exercises.dart';
import 'practice_common.dart';

/// "Sắp xếp câu hát": drag shuffled lines back into song order.
class LineOrderScreen extends StatelessWidget {
  const LineOrderScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context) => PracticeScaffold(
        songId: songId,
        title: 'Sắp xếp câu hát',
        builder: (context, data) => _LineOrderBody(data: data),
      );
}

class _LineOrderBody extends ConsumerStatefulWidget {
  const _LineOrderBody({required this.data});

  final PracticeData data;

  @override
  ConsumerState<_LineOrderBody> createState() => _LineOrderBodyState();
}

class _LineOrderBodyState extends ConsumerState<_LineOrderBody> {
  late LineOrderExercise _exercise;
  late List<LyricLine> _order;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _exercise = ref.read(exerciseGeneratorProvider).lineOrder(
        SongLyrics(widget.data.song.id, singableLines(widget.data.lyrics)));
    _order = [..._exercise.shuffled];
    _checked = false;
  }

  void _check() {
    setState(() => _checked = true);
    reportOtherExercise(ref,
        songId: widget.data.song.id,
        kind: 'lines',
        correct: _exercise.score(_order),
        total: _exercise.correct.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_exercise.correct.length < 2) {
      return const EmptyState(
        icon: Icons.low_priority,
        title: 'Bài hát quá ngắn để sắp xếp câu',
        message: 'Hãy chọn bài hát khác.',
      );
    }
    final t = Theme.of(context);
    final score = _exercise.score(_order);
    final total = _exercise.correct.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            _checked
                ? 'Đúng vị trí $score/$total câu (${percentOf(score, total)}%)'
                : 'Kéo biểu tượng ≡ để xếp các câu theo đúng thứ tự trong bài. '
                    'Nhấn ▶ để nghe từng câu.',
            key: const Key('line-order-status'),
            style: _checked
                ? t.textTheme.titleMedium?.copyWith(
                    color: score == total ? okColor(context) : badColor(context))
                : t.textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            buildDefaultDragHandles: false,
            itemCount: _order.length,
            onReorderItem: (from, to) {
              if (_checked) return;
              setState(() => _order.insert(to, _order.removeAt(from)));
            },
            itemBuilder: (context, i) {
              final line = _order[i];
              final ok = _exercise.correct[i].index == line.index;
              final correctPos = _exercise.correct.indexWhere((l) => l.index == line.index) + 1;
              final color = !_checked ? null : (ok ? okColor(context) : badColor(context));
              return Card(
                key: ValueKey(line.index),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: color == null ? BorderSide.none : BorderSide(color: color, width: 2),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 4, right: 4),
                  leading: IconButton(
                    tooltip: 'Nghe câu này',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => playLyricLine(ref, line.index),
                  ),
                  title: Text(line.en),
                  subtitle: _checked
                      ? Text(ok ? 'Đúng vị trí' : 'Vị trí đúng: $correctPos',
                          style: TextStyle(color: color))
                      : null,
                  trailing: _checked
                      ? Icon(ok ? Icons.check_circle : Icons.cancel, color: color)
                      : ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        ActionBar(children: [
          if (_checked)
            FilledButton.icon(
              onPressed: () => setState(_generate),
              icon: const Icon(Icons.refresh),
              label: const Text('Làm bài khác'),
            )
          else
            FilledButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.check),
              label: const Text('Kiểm tra'),
            ),
        ]),
      ],
    );
  }
}

/// "Sắp xếp từ thành câu": tap word tiles to rebuild a lyric line.
class WordOrderScreen extends StatelessWidget {
  const WordOrderScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context) => PracticeScaffold(
        songId: songId,
        title: 'Sắp xếp từ thành câu',
        builder: (context, data) => _WordOrderBody(data: data),
      );
}

class _WordOrderBody extends ConsumerStatefulWidget {
  const _WordOrderBody({required this.data});

  final PracticeData data;

  @override
  ConsumerState<_WordOrderBody> createState() => _WordOrderBodyState();
}

class _WordOrderBodyState extends ConsumerState<_WordOrderBody> {
  static const _roundSize = 5;

  late List<WordOrderExercise> _round;
  int _pos = 0;
  int _correct = 0;

  /// Indexes into the current exercise's tiles, in the order placed.
  final _placed = <int>[];
  bool? _result;
  bool _finished = false;

  WordOrderExercise get _ex => _round[_pos];

  @override
  void initState() {
    super.initState();
    _generate();
  }

  /// Up to [_roundSize] sentences from different lines.
  void _generate() {
    final gen = ref.read(exerciseGeneratorProvider);
    final round = <WordOrderExercise>[];
    final seen = <int>{};
    for (var attempt = 0; attempt < 30 && round.length < _roundSize; attempt++) {
      final ex = gen.wordOrder(widget.data.lyrics);
      if (ex == null) break;
      if (seen.add(ex.line.index)) round.add(ex);
    }
    _round = round;
    _pos = 0;
    _correct = 0;
    _placed.clear();
    _result = null;
    _finished = false;
  }

  void _check() {
    final ok = _ex.check([for (final i in _placed) _ex.tiles[i]]);
    setState(() {
      _result = ok;
      if (ok) _correct++;
    });
  }

  void _next() {
    if (_pos + 1 >= _round.length) {
      setState(() => _finished = true);
      reportOtherExercise(ref,
          songId: widget.data.song.id,
          kind: 'words',
          correct: _correct,
          total: _round.length);
      return;
    }
    setState(() {
      _pos++;
      _placed.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_round.isEmpty) {
      return const EmptyState(
        icon: Icons.short_text,
        title: 'Không có câu phù hợp',
        message: 'Bài hát cần có câu từ 3 đến 12 từ. Hãy chọn bài khác.',
      );
    }
    if (_finished) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ScoreSummary(correct: _correct, total: _round.length),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => setState(_generate),
            icon: const Icon(Icons.refresh),
            label: const Text('Làm bài khác'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Quay lại'),
          ),
        ],
      );
    }
    final t = Theme.of(context);
    final checked = _result != null;
    final resultColor = _result == true ? okColor(context) : badColor(context);
    return Column(
      children: [
        LinearProgressIndicator(value: (_pos + (checked ? 1 : 0)) / _round.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Câu ${_pos + 1}/${_round.length}', style: t.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Chạm vào các từ theo đúng thứ tự. Chạm từ đã đặt để bỏ ra.',
                  style: t.textTheme.bodySmall),
              const SizedBox(height: 12),
              Container(
                key: const Key('word-answer-area'),
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: checked ? resultColor : t.colorScheme.outlineVariant,
                    width: checked ? 2 : 1,
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var k = 0; k < _placed.length; k++)
                      InputChip(
                        label: Text(_ex.tiles[_placed[k]]),
                        onPressed: checked
                            ? null
                            : () => setState(() => _placed.removeAt(k)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _ex.tiles.length; i++)
                    if (!_placed.contains(i))
                      ActionChip(
                        key: Key('tile-$i'),
                        label: Text(_ex.tiles[i]),
                        onPressed: checked ? null : () => setState(() => _placed.add(i)),
                      ),
                ],
              ),
              if (checked) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(_result! ? Icons.check_circle : Icons.cancel, color: resultColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_result! ? 'Chính xác!' : 'Chưa đúng. Câu đúng là:',
                          style: TextStyle(color: resultColor, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_ex.line.en, style: t.textTheme.titleMedium),
                if (_ex.line.vi.isNotEmpty)
                  Text(_ex.line.vi,
                      style: t.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: t.colorScheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        ActionBar(children: [
          OutlinedButton.icon(
            onPressed: () => playLyricLine(ref, _ex.line.index),
            icon: const Icon(Icons.hearing),
            label: const Text('Nghe câu'),
          ),
          if (!checked)
            FilledButton.icon(
              onPressed: _placed.length == _ex.tiles.length ? _check : null,
              icon: const Icon(Icons.check),
              label: const Text('Kiểm tra'),
            )
          else
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward),
              label: Text(_pos + 1 >= _round.length ? 'Xem kết quả' : 'Tiếp'),
            ),
        ]),
      ],
    );
  }
}
