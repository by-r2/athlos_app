import '../../domain/entities/workout_exercise.dart';

/// In-memory representation of a drop set segment during active execution.
///
/// Unlike [ExecutionSetSegment] (domain entity persisted to DB),
/// this is a transient UI model used while the execution is in progress.
class SegmentEntry {
  final int reps;
  final double? weight;

  const SegmentEntry({required this.reps, this.weight});
}

/// In-memory representation of a set during active execution.
///
/// Unlike [ExecutionSet] (domain entity persisted to DB),
/// this tracks both planned and actual values in a mutable form
/// before persistence.
class SetEntry {
  final int? id;
  final int setNumber;
  final int plannedReps;
  final double? plannedWeight;
  final int reps;
  final double? weight;
  final bool isCompleted;
  final List<SegmentEntry> segments;

  const SetEntry({
    this.id,
    required this.setNumber,
    required this.plannedReps,
    this.plannedWeight,
    required this.reps,
    this.weight,
    this.isCompleted = false,
    this.segments = const [],
  });

  bool get isDropSet => segments.length > 1;

  SetEntry copyWith({
    int? id,
    int? setNumber,
    int? plannedReps,
    double? Function()? plannedWeight,
    int? reps,
    double? Function()? weight,
    bool? isCompleted,
    List<SegmentEntry>? segments,
  }) =>
      SetEntry(
        id: id ?? this.id,
        setNumber: setNumber ?? this.setNumber,
        plannedReps: plannedReps ?? this.plannedReps,
        plannedWeight:
            plannedWeight != null ? plannedWeight() : this.plannedWeight,
        reps: reps ?? this.reps,
        weight: weight != null ? weight() : this.weight,
        isCompleted: isCompleted ?? this.isCompleted,
        segments: segments ?? this.segments,
      );
}

/// Holds the full state of an active workout execution in progress.
class ActiveExecutionState {
  final int executionId;
  final int workoutId;

  /// exerciseId -> list of sets for that exercise.
  final Map<int, List<SetEntry>> exerciseSets;

  /// Ordered exercise configs to access restSeconds per exercise.
  final List<WorkoutExercise> exercises;
  final bool isFinishing;

  const ActiveExecutionState({
    required this.executionId,
    required this.workoutId,
    required this.exerciseSets,
    required this.exercises,
    this.isFinishing = false,
  });

  int get completedSetCount => exerciseSets.values
      .expand((sets) => sets)
      .where((s) => s.isCompleted)
      .length;

  bool get hasCompletedSets => completedSetCount > 0;

  ActiveExecutionState copyWith({
    Map<int, List<SetEntry>>? exerciseSets,
    bool? isFinishing,
  }) =>
      ActiveExecutionState(
        executionId: executionId,
        workoutId: workoutId,
        exerciseSets: exerciseSets ?? this.exerciseSets,
        exercises: exercises,
        isFinishing: isFinishing ?? this.isFinishing,
      );
}
