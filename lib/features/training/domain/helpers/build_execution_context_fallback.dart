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
}) {
  final templateByExerciseId = {
    for (final we in templateExercises) we.exerciseId: we,
  };
  final allIds = {...sessionExerciseIds, ...templateByExerciseId.keys};

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

  return ExecutionContextFallback(exercises: exercises);
}
