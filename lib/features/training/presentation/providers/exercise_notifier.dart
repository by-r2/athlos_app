import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';

part 'exercise_notifier.g.dart';

/// Loads all exercises from the repository.
@riverpod
class ExerciseList extends _$ExerciseList {
  @override
  Future<List<Exercise>> build() async {
    final repo = ref.watch(exerciseRepositoryProvider);
    final result = await repo.getAll();
    return result.getOrThrow();
  }

  /// Creates a user-defined exercise (isVerified = false).
  Future<void> addCustomExercise({
    required String name,
    required MuscleGroup muscleGroup,
    String? description,
    List<int> equipmentIds = const [],
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>
        muscles = const [],
  }) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final exercise = Exercise(
      id: 0,
      name: name,
      muscleGroup: muscleGroup,
      description: description,
    );
    final result = await repo.create(
      exercise,
      equipmentIds: equipmentIds,
      muscles: muscles,
    );
    result.getOrThrow();
    ref.invalidateSelf();
  }

  /// Updates a user-defined exercise.
  Future<void> updateExercise(
    Exercise exercise, {
    List<int>? equipmentIds,
    List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>?
        muscles,
  }) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final result = await repo.update(
      exercise,
      equipmentIds: equipmentIds,
      muscles: muscles,
    );
    result.getOrThrow();
    ref.invalidateSelf();
  }

  /// Deletes a user-defined exercise.
  Future<void> deleteExercise(int id) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final result = await repo.delete(id);
    result.getOrThrow();
    ref.invalidateSelf();
  }
}

/// Loads exercises filtered by a specific muscle group.
@riverpod
Future<List<Exercise>> exercisesByMuscleGroup(
  Ref ref,
  MuscleGroup group,
) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getByMuscleGroup(group);
  return result.getOrThrow();
}

/// Loads variations for a specific exercise.
@riverpod
Future<List<Exercise>> exerciseVariations(Ref ref, int exerciseId) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getVariations(exerciseId);
  return result.getOrThrow();
}

/// Loads equipment IDs linked to a specific exercise.
@riverpod
Future<List<int>> exerciseEquipmentIds(Ref ref, int exerciseId) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getEquipmentIds(exerciseId);
  return result.getOrThrow();
}

/// Loads muscle foci for a specific exercise.
@riverpod
Future<List<ExerciseMuscleFocus>> exerciseMuscleFoci(
    Ref ref, int exerciseId) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getMuscleFoci(exerciseId);
  return result.getOrThrow();
}

/// Maps exerciseId → list of required equipment IDs for all exercises.
@riverpod
Future<Map<int, List<int>>> exerciseEquipmentMap(Ref ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  final result = await repo.getEquipmentMap();
  return result.getOrThrow();
}
