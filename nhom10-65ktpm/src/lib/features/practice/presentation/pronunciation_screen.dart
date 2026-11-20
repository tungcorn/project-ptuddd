import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/events/app_event_bus.dart';
import '../../../core/providers.dart';
import '../../../core/ui/widgets.dart';
import '../../player/presentation/player_controller.dart';
import '../../songs/domain/song.dart';
import '../domain/pronunciation_scorer.dart';
import 'practice_common.dart';
import 'speech_recognizer.dart';

/// "Luyện hát & chấm phát âm" (section 7.8): listen to a line, say/sing it,
/// get an approximate intelligibility score from speech recognition.
class PronunciationScreen extends StatelessWidget {
  const PronunciationScreen({super.key, required this.songId, this.initialLine});
  final String songId;
  final int? initialLine;

  @override
  Widget build(BuildContext context) => PracticeScaffold(
        songId: songId,
        title: 'Luyện phát âm',
        builder: (context, data) =>
            _PronunciationBody(data: data, initialLine: initialLine),
      );
}

enum _Phase {
  idle,
  preparing,
  preparationTimeout,
  listening,
  stopping,
  scored,
  noSpeech,
  unavailable,
  permissionDenied,
  permissionPermanent,
  failed,
}

class _PronunciationBody extends ConsumerStatefulWidget {
  const _PronunciationBody({required this.data, this.initialLine});

  final PracticeData data;
  final int? initialLine;

  @override
  ConsumerState<_PronunciationBody> createState() => _PronunciationBodyState();
}

