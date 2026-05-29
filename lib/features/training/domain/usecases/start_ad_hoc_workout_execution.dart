import '../../../../core/errors/result.dart';
import '../repositories/workout_repository.dart';

/// Parameters for [StartAdHocWorkoutExecution].
class StartAdHocWorkoutExecutionParams {
  final String draftWorkoutName;

  const StartAdHocWorkoutExecutionParams({required this.draftWorkoutName});
}

/// Creates a hidden draft workout row for an ad-hoc session.
///
/// Returns the new workout id. The caller starts execution separately.
class StartAdHocWorkoutExecution {
  final WorkoutRepository _workouts;

  const StartAdHocWorkoutExecution(this._workouts);

  Future<Result<String>> call(StartAdHocWorkoutExecutionParams params) =>
      _workouts.createDraft(name: params.draftWorkoutName);
}
