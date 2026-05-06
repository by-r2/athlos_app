import '../../domain/entities/execution_set.dart';

/// Aggregate stats for the shareable workout card (aligned with execution detail logic).
final class WorkoutShareMetrics {
  final double totalVolume;
  final int totalCompletedSets;
  final int totalPlannedSets;

  const WorkoutShareMetrics({
    required this.totalVolume,
    required this.totalCompletedSets,
    required this.totalPlannedSets,
  });
}

WorkoutShareMetrics computeWorkoutShareMetrics(List<ExecutionSet> sets) {
  var totalVolume = 0.0;
  var totalCompletedSets = 0;

  for (final s in sets) {
    if (!s.isCompleted) continue;
    totalCompletedSets++;
    if (s.segments.isNotEmpty) {
      for (final seg in s.segments) {
        totalVolume += (seg.reps) * (seg.weight ?? 0);
      }
    } else {
      totalVolume += (s.reps ?? 0) * (s.weight ?? 0);
    }
  }

  return WorkoutShareMetrics(
    totalVolume: totalVolume,
    totalCompletedSets: totalCompletedSets,
    totalPlannedSets: sets.length,
  );
}
