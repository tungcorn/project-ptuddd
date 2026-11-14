import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/events/app_event_bus.dart';
import '../../../core/text/text_utils.dart';
import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../songs/domain/song.dart';
import '../domain/exercises.dart';
import 'practice_common.dart';

/// Listening fill-in-the-blank (section 7.6): each line with blanks is played
/// once, the music pauses, the learner fills the gaps and checks.
class FillBlankScreen extends StatelessWidget {
  const FillBlankScreen({super.key, required this.songId, required this.difficulty});
  final String songId;
  final BlankDifficulty difficulty;

  @override
  Widget build(BuildContext context) => PracticeScaffold(
        songId: songId,
        title: 'Điền từ · ${difficulty.label}',
        builder: (context, data) =>
            _FillBlankBody(data: data, difficulty: difficulty),
      );
}

enum _InputMode { type, choose }

class _FillBlankBody extends ConsumerStatefulWidget {
  const _FillBlankBody({required this.data, required this.difficulty});

  final PracticeData data;
  final BlankDifficulty difficulty;

  @override
  ConsumerState<_FillBlankBody> createState() => _FillBlankBodyState();
}

class _FillBlankBodyState extends ConsumerState<_FillBlankBody> {
  late FillBlankExercise _exercise;
  late List<int> _lines;
  int _pos = 0;
  bool _checked = false;
  bool _finished = false;
  bool _segmentDone = false;
  _InputMode _mode = _InputMode.type;

  /// Learner input per blank, keyed by `line:token`.
  final _answers = <String, String>{};
  final _results = <String, bool>{};
  final _controllers = <String, TextEditingController>{};

  Song get _song => widget.data.song;
  SongLyrics get _lyrics => widget.data.lyrics;
  int get _lineIndex => _lines[_pos];
  LyricLine get _line => _lyrics.lines[_lineIndex];

  static String _key(Blank b) => '${b.lineIndex}:${b.tokenIndex}';

