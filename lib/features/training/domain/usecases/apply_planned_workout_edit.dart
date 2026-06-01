import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../entities/workout_exercise.dart';
import '../repositories/workout_repository.dart';

/// What to do with structural edits after a planned session ends.
enum PlannedWorkoutEditOutcome {
  /// Keep execution history only; leave the saved workout template unchanged.
  sessionOnly,

  /// Apply session structure to the existing saved workout (in-place update).
  persist,
}

/// Parameters for [ApplyPlannedWorkoutEdit].
class ApplyPlannedWorkoutEditParams {
  final String workoutId;
  final List<WorkoutExercise> exercises;
  final PlannedWorkoutEditOutcome outcome;

  const ApplyPlannedWorkoutEditParams({
    required this.workoutId,
    required this.exercises,
    required this.outcome,
  });
}

/// Applies or discards structural edits made during a planned execution.
class ApplyPlannedWorkoutEdit {
  final WorkoutRepository _workouts;

  const ApplyPlannedWorkoutEdit(this._workouts);

  Future<Result<void>> call(ApplyPlannedWorkoutEditParams params) async {
    switch (params.outcome) {
      case PlannedWorkoutEditOutcome.sessionOnly:
        return const Success(null);

      case PlannedWorkoutEditOutcome.persist:
        if (params.exercises.isEmpty) {
          return const Failure(
            ValidationException('Cannot save a workout without exercises'),
          );
        }
        final workoutResult = await _workouts.getById(params.workoutId);
        switch (workoutResult) {
          case Failure(:final exception):
            return Failure(exception);
          case Success(:final value):
            if (value == null) {
              return Failure(
                NotFoundException('Workout ${params.workoutId} not found'),
              );
            }
            if (value.isDraft) {
              return const Failure(
                ValidationException(
                  'Planned workout edits cannot persist draft workouts',
                ),
              );
            }
            return _workouts.update(value, params.exercises);
        }
    }
  }
}
