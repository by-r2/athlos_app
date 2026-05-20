import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/auth_prompt_notifier.dart';
import '../../features/auth/presentation/screens/account_prompt_screen.dart';
import '../../features/auth/presentation/screens/auth_email_screen.dart';
import '../../features/hub/presentation/screens/hub_screen.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/profile/presentation/screens/conflict_center_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/training/presentation/screens/execution_detail_screen.dart';
import '../../features/training/presentation/screens/exercise_detail_screen.dart';
import '../../features/training/presentation/screens/exercise_load_chart_screen.dart';
import '../../features/training/presentation/screens/pr_history_screen.dart';
import '../../features/training/presentation/screens/training_shell.dart';
import '../../features/training/presentation/screens/volume_trend_chart_screen.dart';
import '../../features/training/presentation/screens/workout_detail_screen.dart';
import '../../features/training/presentation/screens/workout_execution_screen.dart';
import '../../features/training/presentation/screens/workout_form_screen.dart';
import '../../features/training/presentation/screens/workout_share_summary_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../providers/last_module_provider.dart';
import '../services/user_data_sync_coordinator.dart';
import 'app_entry_decision.dart';
import 'athlos_router_pages.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final lastModule = ref.read(lastModuleProvider);
  bool hasRestoredModule = false;

  final refreshNotifier = ValueNotifier<int>(0);
  ref.watch(userDataCloudSyncListenerProvider);
  ref.watch(userDataCloudSyncConnectivityListenerProvider);
  ref.listen(authProvider, (_, _) => refreshNotifier.value++);
  ref.listen(localAccessProvider, (_, _) => refreshNotifier.value++);
  ref.listen(hasProfileProvider, (_, _) => refreshNotifier.value++);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final hasProfileAsync = ref.read(hasProfileProvider);
      final authAsync = ref.read(authProvider);
      final hasLocalAccess = ref.read(localAccessProvider);
      final location = state.matchedLocation;
      final hasProfile = hasProfileAsync.value ?? false;

      final redirect = resolveAppEntryRedirect(
        location: location,
        isAuthLoading: authAsync.isLoading,
        isProfileLoading: hasProfileAsync.isLoading,
        hasAuthUser: authAsync.value != null,
        hasLocalAccess: hasLocalAccess,
        hasProfile: hasProfile,
      );
      if (redirect != null) return redirect;

      if (!hasRestoredModule && hasProfile && location == RoutePaths.hub) {
        hasRestoredModule = true;
        if (lastModule != null) return lastModule;
      }

      return null;
    },
    routes: [
      // Splash — shown while async state resolves
      GoRoute(
        path: RoutePaths.splash,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const SplashScreen()),
      ),

      // Account rollout prompt
      GoRoute(
        path: RoutePaths.authPrompt,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const AccountPromptScreen()),
      ),
      GoRoute(
        path: RoutePaths.authSignIn,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const AuthEmailScreen.signIn(),
        ),
      ),
      GoRoute(
        path: RoutePaths.authSignUp,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const AuthEmailScreen.signUp(),
        ),
      ),
      // Hub (Olympus) — main entry point
      GoRoute(
        path: RoutePaths.hub,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const HubScreen()),
      ),

      // Profile setup (first launch)
      GoRoute(
        path: RoutePaths.profileSetup,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const ProfileSetupScreen()),
      ),

      // Profile view/edit
      GoRoute(
        path: RoutePaths.profile,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const ProfileScreen()),
      ),
      GoRoute(
        path: RoutePaths.profileConflicts,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const ConflictCenterScreen()),
      ),

      // Training module — shell with bottom navigation
      trainingShellRoute(),

      // Exercise detail (pushed on top of training shell)
      GoRoute(
        path: '${RoutePaths.trainingExercises}/:exerciseId',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['exerciseId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            ExerciseDetailScreen(exerciseId: id),
          );
        },
      ),

      // Workout routes (pushed on top of training shell)
      GoRoute(
        path: RoutePaths.trainingWorkoutNew,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const WorkoutFormScreen()),
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            WorkoutDetailScreen(workoutId: id),
          );
        },
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId/edit',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            WorkoutFormScreen(workoutId: id),
          );
        },
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId/execute',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            WorkoutExecutionScreen(workoutId: id),
          );
        },
      ),

      // Post-workout share summary (must match before generic history detail)
      GoRoute(
        path: '${RoutePaths.trainingHistory}/:executionId/share',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['executionId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            WorkoutShareSummaryScreen(executionId: id),
          );
        },
      ),

      // Execution detail (history)
      GoRoute(
        path: '${RoutePaths.trainingHistory}/:executionId',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['executionId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            ExecutionDetailScreen(executionId: id),
          );
        },
      ),

      // Progress visualization (Phase 10)
      GoRoute(
        path: '${RoutePaths.trainingExercises}/:exerciseId/load-chart',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['exerciseId']!);
          return AthlosRouterPages.fadeThrough(
            state,
            ExerciseLoadChartScreen(exerciseId: id),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.trainingPRHistory,
        pageBuilder: (context, state) =>
            AthlosRouterPages.fadeThrough(state, const PRHistoryScreen()),
      ),
      GoRoute(
        path: RoutePaths.trainingVolumeTrend,
        pageBuilder: (context, state) => AthlosRouterPages.fadeThrough(
          state,
          const VolumeTrendChartScreen(),
        ),
      ),
    ],
  );
}
