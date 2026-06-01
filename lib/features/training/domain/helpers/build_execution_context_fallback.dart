import '../entities/execution_context_fallback.dart';
import '../entities/exercise.dart';
import '../entities/workout_exercise.dart';
import '../enums/load_mode.dart';
import '../enums/muscle_group.dart';

/// Builds [ExecutionContextFallback] from live template + catalog at finish time.
ExecutionContextFallback buildExecutionContextFallback({
  required List<WorkoutExercise> templateExercises,
  required Map<String, Exercise> exercisesById,
  required Set<String> sessionExerciseIds,
  Map<String, String> substitutionsByRowId = const {},
}) {
  final templateByExerciseId = {
    for (final we in templateExercises) we.exerciseId: we,
  };

  final allIds = <String>{
    ...sessionExerciseIds,
    ...templateByExerciseId.keys,
    ...substitutionsByRowId.values,
  };

  final exercises = <String, ExecutionContextFallbackExercise>{};
  for (final exerciseId in allIds) {
    final catalog = exercisesById[exerciseId];
    final template = templateByExerciseId[exerciseId];
    if (catalog == null && template == null) continue;

    exercises[exerciseId] = ExecutionContextFallbackExercise(
      displayName: catalog?.name ?? exerciseId,
      isVerified: catalog?.isVerified ?? false,
      muscleGroup: catalog?.muscleGroup ?? MuscleGroup.fullBody,
      defaultLoadMode: catalog?.defaultLoadMode ?? LoadMode.weighted,
      bodyweightLoadFactor: catalog?.bodyweightLoadFactor,
      isUnilateral: template?.isUnilateral ?? false,
      loadModeOverride: template?.loadModeOverride,
      groupId: template?.groupId,
      sortOrder: template?.sortOrder ?? 0,
    );
  }

  final lines = <String, ExecutionContextFallbackLine>{};
  for (final we in templateExercises) {
    final catalog = exercisesById[we.exerciseId];
    final originalId = substitutionsByRowId[we.id];
    final originalCatalog =
        originalId != null ? exercisesById[originalId] : null;
    final originalSnap = originalId != null ? exercises[originalId] : null;

    lines[we.id] = ExecutionContextFallbackLine(
      workoutExerciseId: we.id,
      exerciseId: we.exerciseId,
      substitutedFromExerciseId: originalId,
      displayName: catalog?.name ?? we.exerciseId,
      substitutedFromDisplayName: originalCatalog?.name ??
          originalSnap?.displayName,
      isVerified: catalog?.isVerified ?? false,
      muscleGroup: catalog?.muscleGroup ?? MuscleGroup.fullBody,
      sortOrder: we.sortOrder,
      groupId: we.groupId,
      isUnilateral: we.isUnilateral,
      loadModeOverride: we.loadModeOverride,
    );
  }

  return ExecutionContextFallback(
    exercises: exercises,
    lines: lines,
  );
}
