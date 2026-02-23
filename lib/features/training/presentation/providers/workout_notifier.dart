import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart'
    show WorkoutExecutionsCompanion;
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

  Future<int> duplicateWorkout(int id) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.duplicate(id);
    final newId = result.getOrThrow();
    ref.invalidateSelf();
    return newId;
  }

  Future<void> reorderWorkouts(List<int> orderedIds) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.reorder(orderedIds);
    result.getOrThrow();
    ref.invalidateSelf();
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

/// Derives the next workout in the cycle from the last finished execution.
@riverpod
Future<Workout?> nextWorkout(Ref ref) async {
  final activeWorkouts = await ref.watch(workoutListProvider.future);
  if (activeWorkouts.isEmpty) return null;

  final ordered = activeWorkouts
      .where((w) => w.sortOrder != null)
      .toList()
    ..sort((a, b) => a.sortOrder!.compareTo(b.sortOrder!));
  if (ordered.isEmpty) return activeWorkouts.first;

  final execRepo = ref.watch(workoutExecutionRepositoryProvider);
  final lastExec = (await execRepo.getLastFinished()).getOrThrow();

  if (lastExec == null) return ordered.first;

  final lastIdx = ordered.indexWhere((w) => w.id == lastExec.workoutId);
  if (lastIdx == -1) return ordered.first;

  return ordered[(lastIdx + 1) % ordered.length];
}

/// Marks a workout as done by creating a minimal WorkoutExecution.
@riverpod
Future<void> markWorkoutDone(Ref ref, int workoutId) async {
  final dao = ref.read(workoutExecutionDaoProvider);
  final now = DateTime.now();
  await dao.create(
    WorkoutExecutionsCompanion.insert(
      workoutId: workoutId,
      startedAt: Value(now),
      finishedAt: Value(now),
    ),
  );
  ref.invalidate(nextWorkoutProvider);
  ref.invalidate(workoutListProvider);
}
