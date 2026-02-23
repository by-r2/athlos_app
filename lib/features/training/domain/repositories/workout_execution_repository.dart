import '../../../../core/errors/result.dart';
import '../entities/execution_set.dart';
import '../entities/workout_execution.dart';

/// Contract for workout execution data operations.
abstract interface class WorkoutExecutionRepository {
  Future<Result<List<WorkoutExecution>>> getAll();
  Future<Result<List<WorkoutExecution>>> getByWorkout(int workoutId);
  Future<Result<WorkoutExecution?>> getById(int id);
  Future<Result<WorkoutExecution?>> getLastFinished();
  Future<Result<int>> start(int workoutId);
  Future<Result<void>> finish(int executionId, {String? notes});
  Future<Result<void>> delete(int id);
  Future<Result<List<ExecutionSet>>> getSets(int executionId);
  Future<Result<int>> logSet(ExecutionSet set);
  Future<Result<void>> updateSet(ExecutionSet set);
}
