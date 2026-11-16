import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/events/app_event_bus.dart';
import '../../../core/providers.dart';
import '../../../core/router.dart';
import '../../../core/ui/widgets.dart';
import '../../auth/domain/app_user.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';
import 'challenge_quiz.dart';
import 'social_widgets.dart';

/// Reports a finished challenge to the progress module (XP is never written
/// here). The id makes it idempotent: one award per user per challenge.
void emitChallengeCompleted(WidgetRef ref, Challenge c, String uid, int score) {
  ref.read(eventBusProvider).emit(LearningEvent(
        id: 'challenge:${c.id}:$uid',
        type: LearningEventType.challengeCompleted,
        uid: uid,
        data: {'challengeId': c.id, 'score': score, 'won': c.winner == uid},
      ));
}

String _resultLabel(Challenge c, String me) {
  final w = c.winner;
  if (w == null) return 'Hòa';
  return w == me ? 'Thắng' : 'Thua';
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

/// "Đoán tên bài hát" challenges: to play, sent and finished.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    // The challenger played before the result was known; award their XP
    // (with the win bonus) once the friend has finished.
    ref.listenManual(challengesProvider, (_, next) {
      final me = ref.read(currentUserProvider);
      final list = next.value;
      if (me == null || me.isGuest || list == null) return;
      for (final c in list) {
        if (c.fromUid == me.uid && c.status == ChallengeStatus.completed) {
          emitChallengeCompleted(ref, c, me.uid, c.fromScore);
        }
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final guest = user == null || user.isGuest;
    return Scaffold(
      appBar: AppBar(title: const Text('Đoán tên bài hát')),
      floatingActionButton: guest
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newChallenge),
              icon: const Icon(Icons.add),
              label: const Text('Tạo thử thách'),
            ),
      body: guest
          ? const GuestSocialNotice()
          : ref.watch(challengesProvider).when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: socialErrorText(e),
                  onRetry: () => ref.invalidate(challengesProvider),
                ),
                data: (list) => _list(context, user.uid, list),
              ),
    );
  }

  Widget _list(BuildContext context, String me, List<Challenge> list) {
    final toPlay = [
      for (final c in list)
        if (c.toUid == me && c.status == ChallengeStatus.waiting) c,
    ];
    final sentWaiting = [
      for (final c in list)
        if (c.fromUid == me && c.status == ChallengeStatus.waiting) c,
    ];
    final done = [
      for (final c in list)
        if (c.status != ChallengeStatus.waiting) c,
    ];
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.sports_esports_outlined,
        title: 'Chưa có thử thách nào',
        message: 'Thách một người bạn “Đoán tên bài hát”: nghe 10 giây hoặc '
            'điền từ còn thiếu, ai đúng nhiều hơn sẽ thắng.',
        action: FilledButton.icon(
          onPressed: () => context.push(Routes.newChallenge),
          icon: const Icon(Icons.add),
          label: const Text('Tạo thử thách'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(challengesProvider);
        await ref.read(challengesProvider.future).catchError((_) => <Challenge>[]);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (toPlay.isNotEmpty) ...[
            SectionTitle('Chờ bạn chơi (${toPlay.length})'),
            for (final c in toPlay)
              ListTile(
                leading: NameAvatar(c.fromName),
                title: Text('${c.fromName} thách bạn',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${c.questions.length} câu · đối thủ được ${c.fromScore} điểm'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16)),
                  onPressed: () => context.push(Routes.playChallenge(c.id)),
                  child: const Text('Chơi'),
                ),
              ),
          ],
          if (sentWaiting.isNotEmpty) ...[
            SectionTitle('Đã gửi (${sentWaiting.length})'),
            for (final c in sentWaiting)
              ListTile(
                leading: NameAvatar(c.toName),
                title: Text('Gửi ${c.toName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Bạn được ${c.fromScore}/${c.questions.length} · '
                    'đang chờ ${c.toName} chơi'),
                trailing: const Icon(Icons.hourglass_top),
              ),
          ],
          if (done.isNotEmpty) ...[
            const SectionTitle('Đã kết thúc'),
            for (final c in done) _DoneTile(challenge: c, me: me),
          ],
        ],
      ),
    );
  }
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.challenge, required this.me});

  final Challenge challenge;
  final String me;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final s = Theme.of(context).colorScheme;
    final iAmFrom = c.fromUid == me;
    final otherName = iAmFrom ? c.toName : c.fromName;
    if (c.status == ChallengeStatus.declined) {
      return ListTile(
        leading: NameAvatar(otherName),
        title: Text(otherName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: const Text('Đã từ chối thử thách'),
      );
    }
    final myScore = iAmFrom ? c.fromScore : (c.toScore ?? 0);
    final otherScore = iAmFrom ? (c.toScore ?? 0) : c.fromScore;
    final label = _resultLabel(c, me);
    final color = switch (label) {
      'Thắng' => Colors.green.shade600,
      'Thua' => s.error,
      _ => s.onSurfaceVariant,
    };
    return ListTile(
      leading: NameAvatar(otherName),
      title: Text(iAmFrom ? 'Bạn thách $otherName' : '$otherName thách bạn',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Bạn $myScore – $otherScore $otherName',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create
// ---------------------------------------------------------------------------

enum _NewStep { pick, generating, playing, saving, sent }

/// Pick a friend, generate 6 questions, play them first, then send.
class NewChallengeScreen extends ConsumerStatefulWidget {
  const NewChallengeScreen({super.key, this.friendUid, this.random});

  /// Preselected friend; defaults to the `to` query parameter.
  final String? friendUid;

  /// Seeded generator for tests.
  final Random? random;

  @override
  ConsumerState<NewChallengeScreen> createState() => _NewChallengeScreenState();
}

class _NewChallengeScreenState extends ConsumerState<NewChallengeScreen> {
  _NewStep _step = _NewStep.pick;
  String? _friend;
  String? _error;
  List<ChallengeQuestion> _questions = const [];
  int _score = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _friend = widget.friendUid ??
        (GoRouter.maybeOf(context) == null
            ? null
            : GoRouterState.of(context).uri.queryParameters['to']);
  }

  Future<void> _generate() async {
    setState(() {
      _step = _NewStep.generating;
      _error = null;
    });
    try {
      final repo = ref.read(songRepositoryProvider);
      final songs = await repo.visibleSongs();
      final qs = await ChallengeGenerator(widget.random).generate(songs, repo.lyrics);
      if (qs.isEmpty) throw StateError('Không tạo được câu hỏi từ thư viện bài hát');
      if (!mounted) return;
      setState(() {
        _questions = qs;
        _step = _NewStep.playing;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _NewStep.pick;
        _error = e is StateError ? e.message : 'Không tạo được thử thách: $e';
      });
    }
  }

  Future<void> _save(AppUser me, int score) async {
    setState(() {
      _score = score;
      _step = _NewStep.saving;
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      final friend = await repo.profile(_friend!);
      final now = DateTime.now().millisecondsSinceEpoch;
      final c = Challenge(
        id: newChallengeId(),
        fromUid: me.uid,
        fromName: me.displayName,
        toUid: _friend!,
        toName: friend?.displayName ?? 'Bạn bè',
        questions: _questions,
        fromScore: score,
        status: ChallengeStatus.waiting,
        createdAt: now,
        updatedAt: now,
      );
      await repo.saveChallenge(c);
      ref.invalidate(challengesProvider);
      showMessage('Đã gửi thử thách tới ${c.toName} – bạn được $score/${_questions.length} điểm');
      if (!mounted) return;
      setState(() => _step = _NewStep.sent);
      // Pop after the rebuild so PopScope no longer blocks it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    } catch (e) {
      if (!mounted) return;
      showMessage('Không gửi được thử thách. ${socialErrorText(e)}');
      setState(() => _step = _NewStep.playing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return PopScope(
      canPop: _step != _NewStep.playing && _step != _NewStep.saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _step != _NewStep.playing) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          setState(() => _step = _NewStep.pick);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Tạo thử thách')),
        body: user == null || user.isGuest ? const GuestSocialNotice() : _body(context, user),
      ),
    );
  }

  Widget _body(BuildContext context, AppUser me) {
    switch (_step) {
      case _NewStep.generating:
        return const _Busy('Đang tạo 6 câu hỏi…');
      case _NewStep.saving:
        return const _Busy('Đang gửi thử thách…');
      case _NewStep.playing:
        return ChallengeQuiz(
          questions: _questions,
          finishLabel: 'Hoàn thành và gửi',
          onFinished: (score) => _save(me, score),
        );
      case _NewStep.sent:
        return EmptyState(
          icon: Icons.send_outlined,
          title: 'Đã gửi thử thách',
          message: 'Bạn được $_score/${_questions.length} điểm. '
              'Kết quả sẽ có khi bạn của bạn chơi xong.',
          action: FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Xong'),
          ),
        );
      case _NewStep.pick:
        return _pick(context, me);
    }
  }

  Widget _pick(BuildContext context, AppUser me) {
    final t = Theme.of(context);
    return ref.watch(friendshipsProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: socialErrorText(e),
            onRetry: () => ref.invalidate(friendshipsProvider),
          ),
          data: (list) {
            final friends = [
              for (final f in list)
                if (f.status == FriendStatus.accepted) f.other(me.uid),
            ];
            if (friends.isEmpty) {
              return EmptyState(
                icon: Icons.group_add_outlined,
                title: 'Bạn chưa có bạn bè',
                message: 'Cần kết bạn trước khi gửi thử thách.',
                action: FilledButton.icon(
                  onPressed: () => context.push(Routes.friends),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Tìm bạn bè'),
                ),
              );
            }
            final selected = friends.contains(_friend) ? _friend : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Text(
                          'Bạn sẽ trả lời 6 câu trước (nghe 10 giây đoán tên bài, '
                          'hoặc điền từ còn thiếu). Sau đó bạn của bạn trả lời '
                          'cùng bộ câu hỏi, ai đúng nhiều hơn sẽ thắng.',
                          style: t.textTheme.bodyMedium
                              ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SectionTitle('Chọn người nhận'),
                      for (final uid in friends)
                        _FriendChoice(
                          uid: uid,
                          selected: uid == selected,
                          onTap: () => setState(() => _friend = uid),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.colorScheme.error)),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: FilledButton.icon(
                      key: const Key('challenge-start'),
                      onPressed: selected == null ? null : _generate,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Bắt đầu chơi'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _FriendChoice extends ConsumerWidget {
  const _FriendChoice({required this.uid, required this.selected, required this.onTap});

  final String uid;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(publicProfileProvider(uid)).value;
    final name = p?.displayName ?? 'Người dùng';
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: NameAvatar(name, highlight: selected),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: p == null ? null : Text('Cấp ${p.level} · ${p.xp} XP'),
      trailing: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
    );
  }
}

Future<bool> _confirmLeave(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ dở thử thách?'),
        content: const Text('Kết quả lượt chơi này sẽ không được lưu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Chơi tiếp')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thoát')),
        ],
      ),
    ) ??
    false;

class _Busy extends StatelessWidget {
  const _Busy(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Play (receiver)
// ---------------------------------------------------------------------------

/// The receiver plays the challenger's questions; the result is saved once.
class ChallengePlayScreen extends ConsumerStatefulWidget {
  const ChallengePlayScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengePlayScreen> createState() => _ChallengePlayScreenState();
}

class _ChallengePlayScreenState extends ConsumerState<ChallengePlayScreen> {
  /// Snapshot taken when play starts, so live updates cannot disturb the quiz.
  Challenge? _playing;
  Challenge? _result;
  bool _saving = false;

  Future<void> _finish(AppUser me, int score) async {
    final c = _playing!;
    setState(() => _saving = true);
    try {
      final repo = ref.read(socialRepositoryProvider);
      final fresh = (await repo.challenges(me.uid)).where((x) => x.id == c.id).firstOrNull;
      if (fresh == null || fresh.status != ChallengeStatus.waiting) {
        showMessage('Thử thách này đã được chơi trước đó, kết quả không thay đổi');
        if (mounted) {
          setState(() {
            _playing = null;
            _result = fresh;
          });
        }
        return;
      }
      final done = Challenge(
        id: fresh.id,
        fromUid: fresh.fromUid,
        fromName: fresh.fromName,
        toUid: fresh.toUid,
        toName: fresh.toName,
        questions: fresh.questions,
        fromScore: fresh.fromScore,
        toScore: score,
        status: ChallengeStatus.completed,
        createdAt: fresh.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await repo.saveChallenge(done);
      emitChallengeCompleted(ref, done, me.uid, score);
      ref.invalidate(challengesProvider);
      if (mounted) {
        setState(() {
          _playing = null;
          _result = done;
        });
      }
    } catch (e) {
      showMessage('Không lưu được kết quả. ${socialErrorText(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final playing = _playing != null;
    return PopScope(
      canPop: !playing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) {
          setState(() => _playing = null);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Đoán tên bài hát')),
        body: user == null || user.isGuest ? const GuestSocialNotice() : _body(context, user),
      ),
    );
  }

  Widget _body(BuildContext context, AppUser me) {
    if (_saving) return const _Busy('Đang lưu kết quả…');
    final result = _result;
    if (result != null) return _ResultView(challenge: result, me: me.uid);
    final playing = _playing;
    if (playing != null) {
      return ChallengeQuiz(
        questions: playing.questions,
        onFinished: (score) => _finish(me, score),
      );
    }
    return ref.watch(challengesProvider).when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            error: socialErrorText(e),
            onRetry: () => ref.invalidate(challengesProvider),
          ),
          data: (list) {
            final c = list.where((x) => x.id == widget.challengeId).firstOrNull;
            if (c == null) {
              return const EmptyState(
                icon: Icons.search_off,
                title: 'Không tìm thấy thử thách',
                message: 'Thử thách có thể đã bị xóa hoặc không dành cho bạn.',
              );
            }
            if (c.toUid != me.uid) {
              if (c.fromUid == me.uid && c.status == ChallengeStatus.completed) {
                return _ResultView(challenge: c, me: me.uid);
              }
              return EmptyState(
                icon: Icons.block,
                title: 'Thử thách này không dành cho bạn',
                message: c.fromUid == me.uid
                    ? 'Bạn đã chơi lượt của mình. Hãy chờ ${c.toName} trả lời.'
                    : null,
              );
            }
            if (c.status != ChallengeStatus.waiting) {
              return _ResultView(challenge: c, me: me.uid, alreadyPlayed: true);
            }
            if (c.questions.isEmpty) {
              return const EmptyState(
                  icon: Icons.error_outline, title: 'Thử thách không có câu hỏi');
            }
            return _Intro(challenge: c, onStart: () => setState(() => _playing = c));
          },
        );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.challenge, required this.onStart});

  final Challenge challenge;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    return EmptyState(
      icon: Icons.sports_esports,
      title: '${c.fromName} thách bạn “Đoán tên bài hát”',
      message: '${c.questions.length} câu hỏi · ${c.fromName} đã trả lời đúng '
          '${c.fromScore} câu. Bạn chỉ được chơi một lần, hãy đeo tai nghe nhé!',
      action: FilledButton.icon(
        key: const Key('challenge-play'),
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Bắt đầu'),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.challenge, required this.me, this.alreadyPlayed = false});

  final Challenge challenge;
  final String me;
  final bool alreadyPlayed;

  @override
  Widget build(BuildContext context) {
    final c = challenge;
    final t = Theme.of(context);
    final s = t.colorScheme;
    final iAmFrom = c.fromUid == me;
    final label = _resultLabel(c, me);
    final (icon, color, headline) = switch (label) {
      'Thắng' => (Icons.emoji_events, const Color(0xFFFFB300), 'Bạn thắng!'),
      'Thua' => (Icons.sentiment_dissatisfied, s.error, 'Bạn thua rồi'),
      _ => (Icons.handshake_outlined, s.primary, 'Hòa'),
    };
    final total = c.questions.length;
    Widget score(String name, int value, bool mine) => Expanded(
          child: Column(
            children: [
              NameAvatar(name, highlight: mine, radius: 24),
              const SizedBox(height: 8),
              Text(mine ? 'Bạn' : name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleSmall),
              Text('$value/$total',
                  style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alreadyPlayed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Bạn đã chơi thử thách này rồi',
                    style: t.textTheme.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
              ),
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 8),
            Text(headline,
                key: const Key('challenge-result'),
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    score(c.fromName, c.fromScore, iAmFrom),
                    Text('–', style: t.textTheme.headlineMedium),
                    score(c.toName, c.toScore ?? 0, !iAmFrom),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Về danh sách thử thách'),
            ),
          ],
        ),
      ),
    );
  }
}
