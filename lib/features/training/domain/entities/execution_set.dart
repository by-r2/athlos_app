import 'execution_set_segment.dart';
import '../enums/load_mode.dart';

/// A single set performed during a workout execution.
class ExecutionSet {
  final String id;
  final String executionId;
  final String exerciseId;

  /// Template line id when recorded. Null on legacy sessions.
  final String? workoutExerciseId;

  final int setNumber;

  /// Snapshot of planned reps from the workout template. Null for cardio.
  final int? plannedReps;

  /// Target weight (e.g. from last session). Null if not set.
  final double? plannedWeight;

  /// Actual reps performed (primary segment for drop sets). Null for cardio.
  final int? reps;

  /// Actual weight used in kg (primary segment for drop sets).
  final double? weight;

  /// Actual duration performed in seconds. Used for cardio exercises.
  final int? durationSeconds;

  /// Actual distance covered in meters. Used for cardio exercises.
  final double? distanceMeters;

  final bool isCompleted;

  /// Whether this is a warmup set (excluded from volume, load feedback, PRs).
  final bool isWarmup;

  /// Rate of Perceived Exertion (1–10). Null when not recorded.
  final int? rpe;

  /// Body weight snapshot in kg captured when the set is completed.
  final double? bodyWeightSnapshot;

  /// Optional per-set load mode override. Null means inherit from
  /// workout-level override and then from exercise catalog default.
  final LoadMode? loadModeOverride;

  /// Reps performed with the left side (unilateral exercises).
  final int? leftReps;

  /// Weight used for the left side (unilateral exercises).
  final double? leftWeight;

  /// Reps performed with the right side (unilateral exercises).
  final int? rightReps;

  /// Weight used for the right side (unilateral exercises).
  final double? rightWeight;

  /// Whether the set was performed unilaterally (one side at a time).
  /// Null means the template default was used (legacy data).
  final bool? isUnilateral;

  /// Drop set segments. Empty for normal sets.
  final List<ExecutionSetSegment> segments;

  const ExecutionSet({
    required this.id,
    required this.executionId,
    required this.exerciseId,
    this.workoutExerciseId,
    required this.setNumber,
    this.plannedReps,
    this.plannedWeight,
    this.reps,
    this.weight,
    this.durationSeconds,
    this.distanceMeters,
    this.isCompleted = false,
    this.isWarmup = false,
    this.rpe,
    this.bodyWeightSnapshot,
    this.loadModeOverride,
    this.leftReps,
    this.leftWeight,
    this.rightReps,
    this.rightWeight,
    this.isUnilateral,
    this.segments = const [],
  });

  bool get isDropSet => segments.length > 1;

  /// Total reps across all segments (or just [reps] for normal sets).
  int get totalReps => segments.isEmpty
      ? (reps ?? 0)
      : segments.fold(0, (sum, s) => sum + s.reps);
}
