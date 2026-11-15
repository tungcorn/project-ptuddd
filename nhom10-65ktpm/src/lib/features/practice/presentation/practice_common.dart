import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/events/app_event_bus.dart';
import '../../../core/providers.dart';
import '../../../core/text/text_utils.dart';
import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../songs/domain/song.dart';
import '../../vocabulary/data/vocabulary_repository.dart';
import '../../vocabulary/domain/saved_word.dart';
import '../domain/exercises.dart';

/// Exercise generator used by every practice screen. Tests override it with
/// a seeded generator to know the generated answers.
final exerciseGeneratorProvider =
    Provider<ExerciseGenerator>((ref) => ExerciseGenerator());

/// A song and its timed lyrics, the input of every exercise.
typedef PracticeData = ({Song song, SongLyrics lyrics});

final practiceDataProvider =
    FutureProvider.family<PracticeData, String>((ref, songId) async {
  final song = await ref.watch(songByIdProvider(songId).future);
  if (song == null) throw StateError('Không tìm thấy bài hát');
  final lyrics = await ref.watch(lyricsProvider(songId).future);
  return (song: song, lyrics: lyrics);
});

/// Only lines that contain at least one word (LRC end markers are empty).
List<LyricLine> singableLines(SongLyrics lyrics) =>
    lyrics.lines.where((l) => wordsOf(l.en).isNotEmpty).toList();

int percentOf(int correct, int total) =>
    total == 0 ? 0 : (correct * 100 / total).round();

/// Reports a finished exercise: emits the learning event (XP is granted by
/// the progress module, idempotent per [eventId]) and stores the best score
/// of the song.
Future<void> reportExerciseResult(
  WidgetRef ref, {
  required String eventId,
  required LearningEventType type,
  required String songId,
  required int correct,
  required int total,
  Map<String, Object?> extra = const {},
}) async {
  ref.read(eventBusProvider).emit(LearningEvent(
        id: eventId,
        type: type,
        uid: ref.read(uidProvider),
        data: {'songId': songId, ...extra, 'correct': correct, 'total': total},
      ));
  try {
    await ref
        .read(songProgressRepositoryProvider)
        .recordExercise(songId, percentOf(correct, total));
  } catch (e) {
    showMessage('Không lưu được kết quả: $e');
  }
}

/// Emits `exerciseCompleted` for the line/word ordering and the quiz.
Future<void> reportOtherExercise(
  WidgetRef ref, {
  required String songId,
  required String kind,
  required int correct,
  required int total,
}) =>
    reportExerciseResult(
      ref,
      eventId: 'exercise:$songId:$kind:${dayKey(DateTime.now())}',
      type: LearningEventType.exerciseCompleted,
      songId: songId,
      correct: correct,
      total: total,
      extra: {'kind': kind},
    );

/// Saves [word] (met in [line] of [song]) to the flashcard deck.
Future<void> saveWordToFlashcards(
  WidgetRef ref, {
  required String word,
  required Song song,
  required LyricLine line,
}) async {
  try {
    final dict = await ref.read(dictionaryProvider.future);
    final r = dict.lookup(word);
    final e = r.entry;
    final outcome = await ref.read(vocabularyRepositoryProvider).save(
          lemma: r.lemma,
          ipa: e?.ipa ?? '',
          pos: e?.pos ?? '',
          meaning: e?.vi ?? '',
          example: e?.example ?? '',
          exampleVi: e?.exampleVi ?? '',
          context: WordContext(
            songId: song.id,
            songTitle: song.title,
            lineIndex: line.index,
            line: line.en,
            lineVi: line.vi,
            startMs: line.start.inMilliseconds,
            endMs: line.end.inMilliseconds,
          ),
        );
    final w = r.lemma;
    showMessage(switch (outcome) {
      SaveWordOutcome.created => e == null
          ? 'Đã lưu “$w” (chưa có nghĩa trong từ điển offline)'
          : 'Đã lưu “$w” vào flashcard',
      SaveWordOutcome.contextAdded => 'Đã thêm ngữ cảnh mới cho “$w”',
      SaveWordOutcome.alreadySaved => '“$w” đã có trong flashcard',
      SaveWordOutcome.restored => 'Đã khôi phục “$w” vào flashcard',
    });
  } catch (err) {
    showMessage('Không lưu được từ: $err');
  }
}

