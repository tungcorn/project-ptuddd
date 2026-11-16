import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../player/presentation/player_controller.dart';
import '../domain/social_models.dart';

/// Plays a list of "guess the song" questions and reports the score
/// (number of correct answers) through [onFinished].
class ChallengeQuiz extends ConsumerStatefulWidget {
  const ChallengeQuiz({
    super.key,
    required this.questions,
    required this.onFinished,
    this.finishLabel = 'Hoàn thành',
  });

  final List<ChallengeQuestion> questions;
  final Future<void> Function(int score) onFinished;
  final String finishLabel;

  @override
  ConsumerState<ChallengeQuiz> createState() => _ChallengeQuizState();
}

class _ChallengeQuizState extends ConsumerState<ChallengeQuiz> {
  late final PlayerController _player;
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _clipLoading = false;
  bool _clipPlaying = false;
  String? _clipError;
  bool _finishing = false;

  /// Ignores late callbacks from a clip of a previous question.
  int _clipToken = 0;

  ChallengeQuestion get _q => widget.questions[_index];
  bool get _last => _index == widget.questions.length - 1;

  @override
  void initState() {
    super.initState();
    _player = ref.read(playerControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startQuestion());
  }

  @override
  void dispose() {
    _clipToken++;
    _player.cancelSegment();
    _player.pause();
    super.dispose();
  }

  void _startQuestion() {
    if (!mounted) return;
    if (_q.type == ChallengeQuestionType.clip) _playClip();
  }

  Future<void> _playClip() async {
    final token = ++_clipToken;
    final q = _q;
    setState(() {
      _clipLoading = true;
      _clipError = null;
    });
    try {
      final song = await ref.read(songRepositoryProvider).byId(q.songId);
      if (song == null) throw StateError('Không tìm thấy bài hát của câu hỏi này');
      await _player.open(song);
      if (!mounted || token != _clipToken) return;
      final err = ref.read(playerControllerProvider).error;
      if (err != null) throw StateError(err);
      final start = Duration(milliseconds: q.startMs);
      setState(() {
        _clipLoading = false;
        _clipPlaying = true;
      });
      await _player.playSegment(start, start + ChallengeQuestion.clipLength, onEnd: () {
        if (mounted && token == _clipToken) setState(() => _clipPlaying = false);
      });
    } catch (e) {
      if (!mounted || token != _clipToken) return;
      setState(() {
        _clipLoading = false;
        _clipPlaying = false;
        _clipError = e is StateError ? e.message : 'Không phát được đoạn nhạc';
      });
    }
  }

  void _answer(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == _q.answerIndex) _score++;
    });
  }

  Future<void> _next() async {
    _clipToken++;
    _player.cancelSegment();
    await _player.pause();
    if (!mounted) return;
    if (_last) {
      setState(() => _finishing = true);
      try {
        await widget.onFinished(_score);
      } finally {
        if (mounted) setState(() => _finishing = false);
      }
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _clipPlaying = false;
      _clipLoading = false;
      _clipError = null;
    });
    _startQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final q = _q;
    final total = widget.questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: (_index + (_selected == null ? 0 : 1)) / total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Câu ${_index + 1}/$total',
                        style: t.textTheme.labelLarge?.copyWith(color: s.onSurfaceVariant)),
                  ),
                  Text('Điểm: $_score',
                      key: const Key('quiz-score'),
                      style: t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              if (q.type == ChallengeQuestionType.clip) _clipPrompt(context) else _lyricPrompt(context),
              const SizedBox(height: 16),
              for (var i = 0; i < q.options.length; i++) ...[
                _option(context, i),
                const SizedBox(height: 8),
              ],
              if (_selected != null) ...[
                const SizedBox(height: 4),
                _feedback(context),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton(
              key: const Key('quiz-next'),
              onPressed: _selected == null || _finishing ? null : _next,
              child: _finishing
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_last ? widget.finishLabel : 'Câu tiếp theo'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _clipPrompt(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    return Card(
      color: s.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(_clipPlaying ? Icons.graphic_eq : Icons.music_note,
                size: 48, color: s.onSecondaryContainer),
            const SizedBox(height: 8),
            Text('Nghe 10 giây và đoán tên bài hát',
                textAlign: TextAlign.center,
                style: t.textTheme.titleMedium?.copyWith(color: s.onSecondaryContainer)),
            if (_clipError != null) ...[
              const SizedBox(height: 8),
              Text(_clipError!, textAlign: TextAlign.center, style: TextStyle(color: s.error)),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _clipLoading ? null : _playClip,
              icon: _clipLoading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_clipPlaying ? Icons.replay : Icons.play_arrow),
              label: Text(_clipPlaying ? 'Nghe lại từ đầu' : 'Nghe đoạn nhạc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lyricPrompt(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final parts = _q.prompt.split('\n');
    final title = parts.length > 1 ? parts.first : '';
    final line = parts.length > 1 ? parts.sublist(1).join('\n') : _q.prompt;
    return Card(
      color: s.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Điền từ còn thiếu trong lời bài hát',
                style: t.textTheme.labelLarge?.copyWith(color: s.onTertiaryContainer)),
            if (title.isNotEmpty)
              Text('Bài: $title',
                  style: t.textTheme.bodySmall?.copyWith(color: s.onTertiaryContainer)),
            const SizedBox(height: 12),
            Text(line,
                style: t.textTheme.titleLarge?.copyWith(
                    color: s.onTertiaryContainer, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, int i) {
    final s = Theme.of(context).colorScheme;
    final answered = _selected != null;
    final correct = i == _q.answerIndex;
    Color? bg;
    Color? fg;
    IconData? icon;
    if (answered && correct) {
      bg = Colors.green.withValues(alpha: 0.18);
      fg = s.onSurface;
      icon = Icons.check_circle;
    } else if (answered && i == _selected) {
      bg = s.errorContainer;
      fg = s.onErrorContainer;
      icon = Icons.cancel;
    }
    return OutlinedButton(
      key: Key('option-$i'),
      onPressed: answered ? () {} : () => _answer(i),
      style: OutlinedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg ?? s.onSurface,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
            color: answered && correct ? Colors.green : s.outlineVariant,
            width: answered && correct ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_q.options[i], style: const TextStyle(fontSize: 16))),
          if (icon != null) Icon(icon, color: correct ? Colors.green : s.error),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context) {
    final ok = _selected == _q.answerIndex;
    return Text(
      ok ? 'Chính xác!' : 'Chưa đúng. Đáp án: ${_q.options[_q.answerIndex]}',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: ok ? Colors.green.shade600 : Theme.of(context).colorScheme.error,
      ),
    );
  }
}