  @override
  void initState() {
    super.initState();
    _exercise =
        ref.read(exerciseGeneratorProvider).fillBlank(_lyrics, widget.difficulty);
    _lines = _exercise.lineIndexes;
    if (_lines.isNotEmpty) _playCurrent();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _playCurrent() {
    if (_segmentDone) setState(() => _segmentDone = false);
    final pos = _pos;
    playLyricLine(ref, _lineIndex, onEnd: () {
      if (mounted && pos == _pos) setState(() => _segmentDone = true);
    });
  }

  TextEditingController _controller(Blank b) => _controllers.putIfAbsent(
      _key(b), () => TextEditingController(text: _answers[_key(b)] ?? ''));

  void _check() {
    FocusScope.of(context).unfocus();
    setState(() {
      for (final b in _exercise.blanksOf(_lineIndex)) {
        final input = _mode == _InputMode.type
            ? _controller(b).text
            : (_answers[_key(b)] ?? '');
        _answers[_key(b)] = input;
        _results[_key(b)] = b.check(input);
      }
      _checked = true;
    });
  }

  void _next() {
    ref.read(playerControllerProvider.notifier)
      ..cancelSegment()
      ..pause();
    if (_pos + 1 >= _lines.length) {
      _finish();
      return;
    }
    setState(() {
      _pos++;
      _checked = false;
    });
    _playCurrent();
  }

  void _finish() {
    final total = _exercise.blanks.length;
    final correct = _results.values.where((v) => v).length;
    setState(() => _finished = true);
    reportExerciseResult(
      ref,
      eventId:
          'fill:${_song.id}:${widget.difficulty.name}:${dayKey(DateTime.now())}',
      type: LearningEventType.fillBlankCompleted,
      songId: _song.id,
      correct: correct,
      total: total,
      extra: {'difficulty': widget.difficulty.name},
    );
  }

  void _restart() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    setState(() {
      _controllers.clear();
      _answers.clear();
      _results.clear();
      _exercise = ref
          .read(exerciseGeneratorProvider)
          .fillBlank(_lyrics, widget.difficulty);
      _lines = _exercise.lineIndexes;
      _pos = 0;
      _checked = false;
      _finished = false;
    });
    if (_lines.isNotEmpty) _playCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'Bài hát chưa có lời để luyện',
        message: 'Hãy chọn bài hát khác.',
      );
    }
    if (_finished) return _summary(context);
    final t = Theme.of(context);
    final playing = ref.watch(playerControllerProvider.select((s) => s.playing));
    final blanks = _exercise.blanksOf(_lineIndex);
    final allFilled = blanks.every((b) => _mode == _InputMode.type
        ? true
        : (_answers[_key(b)] ?? '').isNotEmpty);
    return Column(
      children: [
        LinearProgressIndicator(value: (_pos + (_checked ? 1 : 0)) / _lines.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Câu ${_pos + 1}/${_lines.length}',
                      style: t.textTheme.titleMedium),
                  SegmentedButton<_InputMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: _InputMode.type,
                          icon: Icon(Icons.keyboard, size: 18),
                          label: Text('Gõ')),
                      ButtonSegment(
                          value: _InputMode.choose,
                          icon: Icon(Icons.touch_app, size: 18),
                          label: Text('Chọn từ')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _checked
                        ? null
                        : (s) => setState(() {
                              // Keep what was typed when switching mode.
                              for (final b in blanks) {
                                final c = _controllers[_key(b)];
                                if (c != null && _mode == _InputMode.type) {
                                  _answers[_key(b)] = c.text;
                                }
                              }
                              _mode = s.first;
                            }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    playing ? Icons.graphic_eq : Icons.pause_circle_outline,
                    size: 18,
                    color: t.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      playing
                          ? 'Đang phát câu hát… hãy lắng nghe'
                          : _segmentDone
                              ? 'Nhạc đã dừng. Điền từ còn thiếu.'
                              : 'Nhấn “Nghe lại” để nghe câu hát',
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _lineView(context, blanks),
                ),
              ),
              if (_checked && _line.vi.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_line.vi,
                    style: t.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: t.colorScheme.onSurfaceVariant)),
              ],
              if (_mode == _InputMode.choose && !_checked) ...[
                const SizedBox(height: 16),
                for (var i = 0; i < blanks.length; i++) _optionsRow(context, i, blanks[i]),
              ],
              if (_checked) ...[
                const SizedBox(height: 16),
                _lineFeedback(context, blanks),
              ],
            ],
          ),
        ),
        ActionBar(children: [
          OutlinedButton.icon(
            onPressed: _playCurrent,
            icon: const Icon(Icons.replay),
            label: const Text('Nghe lại'),
          ),
          if (!_checked)
            FilledButton.icon(
              onPressed: allFilled ? _check : null,
              icon: const Icon(Icons.check),
              label: const Text('Kiểm tra'),
            )
          else
            FilledButton.icon(
              onPressed: _next,
              icon: Icon(_pos + 1 >= _lines.length ? Icons.flag : Icons.arrow_forward),
              label: Text(_pos + 1 >= _lines.length ? 'Xem kết quả' : 'Tiếp'),
            ),
        ]),
      ],
    );
  }

  Widget _lineView(BuildContext context, List<Blank> blanks) {
    final t = Theme.of(context);
    final style = t.textTheme.titleMedium;
    final byToken = {for (final b in blanks) b.tokenIndex: b};
    final tokens = tokenizeLine(_line.en);
    final children = <Widget>[];
    for (var i = 0; i < tokens.length; i++) {
      final b = byToken[i];
      if (b == null) {
        final text = tokens[i].text.trim();
        if (text.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(text, style: style),
          ));
        }
        continue;
      }
      final n = blanks.indexOf(b) + 1;
      final ok = _results[_key(b)];
      final width = (b.answer.length * 13.0 + 36).clamp(72.0, 200.0);
      if (_checked) {
        children.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: (ok! ? okColor(context) : badColor(context)).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ok ? okColor(context) : badColor(context)),
          ),
          child: Text(
            ok ? b.answer : (_answers[_key(b)]?.trim().isNotEmpty ?? false
                ? '${_answers[_key(b)]!.trim()} → ${b.answer}'
                : b.answer),
            style: style?.copyWith(
                color: ok ? okColor(context) : badColor(context),
                fontWeight: FontWeight.w700),
          ),
        ));
      } else if (_mode == _InputMode.type) {
        children.add(SizedBox(
          width: width,
          child: TextField(
            key: Key('blank-${b.lineIndex}-${b.tokenIndex}'),
            controller: _controller(b),
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: blanks.last == b ? TextInputAction.done : TextInputAction.next,
            onSubmitted: blanks.last == b ? (_) => _check() : null,
            style: style,
            decoration: InputDecoration(
              isDense: true,
              hintText: '($n)',
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ));
      } else {
        final chosen = _answers[_key(b)] ?? '';
        children.add(Container(
          constraints: BoxConstraints(minWidth: width),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.colorScheme.primary, width: 2)),
          ),
          child: Text(chosen.isEmpty ? '($n)' : chosen,
              textAlign: TextAlign.center,
              style: style?.copyWith(
                  color: chosen.isEmpty ? t.colorScheme.outline : t.colorScheme.primary)),
        ));
      }
    }
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _optionsRow(BuildContext context, int i, Blank b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ô (${i + 1})', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final o in b.options)
                  ChoiceChip(
                    key: Key('option-${b.lineIndex}-${b.tokenIndex}-$o'),
                    label: Text(o),
                    selected: normalizeWord(_answers[_key(b)] ?? '') == o,
                    onSelected: (_) => setState(() {
                      _answers[_key(b)] = o;
                      _controller(b).text = o;
                    }),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _lineFeedback(BuildContext context, List<Blank> blanks) {
    final ok = blanks.where((b) => _results[_key(b)] == true).length;
    final all = ok == blanks.length;
    final color = all ? okColor(context) : badColor(context);
    return Row(
      children: [
        Icon(all ? Icons.check_circle : Icons.info_outline, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            all ? 'Chính xác! ($ok/${blanks.length})' : 'Đúng $ok/${blanks.length} từ. Đáp án đã được tô đỏ.',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    final total = _exercise.blanks.length;
    final correct = _results.values.where((v) => v).length;
    final wrong = _exercise.blanks.where((b) => _results[_key(b)] != true).toList();
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ScoreSummary(correct: correct, total: total),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Từ cần ôn lại', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final b in wrong)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(b.answer, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  (_answers[_key(b)] ?? '').trim().isEmpty
                      ? _lyrics.lines[b.lineIndex].en
                      : 'Bạn điền: “${_answers[_key(b)]!.trim()}” · ${_lyrics.lines[b.lineIndex].en}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Lưu vào flashcard',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () => saveWordToFlashcards(ref,
                      word: b.answer, song: _song, line: _lyrics.lines[b.lineIndex]),
                ),
              ),
            ),
        ] else ...[
          const SizedBox(height: 16),
          Text('Tuyệt vời, bạn điền đúng tất cả các từ!',
              textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _restart,
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
}