/// Loads [PracticeData] and opens the song in the shared player, then shows
/// [builder]. Handles loading / error states for all exercise screens.
class PracticeScaffold extends ConsumerWidget {
  const PracticeScaffold({
    super.key,
    required this.songId,
    required this.title,
    required this.builder,
  });

  final String songId;
  final String title;
  final Widget Function(BuildContext context, PracticeData data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(practiceDataProvider(songId));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: data.hasValue
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      data.value!.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e is StateError ? e.message : e,
          onRetry: () {
            ref.invalidate(allSongsProvider);
            ref.invalidate(lyricsProvider(songId));
            ref.invalidate(practiceDataProvider(songId));
          },
        ),
        data: (d) => _PlayerOpener(
          song: d.song,
          child: Builder(builder: (context) => builder(context, d)),
        ),
      ),
    );
  }
}

/// Opens the song in the player once and stops any segment on leave.
class _PlayerOpener extends ConsumerStatefulWidget {
  const _PlayerOpener({required this.song, required this.child});

  final Song song;
  final Widget child;

  @override
  ConsumerState<_PlayerOpener> createState() => _PlayerOpenerState();
}

class _PlayerOpenerState extends ConsumerState<_PlayerOpener> {
  late final PlayerController _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(playerControllerProvider.notifier);
    // Providers must not change while the widget tree is building.
    Future.microtask(() {
      if (mounted) _player.open(widget.song);
    });
  }

  @override
  void dispose() {
    _player.cancelSegment();
    _player.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(playerControllerProvider.select(
        (s) => s.song?.id == widget.song.id ? s.error : null));
    if (error == null) return widget.child;
    return Column(
      children: [
        MaterialBanner(
          content: const Text(
              'Không phát được âm thanh của bài. Bạn vẫn có thể làm bài tập.'),
          leading: const Icon(Icons.volume_off),
          actions: [
            TextButton(
              onPressed: () => _player.open(widget.song),
              child: const Text('Thử lại'),
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// Plays one lyric line once in the shared player.
Future<void> playLyricLine(WidgetRef ref, int lineIndex, {VoidCallback? onEnd}) async {
  final player = ref.read(playerControllerProvider.notifier);
  // May be called from initState: never touch providers during a build.
  await Future<void>.microtask(() {});
  // The player may still be loading the song; wait briefly for lyrics.
  for (var i = 0; i < 50; i++) {
    if (!ref.context.mounted) return;
    final s = ref.read(playerControllerProvider);
    if (s.lyrics != null || s.error != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  if (!ref.context.mounted) return;
  await player.playLine(lineIndex, onEnd: onEnd);
}

/// Large score summary shown at the end of an exercise.
class ScoreSummary extends StatelessWidget {
  const ScoreSummary({
    super.key,
    required this.correct,
    required this.total,
    this.title = 'Hoàn thành!',
  });

  final int correct;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = percentOf(correct, total);
    final color = p >= 80
        ? Colors.green
        : p >= 50
            ? t.colorScheme.tertiary
            : t.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(p >= 80 ? Icons.emoji_events : Icons.flag, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: t.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$correct/$total',
                key: const Key('summary-score'),
                style: t.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            Text('Đúng $p%', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : correct / total,
                minHeight: 8,
                color: color,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green / red colours that stay readable in light and dark mode.
Color okColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;

Color badColor(BuildContext context) => Theme.of(context).colorScheme.error;

/// Fixed bottom action bar for exercise screens.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: children[i]),
                ],
              ],
            ),
          ),
        ),
      );
}
