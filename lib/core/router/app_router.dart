import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/hub/presentation/screens/hub_screen.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_setup_screen.dart';
import '../../features/training/presentation/screens/exercise_detail_screen.dart';
import '../../features/training/presentation/screens/training_shell.dart';
import '../../features/training/presentation/screens/workout_detail_screen.dart';
import '../../features/training/presentation/screens/workout_form_screen.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  // Watch the hasProfile provider to trigger router refresh on change
  final hasProfileAsync = ref.watch(hasProfileProvider);

  return GoRouter(
    initialLocation: RoutePaths.hub,
    redirect: (context, state) {
      final isOnSetup = state.matchedLocation == RoutePaths.profileSetup;

      // While loading, don't redirect
      if (hasProfileAsync.isLoading) return null;

      final hasProfile = hasProfileAsync.value ?? false;

      // No profile and not on setup -> go to setup
      if (!hasProfile && !isOnSetup) return RoutePaths.profileSetup;

      // Has profile but on setup -> go to hub
      if (hasProfile && isOnSetup) return RoutePaths.hub;

      return null;
    },
    routes: [
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
    ],
  );
}
