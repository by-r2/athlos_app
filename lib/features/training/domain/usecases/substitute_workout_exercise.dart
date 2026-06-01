import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../entities/exercise.dart';
import '../entities/workout_exercise.dart';
import '../enums/exercise_type.dart';

/// Parameters for [SubstituteWorkoutExercise].
class SubstituteWorkoutExerciseParams {
  final WorkoutExercise row;
  final Exercise replacement;
  final List<WorkoutExercise> workoutExercises;
  final Set<String> isometricExerciseIds;

  const SubstituteWorkoutExerciseParams({
    required this.row,
    required this.replacement,
    required this.workoutExercises,
    this.isometricExerciseIds = const {},
  });
}

/// Builds the updated template row when swapping catalog exercise on a line.
class SubstituteWorkoutExercise {
  const SubstituteWorkoutExercise();

  Result<WorkoutExercise> call(SubstituteWorkoutExerciseParams params) {
    final others = params.workoutExercises.where((e) => e.id != params.row.id);
    if (others.any((e) => e.exerciseId == params.replacement.id)) {
      return const Failure(
        ConflictException('Exercise is already in this workout'),
      );
    }

    return Success(
      _buildSubstitutedRow(
        row: params.row,
        replacement: params.replacement,
        isometricExerciseIds: params.isometricExerciseIds,
      ),
    );
  }

  WorkoutExercise _buildSubstitutedRow({
    required WorkoutExercise row,
    required Exercise replacement,
    required Set<String> isometricExerciseIds,
  }) {
    final isIsometric = isometricExerciseIds.contains(replacement.id);
    final isCardio = replacement.type == ExerciseType.cardio && !isIsometric;

    if (isCardio) {
      return WorkoutExercise(
        id: row.id,
        workoutId: row.workoutId,
        exerciseId: replacement.id,
        sortOrder: row.sortOrder,
        sets: row.sets,
        restSeconds: row.restSeconds,
        durationSeconds: row.durationSeconds ?? 300,
        groupId: row.groupId,
        isUnilateral: row.isUnilateral,
        loadModeOverride: row.loadModeOverride,
        notes: row.notes,
      );
    }

    if (isIsometric) {
      return WorkoutExercise(
        id: row.id,
        workoutId: row.workoutId,
        exerciseId: replacement.id,
        sortOrder: row.sortOrder,
        sets: row.sets,
        restSeconds: row.restSeconds,
        durationSeconds: row.durationSeconds ?? 30,
        groupId: row.groupId,
        isUnilateral: row.isUnilateral,
        loadModeOverride: row.loadModeOverride,
        notes: row.notes,
      );
    }

    final wasCardioOrIso = row.durationSeconds != null && row.minReps == null;
    return WorkoutExercise(
      id: row.id,
      workoutId: row.workoutId,
      exerciseId: replacement.id,
      sortOrder: row.sortOrder,
      sets: row.sets,
      minReps: wasCardioOrIso ? 12 : row.minReps,
      maxReps: wasCardioOrIso ? 12 : row.maxReps,
      isAmrap: wasCardioOrIso ? false : row.isAmrap,
      restSeconds: row.restSeconds,
      groupId: row.groupId,
      isUnilateral: row.isUnilateral,
      loadModeOverride: row.loadModeOverride,
      notes: row.notes,
    );
  }
}
