import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../helpers/workout_exercise_structure.dart';

/// In-memory representation of a drop set segment during active execution.
///
/// Unlike [ExecutionSetSegment] (domain entity persisted to DB),
/// this is a transient UI model used while the execution is in progress.
class SegmentEntry {
  final int reps;
  final double? weight;

  const SegmentEntry({required this.reps, this.weight});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SegmentEntry &&
          runtimeType == other.runtimeType &&
          reps == other.reps &&
          weight == other.weight;

  @override
  int get hashCode => Object.hash(reps, weight);
}

/// In-memory representation of a set during active execution.
///
/// Unlike [ExecutionSet] (domain entity persisted to DB),
/// this tracks both planned and actual values in a mutable form
/// before persistence.
class SetEntry {
  final String? id;
  final int setNumber;
  final int? plannedReps;
  final double? plannedWeight;
  final int? reps;
  final double? weight;

  /// Target duration in seconds (for cardio/isometric exercises).
  final int? plannedDuration;

  /// Actual duration in seconds for cardio/isometric exercises.
  final int? duration;

  /// Distance in meters for cardio exercises.
  final double? distance;

  final bool isCompleted;
  final bool isWarmup;

  /// Rate of Perceived Exertion (1–10). Null when not recorded.
  final int? rpe;

  /// Rare per-set load mode override. Null inherits workout + catalog.
  final LoadMode? loadModeOverride;

  final int? leftReps;
  final double? leftWeight;
  final int? rightReps;
  final double? rightWeight;

  final List<SegmentEntry> segments;

  const SetEntry({
    this.id,
    required this.setNumber,
    this.plannedReps,
    this.plannedWeight,
    this.plannedDuration,
    this.reps,
    this.weight,
    this.duration,
    this.distance,
    this.isCompleted = false,
    this.isWarmup = false,
    this.rpe,
    this.loadModeOverride,
    this.leftReps,
    this.leftWeight,
    this.rightReps,
    this.rightWeight,
    this.segments = const [],
  });

  bool get isDropSet => segments.length > 1;

  SetEntry copyWith({
    String? id,
    int? setNumber,
    int? Function()? plannedReps,
    double? Function()? plannedWeight,
    int? Function()? plannedDuration,
    int? Function()? reps,
    double? Function()? weight,
    int? Function()? duration,
    double? Function()? distance,
    bool? isCompleted,
    bool? isWarmup,
    int? Function()? rpe,
    LoadMode? Function()? loadModeOverride,
    int? Function()? leftReps,
    double? Function()? leftWeight,
    int? Function()? rightReps,
    double? Function()? rightWeight,
    List<SegmentEntry>? segments,
  }) => SetEntry(
    id: id ?? this.id,
    setNumber: setNumber ?? this.setNumber,
    plannedReps: plannedReps != null ? plannedReps() : this.plannedReps,
    plannedWeight: plannedWeight != null ? plannedWeight() : this.plannedWeight,
    plannedDuration: plannedDuration != null
        ? plannedDuration()
        : this.plannedDuration,
    reps: reps != null ? reps() : this.reps,
    weight: weight != null ? weight() : this.weight,
    duration: duration != null ? duration() : this.duration,
    distance: distance != null ? distance() : this.distance,
    isCompleted: isCompleted ?? this.isCompleted,
    isWarmup: isWarmup ?? this.isWarmup,
    rpe: rpe != null ? rpe() : this.rpe,
    loadModeOverride: loadModeOverride != null
        ? loadModeOverride()
        : this.loadModeOverride,
    leftReps: leftReps != null ? leftReps() : this.leftReps,
    leftWeight: leftWeight != null ? leftWeight() : this.leftWeight,
    rightReps: rightReps != null ? rightReps() : this.rightReps,
    rightWeight: rightWeight != null ? rightWeight() : this.rightWeight,
    segments: segments ?? this.segments,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          setNumber == other.setNumber &&
          plannedReps == other.plannedReps &&
          plannedWeight == other.plannedWeight &&
          plannedDuration == other.plannedDuration &&
          reps == other.reps &&
          weight == other.weight &&
          duration == other.duration &&
          distance == other.distance &&
          isCompleted == other.isCompleted &&
          isWarmup == other.isWarmup &&
          rpe == other.rpe &&
          loadModeOverride == other.loadModeOverride &&
          leftReps == other.leftReps &&
          leftWeight == other.leftWeight &&
          rightReps == other.rightReps &&
          rightWeight == other.rightWeight;

  @override
  int get hashCode => Object.hash(
    id,
    setNumber,
    plannedReps,
    plannedWeight,
    plannedDuration,
    reps,
    weight,
    duration,
    distance,
    isCompleted,
    isWarmup,
    rpe,
    loadModeOverride,
    leftReps,
    leftWeight,
    rightReps,
    rightWeight,
  );
}

/// Holds the full state of an active workout execution in progress.
class ActiveExecutionState {
  final String executionId;
  final String workoutId;

