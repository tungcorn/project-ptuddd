import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/widgets.dart';
import '../domain/exercises.dart';
import 'practice_common.dart';

/// "Trắc nghiệm nghĩa": keyword meanings + line translations.
class MeaningQuizScreen extends StatelessWidget {
  const MeaningQuizScreen({super.key, required this.songId});
  final String songId;

  @override
  Widget build(BuildContext context) => PracticeScaffold(
        songId: songId,
        title: 'Trắc nghiệm nghĩa',
        builder: (context, data) => _QuizLoader(data: data),
      );
}

/// Waits for the dictionary (keyword meanings) before building questions.
class _QuizLoader extends ConsumerWidget {
  const _QuizLoader({required this.data});

  final PracticeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(dictionaryProvider).when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(dictionaryProvider),
            ),
            data: (dict) {
              final meanings = <String, String>{};
              for (final k in data.song.keywords) {
                final vi = dict.lookup(k).entry?.vi ?? '';
                if (vi.isNotEmpty) meanings[k] = vi;
              }
              return _QuizBody(data: data, keywordMeanings: meanings);
            },
          );
}

class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.data, required this.keywordMeanings});

  final PracticeData data;
  final Map<String, String> keywordMeanings;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody> {
  late List<QuizQuestion> _questions;
  int _pos = 0;
  int _correct = 0;
  int? _chosen;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _questions = ref.read(exerciseGeneratorProvider).meaningQuiz(
          widget.data.lyrics,
          keywordMeanings: widget.keywordMeanings,
        );
    _pos = 0;
    _correct = 0;
    _chosen = null;
    _finished = false;
  }

  void _choose(int i) {
    if (_chosen != null) return;
    setState(() {
      _chosen = i;
      if (i == _questions[_pos].answerIndex) _correct++;
    });
  }

  void _next() {
    if (_pos + 1 >= _questions.length) {
      setState(() => _finished = true);
      reportOtherExercise(ref,
          songId: widget.data.song.id,
          kind: 'quiz',
          correct: _correct,
          total: _questions.length);
      return;
    }
    setState(() {
      _pos++;
      _chosen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const EmptyState(
        icon: Icons.quiz_outlined,
        title: 'Chưa đủ dữ liệu để tạo câu hỏi',
        message: 'Bài hát cần có bản dịch hoặc từ khóa. Hãy chọn bài khác.',
      );
    }
    if (_finished) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ScoreSummary(correct: _correct, total: _questions.length),
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
    final q = _questions[_pos];
    final answered = _chosen != null;
    return Column(
      children: [
        LinearProgressIndicator(value: (_pos + (answered ? 1 : 0)) / _questions.length),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Câu ${_pos + 1}/${_questions.length}', style: t.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(q.prompt, style: t.textTheme.titleMedium),
              if (q.lineIndex != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => playLyricLine(ref, q.lineIndex!),
                    icon: const Icon(Icons.hearing),
                    label: const Text('Nghe câu'),
                  ),
                ),
              const SizedBox(height: 12),
              for (var i = 0; i < q.options.length; i++)
                _option(context, q, i),
              if (answered) ...[
                const SizedBox(height: 8),
                Text(
                  _chosen == q.answerIndex ? 'Chính xác!' : 'Chưa đúng. Đáp án: ${q.options[q.answerIndex]}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _chosen == q.answerIndex ? okColor(context) : badColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        ActionBar(children: [
          FilledButton.icon(
            onPressed: answered ? _next : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(_pos + 1 >= _questions.length ? 'Xem kết quả' : 'Câu tiếp'),
          ),
        ]),
      ],
    );
  }

  Widget _option(BuildContext context, QuizQuestion q, int i) {
    final t = Theme.of(context);
    final answered = _chosen != null;
    final isAnswer = i == q.answerIndex;
    Color? border;
    IconData? icon;
    if (answered && isAnswer) {
      border = okColor(context);
      icon = Icons.check_circle;
    } else if (answered && i == _chosen) {
      border = badColor(context);
      icon = Icons.cancel;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: border?.withValues(alpha: 0.1) ?? t.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border ?? t.colorScheme.outlineVariant, width: border == null ? 1 : 2),
        ),
        child: InkWell(
          key: Key('quiz-option-$i'),
          borderRadius: BorderRadius.circular(12),
          onTap: answered ? null : () => _choose(i),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: Text(q.options[i], style: t.textTheme.bodyLarge)),
                if (icon != null) Icon(icon, color: border),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
