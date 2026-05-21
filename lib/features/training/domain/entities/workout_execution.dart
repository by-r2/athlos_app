/// Record of a completed (or in-progress) workout execution.
class WorkoutExecution {
  final String id;
  final String workoutId;
  final String? programId;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const WorkoutExecution({
    required this.id,
    required this.workoutId,
    this.programId,
    required this.startedAt,
    this.finishedAt,
  });

  bool get isFinished => finishedAt != null;

  Duration? get duration => finishedAt?.difference(startedAt);
}
