import '../../domain/entities/execution_set.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/helpers/training_metrics.dart';

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

WorkoutShareMetrics computeWorkoutShareMetrics(
  List<ExecutionSet> sets, {
  Map<String, Exercise>? exerciseById,
  Map<String, WorkoutExercise>? workoutExerciseByExerciseId,
  double? profileBodyWeightOnExecutionDate,
  double? latestBodyWeight,
}) {
  var totalCompletedSets = 0;
  for (final s in sets) {
    if (s.isCompleted) totalCompletedSets++;
  }

  return WorkoutShareMetrics(
    totalVolume: computeTotalVolume(
      sets,
      exerciseById: exerciseById,
      workoutExerciseByExerciseId: workoutExerciseByExerciseId,
      profileBodyWeightOnExecutionDate: profileBodyWeightOnExecutionDate,
      latestBodyWeight: latestBodyWeight,
    ),
    totalCompletedSets: totalCompletedSets,
    totalPlannedSets: sets.length,
  );
}
