import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/hub/presentation/screens/hub_screen.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/training/presentation/screens/execution_detail_screen.dart';
import '../../features/training/presentation/screens/exercise_detail_screen.dart';
import '../../features/training/presentation/screens/training_shell.dart';
import '../../features/training/presentation/screens/workout_detail_screen.dart';
import '../../features/training/presentation/screens/workout_execution_screen.dart';
import '../../features/training/presentation/screens/workout_form_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../providers/last_module_provider.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final lastModule = ref.read(lastModuleProvider);
  bool hasRestoredModule = false;

  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(hasProfileProvider, (_, _) => refreshNotifier.value++);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final hasProfileAsync = ref.read(hasProfileProvider);
      final location = state.matchedLocation;
      final isOnSplash = location == RoutePaths.splash;
      final isOnSetup = location == RoutePaths.profileSetup;

      if (hasProfileAsync.isLoading) {
        return isOnSplash ? null : RoutePaths.splash;
      }

      if (isOnSplash) {
        final hasProfile = hasProfileAsync.value ?? false;
        return hasProfile ? RoutePaths.hub : RoutePaths.profileSetup;
      }

      final hasProfile = hasProfileAsync.value ?? false;

      if (!hasProfile && !isOnSetup) return RoutePaths.profileSetup;
      if (hasProfile && isOnSetup) return RoutePaths.hub;

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
        builder: (context, state) => const SplashScreen(),
      ),

      // Hub (Olympus) — main entry point
      GoRoute(
        path: RoutePaths.hub,
        builder: (context, state) => const HubScreen(),
      ),

      // Profile setup (first launch)
      GoRoute(
        path: RoutePaths.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),

      // Profile view/edit
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),

      // Training module — shell with bottom navigation
      trainingShellRoute(),

      // Exercise detail (pushed on top of training shell)
      GoRoute(
        path: '${RoutePaths.trainingExercises}/:exerciseId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['exerciseId']!);
          return ExerciseDetailScreen(exerciseId: id);
        },
      ),

      // Workout routes (pushed on top of training shell)
      GoRoute(
        path: RoutePaths.trainingWorkoutNew,
        builder: (context, state) => const WorkoutFormScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return WorkoutDetailScreen(workoutId: id);
        },
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return WorkoutFormScreen(workoutId: id);
        },
      ),
      GoRoute(
        path: '${RoutePaths.trainingWorkouts}/:workoutId/execute',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['workoutId']!);
          return WorkoutExecutionScreen(workoutId: id);
        },
      ),

      // Execution detail (history)
      GoRoute(
        path: '${RoutePaths.trainingHistory}/:executionId',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['executionId']!);
          return ExecutionDetailScreen(executionId: id);
        },
      ),
    ],
  );
}
