import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/workout_exercise.dart';
import '../../../domain/enums/load_mode.dart';

/// Editable prescription for an improvised-workout exercise (sheet-local).
class AdHocExerciseConfig {
  final String workoutExerciseId;
  final String workoutId;
  final int sortOrder;
  final Exercise exercise;
  int sets;
  int? minReps;
  int? maxReps;
  bool isAmrap;
  int restSeconds;
  int? durationSeconds;
  bool isUnilateral;
  LoadMode? loadModeOverride;
  String? notes;
  final int? groupId;

  AdHocExerciseConfig({
    required this.workoutExerciseId,
    required this.workoutId,
    required this.sortOrder,
    required this.exercise,
    required this.sets,
    this.minReps,
    this.maxReps,
    this.isAmrap = false,
    required this.restSeconds,
    this.durationSeconds,
    this.isUnilateral = false,
    this.loadModeOverride,
    this.notes,
    this.groupId,
  });

  bool get usesDuration => exercise.isCardio || exercise.isIsometric;

  factory AdHocExerciseConfig.fromWorkoutExercise(
    WorkoutExercise workoutExercise,
    Exercise exercise,
  ) {
    return AdHocExerciseConfig(
      workoutExerciseId: workoutExercise.id,
      workoutId: workoutExercise.workoutId,
      sortOrder: workoutExercise.sortOrder,
      exercise: exercise,
      sets: workoutExercise.sets,
      minReps: workoutExercise.minReps,
      maxReps: workoutExercise.maxReps,
      isAmrap: workoutExercise.isAmrap,
      restSeconds: workoutExercise.restSeconds,
      durationSeconds: workoutExercise.durationSeconds,
      isUnilateral: workoutExercise.isUnilateral,
      loadModeOverride: workoutExercise.loadModeOverride,
      notes: workoutExercise.notes,
      groupId: workoutExercise.groupId,
    );
  }

  WorkoutExercise toWorkoutExercise() => WorkoutExercise(
        id: workoutExerciseId,
        workoutId: workoutId,
        exerciseId: exercise.id,
        sortOrder: sortOrder,
        sets: sets,
        minReps: minReps,
        maxReps: maxReps,
        isAmrap: isAmrap,
        restSeconds: restSeconds,
        durationSeconds: durationSeconds,
        isUnilateral: isUnilateral,
        loadModeOverride: loadModeOverride,
        notes: notes,
        groupId: groupId,
      );
}
