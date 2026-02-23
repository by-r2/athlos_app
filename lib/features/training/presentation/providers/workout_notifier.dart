import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_exercise.dart';

part 'workout_notifier.g.dart';

/// Loads all workouts from the repository, ordered by creation date (newest first).
@riverpod
class WorkoutList extends _$WorkoutList {
  @override
  Future<List<Workout>> build() async {
    final repo = ref.watch(workoutRepositoryProvider);
    final result = await repo.getAll();
    final workouts = result.getOrThrow();
    workouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return workouts;
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
  }

  Future<void> deleteWorkout(int id) async {
    final repo = ref.read(workoutRepositoryProvider);
    final result = await repo.delete(id);
    result.getOrThrow();
    ref.invalidateSelf();
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
