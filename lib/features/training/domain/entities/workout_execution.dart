/// Record of a completed (or in-progress) workout execution.
class WorkoutExecution {
  final int id;
  final int workoutId;
  final int programId;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// JSON snapshot of the workout exercise configuration at execution start.
  final String? exerciseConfigSnapshot;

  const WorkoutExecution({
    required this.id,
    required this.workoutId,
    required this.programId,
    required this.startedAt,
    this.finishedAt,
    this.exerciseConfigSnapshot,
  });

  bool get isFinished => finishedAt != null;

  Duration? get duration => finishedAt?.difference(startedAt);
}
