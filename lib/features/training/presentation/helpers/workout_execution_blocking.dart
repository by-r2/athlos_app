import '../../domain/entities/workout_execution.dart';
import '../providers/active_execution_state.dart';

/// In-progress workout blocking navigation to another template.
class BlockingInProgressWorkout {
  const BlockingInProgressWorkout({
    required this.executionId,
    required this.workoutId,
  });

  final String executionId;
  final String workoutId;
}

/// Returns blocking in-progress workout for [targetWorkoutId], or null if safe.
BlockingInProgressWorkout? blockingInProgressWorkout({
  required WorkoutExecution? dangling,
  required ActiveExecutionState? active,
  required String targetWorkoutId,
}) {
  if (active != null) {
    if (active.workoutId == targetWorkoutId) return null;
    return BlockingInProgressWorkout(
      executionId: active.executionId,
      workoutId: active.workoutId,
    );
  }
  if (dangling != null) {
    if (dangling.workoutId == targetWorkoutId) return null;
    return BlockingInProgressWorkout(
      executionId: dangling.id,
      workoutId: dangling.workoutId,
    );
  }
  return null;
}
