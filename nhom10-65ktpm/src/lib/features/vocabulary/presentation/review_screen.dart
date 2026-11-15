import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/widgets.dart';
import '../domain/saved_word.dart';
import '../domain/sm2.dart';
import 'vocabulary_screen.dart';

/// Flashcard review session over the cards due now (section 7.9).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<SavedWord>? _queue;
  int _index = 0;
  bool _flipped = false;
  bool _busy = false;
  final _results = <ReviewGrade>[];

  @override
  void initState() {
    super.initState();
    // Snapshot the due list once so cards don't disappear mid-session.
    ref.read(vocabularyRepositoryProvider).due().then((list) {
      if (mounted) setState(() => _queue = list);
    });
  }

  Future<void> _grade(ReviewGrade g) async {
    final w = _queue![_index];
    setState(() => _busy = true);
    try {
      await ref.read(vocabularyRepositoryProvider).review(w.id, g);
      _results.add(g);
      setState(() {
        _index++;
        _flipped = false;
      });
    } catch (e) {
      showMessage('Không lưu được kết quả ôn: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    return Scaffold(
      appBar: AppBar(
        title: Text(queue == null || _index >= queue.length
            ? 'Ôn tập flashcard'
            : 'Ôn tập ${_index + 1}/${queue.length}'),
      ),
      body: queue == null
          ? const LoadingView()
          : queue.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Không có từ cần ôn',
                  message: 'Hãy quay lại vào ngày ôn tiếp theo theo lịch SM-2.',
                )
              : _index >= queue.length
                  ? _Summary(results: _results)
                  : _card(context, queue[_index]),
    );
  }

  Widget _card(BuildContext context, SavedWord w) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    final ctx = w.contexts.isEmpty ? null : w.contexts.last;
    final now = DateTime.now();
    String preview(ReviewGrade g) {
      final days = Sm2.review(w.sm2, g.quality, now).intervalDays;
      return days <= 1 ? '1 ngày' : '$days ngày';
    }

    return SafeArea(
      child: Column(
        children: [
          LinearProgressIndicator(value: _index / _queue!.length),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                key: const Key('flashcard'),
                onTap: () => setState(() => _flipped = !_flipped),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: _flipped ? 1 : 0),
                  duration: const Duration(milliseconds: 350),
                  builder: (context, v, _) {
                    final showBack = v >= 0.5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(v * math.pi),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: showBack ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
                        child: Card(
                          color: showBack ? c.secondaryContainer : c.primaryContainer,
                          child: SizedBox.expand(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: showBack
                                  ? Column(children: [
                                      Text(w.meaning,
                                          key: const Key('card-back'),
                                          textAlign: TextAlign.center,
                                          style: t.textTheme.headlineSmall),
                                      const SizedBox(height: 12),
                                      Text('${w.ipa}  ${w.pos}', style: t.textTheme.titleMedium),
                                      if (w.example.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(w.example,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontStyle: FontStyle.italic)),
                                        Text(w.exampleVi, textAlign: TextAlign.center),
                                      ],
                                      if (ctx != null && ctx.lineVi.isNotEmpty) ...[
                                        const SizedBox(height: 16),
                                        Text(ctx.lineVi, textAlign: TextAlign.center,
                                            style: t.textTheme.bodySmall),
                                      ],
                                    ])
                                  : Column(children: [
                                      const SizedBox(height: 24),
                                      Text(w.word,
                                          key: const Key('card-front'),
                                          style: t.textTheme.displaySmall
                                              ?.copyWith(fontWeight: FontWeight.w800)),
                                      if (ctx != null) ...[
                                        const SizedBox(height: 24),
                                        Text('“${ctx.line}”',
                                            textAlign: TextAlign.center,
                                            style: t.textTheme.titleMedium),
                                        Text(ctx.songTitle, style: t.textTheme.bodySmall),
                                      ],
                                      const SizedBox(height: 24),
                                      Text('Chạm để lật thẻ', style: t.textTheme.labelMedium),
                                    ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => ref.read(speechServiceProvider).speak(w.word),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Phát âm'),
                ),
                if (ctx != null)
                  OutlinedButton.icon(
                    onPressed: () => playWordContext(ref, ctx),
                    icon: const Icon(Icons.music_note),
                    label: const Text('Nghe đoạn nhạc'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _flipped
                ? Row(children: [
                    for (final g in ReviewGrade.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FilledButton.tonal(
                            key: Key('grade-${g.name}'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              backgroundColor: switch (g) {
                                ReviewGrade.forgot => c.errorContainer,
                                ReviewGrade.hard => c.tertiaryContainer,
                                ReviewGrade.good => c.secondaryContainer,
                                ReviewGrade.easy => c.primaryContainer,
                              },
                            ),
                            onPressed: _busy ? null : () => _grade(g),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(g.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(preview(g), style: t.textTheme.labelSmall),
                            ]),
                          ),
                        ),
                      ),
                  ])
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('show-answer'),
                      onPressed: () => setState(() => _flipped = true),
                      child: const Text('Xem nghĩa'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.results});

  final List<ReviewGrade> results;

  @override
  Widget build(BuildContext context) {
    final correct = results.where((g) => g.isCorrect).length;
    return EmptyState(
      icon: Icons.celebration,
      title: 'Hoàn thành phiên ôn tập!',
      message: 'Nhớ $correct/${results.length} từ. '
          'Lịch ôn tiếp theo đã được cập nhật theo SM-2.',
      action: FilledButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Xong'),
      ),
    );
  }
}
