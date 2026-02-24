import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_exercise.dart';

part 'workout_notifier.g.dart';

/// Active (non-archived) workouts, ordered by sortOrder.
@riverpod
class WorkoutList extends _$WorkoutList {
  @override
  Future<List<Workout>> build() async {
    final repo = ref.watch(workoutRepositoryProvider);
    final result = await repo.getActive();
    return result.getOrThrow();
  }

  Future<int> createWorkout({
    required String name,
    String? description,
    required List<WorkoutExercise> exercises,
  }) async {
    final repo = ref.read(workoutRepositoryProvider);
    final workout = Workout(
      id: 0,
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    final result = await repo.create(workout, exercises);
    final id = result.getOrThrow();
    ref.invalidateSelf();
    return id;
  }

  Future<void> updateWorkout({
    required Workout workout,
    required List<WorkoutExercise> exercises,
  }) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.update(workout, exercises);
    result.getOrThrow();
    ref.invalidateSelf();
    ref.invalidate(workoutByIdProvider(workout.id));
    ref.invalidate(workoutExercisesProvider(workout.id));
  }

  Future<void> deleteWorkout(int id) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.delete(id);
    result.getOrThrow();
    ref.invalidateSelf();
    ref.invalidate(workoutByIdProvider(id));
    ref.invalidate(workoutExercisesProvider(id));
  }

  Future<void> archiveWorkout(int id) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.archive(id);
    result.getOrThrow();
    ref.invalidateSelf();
    ref.invalidate(archivedWorkoutListProvider);
  }

  Future<void> unarchiveWorkout(int id) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.unarchive(id);
    result.getOrThrow();
    ref.invalidateSelf();
    ref.invalidate(archivedWorkoutListProvider);
  }

  Future<int> duplicateWorkout(int id, {required String nameSuffix}) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.duplicate(id, nameSuffix: nameSuffix);
    final newId = result.getOrThrow();
    ref.invalidateSelf();
    return newId;
  }

  Future<void> reorderWorkouts(List<int> orderedIds) async {
    final repo = ref.read(workoutRepositoryProvider);

    // Optimistic update: apply new sortOrder values immediately so
    // nextWorkoutProvider recomputes before the DB round-trip completes.
    final current = state.value;
    if (current != null) {
      final byId = {for (final w in current) w.id: w};
      final reordered = [
        for (var i = 0; i < orderedIds.length; i++)
          if (byId[orderedIds[i]] case final w?)
            Workout(
              id: w.id,
              name: w.name,
              description: w.description,
              sortOrder: i,
              isArchived: w.isArchived,
              createdAt: w.createdAt,
            ),
      ];
      state = AsyncData(reordered);
    }

    final result = await repo.reorder(orderedIds);
    result.getOrThrow();
    final fresh = await repo.getActive();
    state = AsyncData(fresh.getOrThrow());
  }
}

/// Archived workouts, ordered by name.
@riverpod
class ArchivedWorkoutList extends _$ArchivedWorkoutList {
  @override
  Future<List<Workout>> build() async {
    final repo = ref.watch(workoutRepositoryProvider);
    final result = await repo.getArchived();
    return result.getOrThrow();
  }
}

/// Loads a single workout by ID.
@riverpod
Future<Workout?> workoutById(Ref ref, int id) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getById(id);
  return result.getOrThrow();
}

/// Loads the exercises configured for a workout.
@riverpod
Future<List<WorkoutExercise>> workoutExercises(Ref ref, int workoutId) async {
  final repo = ref.watch(workoutRepositoryProvider);
  final result = await repo.getExercises(workoutId);
  return result.getOrThrow();
}

/// Last finished workout execution. Watched by [nextWorkoutProvider].
@riverpod
Future<int?> lastFinishedWorkoutId(Ref ref) async {
  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final result = await execRepo.getLastFinished();
  return result.getOrThrow()?.workoutId;
}

/// Derives the next workout in the cycle.
///
/// Synchronous provider that watches [workoutListProvider] and
/// [lastFinishedWorkoutIdProvider]. Recomputes automatically when
/// either dependency changes — no manual invalidation needed.
@riverpod
Workout? nextWorkout(Ref ref) {
  final workoutsAsync = ref.watch(workoutListProvider);
  final lastExecAsync = ref.watch(lastFinishedWorkoutIdProvider);

  // Skip computation while data is loading to avoid using stale sort-order.
  if (workoutsAsync is AsyncLoading) return null;

  final activeWorkouts = workoutsAsync.value;
  if (activeWorkouts == null || activeWorkouts.isEmpty) return null;

  final ordered = activeWorkouts
      .where((w) => w.sortOrder != null)
      .toList()
    ..sort((a, b) => a.sortOrder!.compareTo(b.sortOrder!));
  if (ordered.isEmpty) return activeWorkouts.first;

  final lastWorkoutId = lastExecAsync.value;
  if (lastWorkoutId == null) return ordered.first;

  final lastIdx = ordered.indexWhere((w) => w.id == lastWorkoutId);
  if (lastIdx == -1) return ordered.first;

  return ordered[(lastIdx + 1) % ordered.length];
}
