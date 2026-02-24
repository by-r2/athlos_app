import 'execution_set_segment.dart';

/// A single set performed during a workout execution.
class ExecutionSet {
  final int id;
  final int executionId;
  final int exerciseId;
  final int setNumber;

  /// Snapshot of planned reps from the workout template.
  final int plannedReps;

  /// Target weight (e.g. from last session). Null if not set.
  final double? plannedWeight;

  /// Actual reps performed (primary segment for drop sets).
  final int reps;

  /// Actual weight used in kg (primary segment for drop sets).
  final double? weight;

  final bool isCompleted;

  /// Per-set user notes.
  final String? notes;

  /// Drop set segments. Empty for normal sets.
  final List<ExecutionSetSegment> segments;

  const ExecutionSet({
    required this.id,
    required this.executionId,
    required this.exerciseId,
    required this.setNumber,
    required this.plannedReps,
    this.plannedWeight,
    required this.reps,
    this.weight,
    this.isCompleted = false,
    this.notes,
    this.segments = const [],
  });

  bool get isDropSet => segments.length > 1;

  /// Total reps across all segments (or just [reps] for normal sets).
  int get totalReps =>
      segments.isEmpty ? reps : segments.fold(0, (sum, s) => sum + s.reps);
}
