/// A single segment within a drop set.
///
/// Normal sets have no segments. Drop sets have 2+ segments
/// representing each weight/rep block within the set.
class ExecutionSetSegment {
  final int id;
  final int executionSetId;
  final int segmentOrder;
  final int reps;
  final double? weight;

  const ExecutionSetSegment({
    required this.id,
    required this.executionSetId,
    required this.segmentOrder,
    required this.reps,
    this.weight,
  });
}
