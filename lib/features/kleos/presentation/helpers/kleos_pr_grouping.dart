import '../../../training/presentation/providers/training_analytics_provider.dart';
import '../../../training/presentation/providers/training_metrics_provider.dart';

/// Best PR (highest estimated 1RM) per muscle group key.
Map<String, ExercisePRRecord> bestPrPerMuscleGroup(
  List<ExercisePRRecord> prs,
) {
  final best = <String, ExercisePRRecord>{};
  for (final pr in prs) {
    final current = best[pr.muscleGroup];
    if (current == null || pr.best1RM > current.best1RM) {
      best[pr.muscleGroup] = pr;
    }
  }
  return best;
}

/// Total finished sessions from [TrainingHomeAnalytics] counters.
int finishedSessionsFromAnalytics(TrainingHomeAnalytics analytics) =>
    analytics.archivedSessionsTotal +
    analytics.sessionsByActiveWorkoutId.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );
