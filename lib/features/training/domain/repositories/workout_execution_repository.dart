import '../../../../core/errors/result.dart';
import '../entities/execution_comparison.dart';
import '../entities/execution_context_fallback.dart';
import '../entities/execution_set.dart';
import '../entities/execution_set_segment.dart';
import '../entities/workout_execution.dart';
import '../enums/session_kind.dart';

/// Contract for workout execution data operations.
abstract interface class WorkoutExecutionRepository {
  Future<Result<List<WorkoutExecution>>> getAll();

  /// Count of finished, non-deleted executions for the current user.
  Future<Result<int>> countFinished();

  Future<Result<List<WorkoutExecution>>> getByWorkout(String workoutId);
  Future<Result<WorkoutExecution?>> getById(String id);
  Future<Result<WorkoutExecution?>> getLastFinished();

  /// Last finished **planned** execution for a workout in [programId]'s cycle.
  Future<Result<WorkoutExecution?>> getLastFinishedForCycle({
    required String programId,
    required List<String> cycleWorkoutIds,
  });

  /// Last two finished executions for [workoutId] with total volume (weight x reps).
  /// Returns null if there are fewer than two finished executions.
  Future<Result<ExecutionComparison?>> getLastTwoFinishedWithVolume(
    String workoutId,
  );

  /// Unfinished executions (started but never finished/cancelled).
  Future<Result<List<WorkoutExecution>>> getDangling();

  Future<Result<String>> start(
    String workoutId, {
    String? programId,
    SessionKind sessionKind = SessionKind.planned,
  });

  /// Deletes only unfinished executions (with sets/segments) for a workout.
  /// Finished executions are preserved as training history.
  Future<Result<void>> deleteUnfinishedByWorkout(String workoutId);

  /// Deletes executions referencing workouts that no longer exist.
  Future<Result<void>> deleteOrphaned();
  Future<Result<void>> finish(String executionId);

  /// Marks [executionId] finished and stores history fallback snapshots.
  Future<Result<void>> finishWithSnapshot({
    required String executionId,
    required String workoutNameSnapshot,
    String? programNameSnapshot,
    required ExecutionContextFallback contextFallback,
  });
  Future<Result<void>> delete(String id);
  Future<Result<List<ExecutionSet>>> getSets(String executionId);
  Future<Result<String>> logSet(ExecutionSet set);
  Future<Result<void>> updateSet(ExecutionSet set);

  /// Updates catalog [exerciseId] and planned snapshots (e.g. after substitution).
  Future<Result<void>> rekeySetCatalogExercise(ExecutionSet set);
  Future<Result<Map<String, double>>> getLastWeightsForExercises(
    List<String> exerciseIds,
  );

  /// Completed sets from the most recent finished execution
  /// that included [exerciseId].
  Future<Result<List<ExecutionSet>>> getLastCompletedSetsForExercise(
    String exerciseId,
  );

  /// All completed sets for [exerciseId] across all finished
  /// executions (for PR detection and 1RM history).
  Future<Result<List<ExecutionSet>>> getAllCompletedSetsForExercise(
    String exerciseId,
  );

  /// Completed sets for [exerciseId] with the execution date,
  /// for charting load progression over time.
  Future<Result<List<({ExecutionSet set, DateTime date})>>>
  getCompletedSetsWithDateForExercise(String exerciseId);

  // --- Segments (drop sets) ---
  Future<Result<List<ExecutionSetSegment>>> getSegments(String executionSetId);
  Future<Result<List<ExecutionSetSegment>>> getSegmentsForExecution(
    String executionId,
  );
  Future<Result<void>> saveSegments(
    String executionSetId,
    List<ExecutionSetSegment> segments,
  );
}
