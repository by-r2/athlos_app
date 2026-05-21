import '../../../../core/errors/result.dart';
import '../entities/cycle_step.dart';

/// Contract for the training cycle (ordered queue of workouts).
///
/// Every cycle belongs to a program — there is no free cycle.
abstract interface class CycleRepository {
  Future<Result<List<TrainingCycleStep>>> getSteps(String programId);
  Future<Result<void>> setSteps(List<TrainingCycleStep> steps, String programId);

  /// Removes any cycle step that references this workout (e.g. when archived).
  Future<Result<void>> removeWorkoutFromCycle(String workoutId, String programId);

  /// Removes a workout from ALL programs' cycles (used when archiving).
  Future<Result<void>> removeWorkoutFromAllCycles(String workoutId);

  /// Appends a workout step at the end of the cycle.
  Future<Result<void>> appendWorkoutToCycle(String workoutId, String programId);
}