class _PronunciationBodyState extends ConsumerState<_PronunciationBody>
    with WidgetsBindingObserver {
  late final List<LyricLine> _lines = singableLines(widget.data.lyrics);
  late final SpeechRecognizer _recognizer;
  late final PlayerController _player;

  int _pos = 0;
  _Phase _phase = _Phase.idle;
  String _partial = '';
  List<String> _alternatives = const [];
  PronunciationResult? _result;
  int _session = 0;
  Timer? _preparationTimer;

  bool get _receivingResults =>
      _phase == _Phase.listening || _phase == _Phase.stopping;

  bool get _recognizing => _phase == _Phase.preparing || _receivingResults;

  bool _isCurrent(int session) => mounted && session == _session;

  // Permission dialogs and platform initialization can fail to complete.
  // Invalidate this attempt so a late response cannot start the microphone.
  void _preparationTimedOut(int session) {
    if (!_isCurrent(session) || _phase != _Phase.preparing) return;
    _session++;
    unawaited(_cancelRecognition());
    setState(() => _phase = _Phase.preparationTimeout);
  }

  Future<void> _cancelRecognition() async {
    try {
      await _recognizer.cancel();
    } catch (_) {
      // Cleanup is best effort; leaving the screen must not throw.
    }
  }

  LyricLine get _line => _lines[_pos];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recognizer = ref.read(speechRecognizerProvider);
    _player = ref.read(playerControllerProvider.notifier);
    final initial = widget.initialLine;
    if (initial != null) {
      final i = _lines.indexWhere((l) => l.index == initial);
      if (i >= 0) _pos = i;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session++;
    _preparationTimer?.cancel();
    if (_recognizing) unawaited(_cancelRecognition());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted ||
        (state != AppLifecycleState.paused && state != AppLifecycleState.detached) ||
        !_recognizing) {
      return;
    }
    // A permission dialog can temporarily make the app inactive. Only
    // abandon recognition when the app actually pauses or detaches.
    _session++;
    _preparationTimer?.cancel();
    unawaited(_cancelRecognition());
    setState(() {
      _phase = _Phase.idle;
      _result = null;
      _partial = '';
      _alternatives = const [];
    });
  }

  void _select(int pos) {
    if (pos < 0 || pos >= _lines.length || pos == _pos) return;
    _session++;
    _preparationTimer?.cancel();
    if (_recognizing) unawaited(_cancelRecognition());
    _player.cancelSegment();
    _player.pause();
    setState(() {
      _pos = pos;
      _phase = _Phase.idle;
      _result = null;
      _partial = '';
    });
  }

  Future<void> _openSettings() async {
    final session = _session;
    try {
      await _recognizer.openSettings();
    } catch (_) {
      if (_isCurrent(session)) {
        showMessage('Không mở được cài đặt. Hãy mở quyền micro trong '
            'Cài đặt của thiết bị rồi thử lại.');
      }
    }
  }

  Future<void> _listenSample() async {
    final session = _session;
    if (_recognizing) {
      if (_phase != _Phase.listening) return;
      if (!await _stop()) return;
    }
    if (!_isCurrent(session)) return;
    await playLyricLine(ref, _line.index);
  }

  Future<void> _start() async {
    if (_recognizing) return;
    final session = ++_session;
    setState(() {
      _phase = _Phase.preparing;
      _result = null;
      _partial = '';
      _alternatives = const [];
    });
    _preparationTimer?.cancel();
    final timer = Timer(
      const Duration(seconds: 30),
      () => _preparationTimedOut(session),
    );
    _preparationTimer = timer;
    try {
      // The microphone must not pick up the music.
      _player.cancelSegment();
      await _player.pause();
      if (!_isCurrent(session)) return;

      final permission = await _recognizer.ensurePermission();
      if (!_isCurrent(session)) return;
      if (permission != MicPermission.granted) {
        setState(() => _phase = permission == MicPermission.permanentlyDenied
            ? _Phase.permissionPermanent
            : _Phase.permissionDenied);
        return;
      }
      final available = await _recognizer.initialize();
      if (!_isCurrent(session)) return;
      if (!available) {
        setState(() => _phase = _Phase.unavailable);
        return;
      }
      timer.cancel();
      setState(() => _phase = _Phase.listening);
      await _recognizer.listen(
        onResult: (heard) {
          if (!_isCurrent(session) || !_receivingResults) return;
          final alts = heard.alternatives.where((a) => a.trim().isNotEmpty).toList();
          if (alts.isNotEmpty) {
            _alternatives = alts;
            setState(() => _partial = alts.first);
          }
          if (heard.isFinal) _finish(session);
        },
        onError: (failure) {
          if (!_isCurrent(session) || !_receivingResults) return;
          if (_alternatives.isNotEmpty) {
            _finish(session);
            return;
          }
          setState(() => _phase = switch (failure) {
                SpeechFailure.noSpeech => _Phase.noSpeech,
                SpeechFailure.permission => _Phase.permissionDenied,
                SpeechFailure.other => _Phase.failed,
              });
        },
        onDone: () => _finish(session),
      );
    } catch (_) {
      if (_isCurrent(session) && _recognizing) {
        _session++;
        unawaited(_cancelRecognition());
        setState(() => _phase = _Phase.failed);
      }
    } finally {
      // A stale attempt must not cancel the next attempt's watchdog.
      timer.cancel();
    }
  }

  Future<bool> _stop() async {
    if (_phase != _Phase.listening) return false;
    final session = _session;
    setState(() => _phase = _Phase.stopping);
    try {
      // Some engines deliver their final result while stop is pending.
      await _recognizer.stop();
      if (!_isCurrent(session)) return false;
      _finish(session);
      return _phase == _Phase.scored || _phase == _Phase.noSpeech;
    } catch (_) {
      if (_isCurrent(session) && _phase == _Phase.stopping) {
        _session++;
        unawaited(_cancelRecognition());
        setState(() => _phase = _Phase.failed);
      }
      // A late stop error must not replace a result already finalized by
      // onResult/onDone, or affect a newer session after leaving this one.
      return false;
    }
  }

  /// Scores the best of the collected alternatives (once per session).
  void _finish(int session) {
    if (!_isCurrent(session) || !_receivingResults) return;
    if (_alternatives.isEmpty) {
      setState(() => _phase = _Phase.noSpeech);
      return;
    }
    final result = PronunciationScorer.score(_line.en, _alternatives);
    setState(() {
      _phase = _Phase.scored;
      _result = result;
    });
    _save(result.score);
  }

  Future<void> _save(int score) async {
    final song = widget.data.song;
    final line = _line;
    final today = dayKey(DateTime.now());
    final id = score >= 70
        ? 'pron:${song.id}:${line.index}:$today'
        : 'pron:${song.id}:${line.index}:$today:try:${DateTime.now().millisecondsSinceEpoch}';
    ref.read(eventBusProvider).emit(LearningEvent(
          id: id,
          type: LearningEventType.pronunciationScored,
          uid: ref.read(uidProvider),
          data: {'songId': song.id, 'lineIndex': line.index, 'score': score},
        ));
    try {
      await ref
          .read(songProgressRepositoryProvider)
          .recordPronunciation(song.id, line.index, score, lineCount: _lines.length);
    } catch (e) {
      showMessage('Không lưu được điểm: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      return const EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'Bài hát chưa có lời để luyện',
      );
    }
    final t = Theme.of(context);
    final progress = ref.watch(songProgressProvider).value?[widget.data.song.id];
    final best = progress?.lineBestScores ?? const <int, int>{};
    final playing = ref.watch(playerControllerProvider.select((s) => s.playing));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Câu trước',
              onPressed: _pos > 0 ? () => _select(_pos - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text('Câu ${_pos + 1}/${_lines.length}',
                  textAlign: TextAlign.center, style: t.textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Câu sau',
              onPressed: _pos + 1 < _lines.length ? () => _select(_pos + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _targetSentence(context),
                if (_line.vi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_line.vi,
                      style: t.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: t.colorScheme.onSurfaceVariant)),
                ],
                if (best[_line.index] != null) ...[
                  const SizedBox(height: 8),
                  Text('Điểm cao nhất câu này: ${best[_line.index]}',
                      key: const Key('line-best'), style: t.textTheme.labelMedium),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: _phase == _Phase.preparing || _phase == _Phase.stopping
                  ? null
                  : _listenSample,
              icon: Icon(playing ? Icons.graphic_eq : Icons.hearing),
              label: const Text('Nghe mẫu'),
            ),
            _micButton(context),
          ],
        ),
        const SizedBox(height: 16),
        _statusPanel(context),
        const SizedBox(height: 16),
        Text(
          'Lưu ý: Điểm dựa trên nhận dạng giọng nói, là ước lượng gần đúng, '
          'không chấm cao độ/nhịp.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SectionTitle('Tất cả các câu'),
        for (var i = 0; i < _lines.length; i++)
          ListTile(
            dense: true,
            selected: i == _pos,
            selectedTileColor: t.colorScheme.primaryContainer.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Text('${i + 1}', style: t.textTheme.labelLarge),
            title: Text(_lines[i].en, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: best[_lines[i].index] == null
                ? null
                : _ScoreBadge(score: best[_lines[i].index]!),
            onTap: () => _select(i),
          ),
      ],
    );
  }

  Widget _targetSentence(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    final marks = _result?.marks;
    if (marks == null) return Text(_line.en, style: style);
    return Wrap(
      key: const Key('marked-sentence'),
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final m in marks)
          Text(
            m.word,
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: m.correct ? okColor(context) : badColor(context),
              decoration: m.correct ? null : TextDecoration.underline,
            ),
          ),
      ],
    );
  }

  Widget _micButton(BuildContext context) {
    final t = Theme.of(context);
    final listening = _phase == _Phase.listening;
    final preparing = _phase == _Phase.preparing;
    final stopping = _phase == _Phase.stopping;
    final busy = preparing || stopping;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: FilledButton(
            key: const Key('mic-button'),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: listening ? t.colorScheme.error : t.colorScheme.primary,
              foregroundColor: listening ? t.colorScheme.onError : t.colorScheme.onPrimary,
            ),
            onPressed: busy ? null : (listening ? _stop : _start),
            child: busy
                ? const SizedBox(
                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : Icon(listening ? Icons.stop : Icons.mic, size: 32),
          ),
        ),
        const SizedBox(height: 4),
        Text(stopping ? 'Đang dừng' : (listening ? 'Nhấn để dừng' : 'Nhấn để nói'),
            style: t.textTheme.labelSmall),
      ],
    );
  }

  Widget _statusPanel(BuildContext context) {
    final t = Theme.of(context);
    switch (_phase) {
      case _Phase.idle:
      case _Phase.preparing:
        return Text(
          'Nghe mẫu, sau đó nhấn micro và hát/đọc lại câu bằng tiếng Anh.',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium,
        );
      case _Phase.listening:
        return Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_partial.isEmpty ? 'Đang nghe… hãy nói ngay' : _partial,
                textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
          ],
        );
      case _Phase.stopping:
        return Text(
          'Đang dừng nhận dạng…',
          textAlign: TextAlign.center,
          style: t.textTheme.bodyMedium,
        );
      case _Phase.scored:
        return _resultCard(context, _result!);
      case _Phase.noSpeech:
        return _InfoPanel(
          icon: Icons.hearing_disabled,
          title: 'Không nghe thấy giọng nói',
          message: 'Hãy nói to, rõ ràng và gần micro hơn, rồi thử lại.',
          actions: [FilledButton.tonal(onPressed: _start, child: const Text('Thử lại'))],
        );
      case _Phase.unavailable:
        return const _InfoPanel(
          icon: Icons.mic_off,
          title: 'Thiết bị không hỗ trợ nhận dạng giọng nói',
          message: 'Hãy cài/bật dịch vụ nhận dạng giọng nói của Google '
              '(ứng dụng Google) và gói ngôn ngữ tiếng Anh, rồi thử lại.',
        );
      case _Phase.preparationTimeout:
        return _InfoPanel(
          icon: Icons.timer_off_outlined,
          title: 'Chuẩn bị micro quá lâu',
          message: 'Nếu hộp thoại quyền micro còn mở, hãy xử lý hộp thoại '
              'rồi thử lại. Bạn cũng có thể thoát màn và quay lại sau.',
          actions: [FilledButton.tonal(onPressed: _start, child: const Text('Thử lại'))],
        );
      case _Phase.failed:
        return _InfoPanel(
          icon: Icons.error_outline,
          title: 'Nhận dạng giọng nói gặp lỗi',
          message: 'Kiểm tra kết nối mạng hoặc thử lại sau.',
          actions: [FilledButton.tonal(onPressed: _start, child: const Text('Thử lại'))],
        );
      case _Phase.permissionDenied:
      case _Phase.permissionPermanent:
        final permanent = _phase == _Phase.permissionPermanent;
        return _InfoPanel(
          key: const Key('mic-permission-view'),
          icon: Icons.mic_off,
          title: 'Cần quyền sử dụng micro',
          message: permanent
              ? 'Bạn đã từ chối quyền micro. Để chấm phát âm, hãy mở Cài đặt → '
                  'Quyền → Micro và cho phép SingLearn, rồi quay lại nhấn “Thử lại”.'
              : 'SingLearn cần micro để nghe bạn hát/đọc và chấm phát âm. '
                  'Giọng nói chỉ được nhận dạng để tính điểm, không được lưu lại.',
          actions: [
            FilledButton.tonal(onPressed: _start, child: const Text('Thử lại')),
            OutlinedButton(
              onPressed: _openSettings,
              child: const Text('Mở cài đặt'),
            ),
          ],
        );
    }
  }

  Widget _resultCard(BuildContext context, PronunciationResult r) {
    final t = Theme.of(context);
    final color = r.score >= 70
        ? okColor(context)
        : r.score >= 50
            ? t.colorScheme.tertiary
            : badColor(context);
    return Card(
      key: const Key('pron-result'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${r.score}',
                key: const Key('pron-score'),
                style: t.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
            Text(r.rating.label,
                style: t.textTheme.titleMedium?.copyWith(color: color)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Máy nghe được:', style: t.textTheme.labelLarge),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('“${r.recognized}”',
                  key: const Key('pron-recognized'), style: t.textTheme.bodyLarge),
            ),
            const SizedBox(height: 8),
            Text('Các từ màu đỏ là từ máy chưa nhận ra, hãy luyện thêm.',
                style: t.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _start,
                  icon: const Icon(Icons.mic),
                  label: const Text('Thử lại'),
                ),
                if (_pos + 1 < _lines.length)
                  FilledButton.icon(
                    onPressed: () => _select(_pos + 1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Câu tiếp'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      color: t.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: t.colorScheme.error),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final c = score >= 70 ? okColor(context) : badColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$score', style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    );
  }
}