  /// WorkoutExercise row id -> sets for that template line (not catalog exercise id).
  final Map<String, List<SetEntry>> exerciseSets;

  /// Ordered exercise configs to access rest per exercise.
  final List<WorkoutExercise> exercises;
  final bool isFinishing;

  /// Whether this session is running under deload adjustments.
  final bool isDeload;

  /// Fallback rest seconds from the active program's defaultRestSeconds.
  final int defaultRestSeconds;

  /// In-session workout building (treino improvisado).
  final bool isAdHoc;

  /// Structural edit mode for a planned session (overlay in memory only).
  final bool isStructuralEditing;

  /// Template snapshot when [isStructuralEditing] was entered.
  final List<WorkoutExercise>? baselineExercises;

  const ActiveExecutionState({
    required this.executionId,
    required this.workoutId,
    required this.exerciseSets,
    required this.exercises,
    this.isFinishing = false,
    this.isDeload = false,
    this.defaultRestSeconds = 0,
    this.isAdHoc = false,
    this.isStructuralEditing = false,
    this.baselineExercises,
  });

  /// Ad-hoc or planned structural editing — unlocks template mutation UI.
  bool get canEditStructure => isAdHoc || isStructuralEditing;

  /// Whether the current structure differs from the session baseline.
  bool get hasTemplateChangesFromBaseline {
    if (!isStructuralEditing || baselineExercises == null) return false;
    return !workoutExercisesStructurallyEqual(exercises, baselineExercises!);
  }

  int get completedSetCount => exerciseSets.values
      .expand((sets) => sets)
      .where((s) => s.isCompleted)
      .length;

  bool get hasCompletedSets => completedSetCount > 0;

  ActiveExecutionState copyWith({
    Map<String, List<SetEntry>>? exerciseSets,
    List<WorkoutExercise>? exercises,
    bool? isFinishing,
    bool? isDeload,
    int? defaultRestSeconds,
    bool? isAdHoc,
    bool? isStructuralEditing,
    List<WorkoutExercise>? baselineExercises,
    bool clearBaselineExercises = false,
  }) => ActiveExecutionState(
    executionId: executionId,
    workoutId: workoutId,
    exerciseSets: exerciseSets ?? this.exerciseSets,
    exercises: exercises ?? this.exercises,
    isFinishing: isFinishing ?? this.isFinishing,
    isDeload: isDeload ?? this.isDeload,
    defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    isAdHoc: isAdHoc ?? this.isAdHoc,
    isStructuralEditing: isStructuralEditing ?? this.isStructuralEditing,
    baselineExercises: clearBaselineExercises
        ? null
        : (baselineExercises ?? this.baselineExercises),
  );
}

extension ActiveExecutionStateSets on ActiveExecutionState {
  List<SetEntry> setsForRow(String rowId) => exerciseSets[rowId] ?? [];

  List<SetEntry> setsForExercise(WorkoutExercise exercise) =>
      setsForRow(exercise.id);

  List<SetEntry> setsAtIndex(int exerciseIndex) =>
      setsForRow(exercises[exerciseIndex].id);

  WorkoutExercise? exerciseByRowId(String rowId) {
    for (final exercise in exercises) {
      if (exercise.id == rowId) return exercise;
    }
    return null;
  }
}
