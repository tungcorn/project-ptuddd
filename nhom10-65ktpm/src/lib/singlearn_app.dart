import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/cloud/firebase_services.dart';
import 'core/config/app_config.dart';
import 'core/events/app_event_bus.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/ui/theme.dart';
import 'features/auth/domain/app_user.dart';
import 'features/player/presentation/player_controller.dart';
import 'features/progress/data/progress_service.dart';
import 'features/social/domain/social_models.dart';

class SingLearnApp extends ConsumerWidget {
  const SingLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'SingLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => AppLifecycleHost(child: child ?? const SizedBox()),
    );
  }
}

/// App-wide background duties: XP feedback, sync on reconnect, public profile
/// refresh, reminder scheduling, challenge notifications and listening-time
/// reporting when the app is backgrounded.
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends ConsumerState<AppLifecycleHost>
    with WidgetsBindingObserver {
  StreamSubscription<XpAward>? _awards;
  StreamSubscription<List<ConnectivityResult>>? _net;
  final _seenChallenges = <String, String>{};
  bool _challengesPrimed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _net = ref.read(connectivityProvider).listen((r) {
      if (!r.contains(ConnectivityResult.none)) _syncNow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awards?.cancel();
    _net?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(playerControllerProvider.notifier).reportListening();
      _syncNow();
    } else if (state == AppLifecycleState.resumed) {
      _syncNow();
    }
  }

  Future<void> _syncNow() async {
    final sync = ref.read(syncServiceProvider);
    if (!sync.isEnabled) return;
    final user = ref.read(currentUserProvider);
    try {
      await sync.flush();
      if (user != null && !user.isGuest) {
        await ref.read(vocabularyRepositoryProvider).pull();
        await ref.read(songProgressRepositoryProvider).pull();
        await ref.read(progressServiceProvider).pull();
        await ref.read(songRepositoryProvider).pullRemote();
      }
    } catch (e) {
      debugPrint('Sync deferred: $e');
    }
  }

  Future<void> _onUser(AppUser? user) async {
    if (user == null || user.isGuest) return;
    final snap = await ref.read(progressServiceProvider).snapshot();
    await ref.read(socialRepositoryProvider).upsertProfile(PublicProfile(
          uid: user.uid,
          displayName: user.displayName,
          userCode: user.userCode,
          email: user.email,
          xp: snap.totalXp,
          weekXp: snap.weekXp,
          weekKey: weekKeyOf(DateTime.now()),
          level: snap.level.level,
          streak: snap.streak,
        ));
    _challengesPrimed = false;
    _seenChallenges.clear();
    unawaited(_syncNow());
    if (AppConfig.messagingEnabled) {
      unawaited(CloudMessaging.register(user.uid).catchError(
          (Object e) => debugPrint('FCM registration skipped: $e')));
    }
  }

  void _onChallenges(List<Challenge> list, String uid) {
    final notifications = ref.read(notificationServiceProvider);
    for (final c in list) {
      final key = '${c.status.name}:${c.toScore}';
      final prev = _seenChallenges[c.id];
      _seenChallenges[c.id] = key;
      if (!_challengesPrimed || prev == key) continue;
      if (prev == null && c.toUid == uid && c.status == ChallengeStatus.waiting) {
        notifications.show('Lời mời thử thách mới',
            '${c.fromName} thách bạn “Đoán tên bài hát” (${c.fromScore} điểm).');
      } else if (c.fromUid == uid && c.status == ChallengeStatus.completed) {
        // The challenger's result is known only now (win bonus / badge).
        ref.read(eventBusProvider).emit(LearningEvent(
              id: 'challenge:${c.id}:$uid',
              type: LearningEventType.challengeCompleted,
              uid: uid,
              data: {'challengeId': c.id, 'score': c.fromScore, 'won': c.winner == uid},
            ));
        final result = c.winner == null
            ? 'Hòa'
            : (c.winner == uid ? 'Bạn thắng' : '${c.toName} thắng');
        notifications.show('Kết quả thử thách',
            '$result: ${c.fromScore} – ${c.toScore}.');
      }
    }
    _challengesPrimed = true;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the progress module alive so it consumes learning events.
    final progress = ref.watch(progressServiceProvider);
    if (_awards == null || !identical(_awardsSource, progress)) {
      _awards?.cancel();
      _awardsSource = progress;
      _awards = progress.awards.listen((a) {
        final parts = <String>[
          if (a.xp > 0) '+${a.xp} XP',
          if (a.levelUp != null) 'Lên cấp ${a.levelUp}!',
          for (final b in a.newBadges) 'Huy hiệu mới: ${b.title}',
        ];
        if (parts.isNotEmpty) showMessage(parts.join(' · '));
      });
    }
    ref.listen(currentUserProvider, (prev, next) {
      if (prev?.uid != next?.uid) _onUser(next);
    });
    ref.listen(challengesProvider, (_, next) {
      final uid = ref.read(uidProvider);
      if (next.hasValue && uid != AppUser.guestUid) _onChallenges(next.value!, uid);
    });
    ref.listen(settingsProvider, (prev, next) {
      final n = ref.read(notificationServiceProvider);
      if (prev?.reminderEnabled == next.reminderEnabled &&
          prev?.reminderTime == next.reminderTime) {
        return;
      }
      if (next.reminderEnabled) {
        n.scheduleDailyReminder(next.reminderTime);
      } else if (prev != null && prev.reminderEnabled) {
        n.cancelDailyReminder();
      }
    });
    return widget.child;
  }

  Object? _awardsSource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(currentUserProvider);
    if (user != null && _seenChallenges.isEmpty && !_challengesPrimed) {
      _onUser(user);
    }
  }
}
