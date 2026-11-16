import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_songs_screen.dart';
import '../features/admin/presentation/song_editor_screen.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/auth/presentation/placement_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/player/presentation/player_screen.dart';
import '../features/practice/domain/exercises.dart';
import '../features/practice/presentation/fill_blank_screen.dart';
import '../features/practice/presentation/ordering_screens.dart';
import '../features/practice/presentation/practice_screen.dart';
import '../features/practice/presentation/pronunciation_screen.dart';
import '../features/practice/presentation/quiz_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/profile/presentation/stats_screen.dart';
import '../features/social/presentation/challenge_screens.dart';
import '../features/social/presentation/friends_screen.dart';
import '../features/social/presentation/leaderboard_screen.dart';
import '../features/songs/presentation/library_screen.dart';
import '../features/vocabulary/presentation/review_screen.dart';
import '../features/vocabulary/presentation/vocabulary_screen.dart';
import 'providers.dart';
import 'ui/app_shell.dart';

/// Route paths shared by all modules.
class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const placement = '/placement';
  static const home = '/home';
  static const songs = '/songs';
  static const practice = '/practice';
  static const vocabulary = '/vocabulary';
  static const profile = '/profile';
  static const review = '/review';
  static const stats = '/stats';
  static const settings = '/settings';
  static const friends = '/friends';
  static const leaderboard = '/leaderboard';
  static const challenges = '/challenges';
  static const newChallenge = '/challenges/new';
  static const admin = '/admin';

  static String player(String songId) => '/player/$songId';
  static String fillBlank(String songId, BlankDifficulty d) =>
      '/practice/$songId/fill?level=${d.name}';
  static String lineOrder(String songId) => '/practice/$songId/lines';
  static String wordOrder(String songId) => '/practice/$songId/words';
  static String quiz(String songId) => '/practice/$songId/quiz';
  static String pronunciation(String songId, {int? line}) =>
      '/practice/$songId/pronunciation${line == null ? '' : '?line=$line'}';
  static String playChallenge(String id) => '/challenges/$id/play';
  static String editSong(String? id) => '/admin/song/${id ?? 'new'}';

  static const _authPaths = {login, register, forgot};
}

/// Bridges auth changes into go_router's refresh mechanism.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>();
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      final AppUser? user = auth.value;
      if (user == null) {
        return Routes._authPaths.contains(loc) ? null : Routes.login;
      }
      if (!user.isGuest && user.level == null && loc != Routes.placement) {
        return Routes.placement;
      }
      if (loc == Routes.splash ||
          Routes._authPaths.contains(loc) ||
          (loc == Routes.placement && (user.isGuest || user.level != null))) {
        return Routes.home;
      }
      if (loc.startsWith(Routes.admin) && !user.isAdmin) return Routes.profile;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgot, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.placement, builder: (_, _) => const PlacementScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.songs, builder: (_, _) => const LibraryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.practice, builder: (_, _) => const PracticeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.vocabulary, builder: (_, _) => const VocabularyScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/player/:id',
        builder: (_, s) => PlayerScreen(songId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/practice/:id/fill',
        builder: (_, s) => FillBlankScreen(
          songId: s.pathParameters['id']!,
          difficulty: BlankDifficulty.values.asNameMap()[s.uri.queryParameters['level']] ??
              BlankDifficulty.easy,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/practice/:id/lines',
        builder: (_, s) => LineOrderScreen(songId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/practice/:id/words',
        builder: (_, s) => WordOrderScreen(songId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/practice/:id/quiz',
        builder: (_, s) => MeaningQuizScreen(songId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/practice/:id/pronunciation',
        builder: (_, s) => PronunciationScreen(
          songId: s.pathParameters['id']!,
          initialLine: int.tryParse(s.uri.queryParameters['line'] ?? ''),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.review,
        builder: (_, _) => const ReviewScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.stats,
        builder: (_, _) => const StatsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.friends,
        builder: (_, _) => const FriendsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.leaderboard,
        builder: (_, _) => const LeaderboardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.challenges,
        builder: (_, _) => const ChallengesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const NewChallengeScreen(),
          ),
          GoRoute(
            path: ':cid/play',
            builder: (_, s) => ChallengePlayScreen(challengeId: s.pathParameters['cid']!),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.admin,
        builder: (_, _) => const AdminSongsScreen(),
        routes: [
          GoRoute(
            path: 'song/:sid',
            builder: (_, s) {
              final id = s.pathParameters['sid']!;
              return SongEditorScreen(songId: id == 'new' ? null : id);
            },
          ),
        ],
      ),
    ],
  );
});
