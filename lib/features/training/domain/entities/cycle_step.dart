/// A step in the training cycle: an ordered workout reference.
class TrainingCycleStep {
  final String id;
  final int orderIndex;
  final String workoutId;

  const TrainingCycleStep({
    required this.id,
    required this.orderIndex,
    required this.workoutId,
  });
}
