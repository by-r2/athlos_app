import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../entities/workout_exercise.dart';
import '../repositories/cycle_repository.dart';
import '../repositories/workout_repository.dart';

/// What to do with an ad-hoc session template after finish.
enum AdHocSaveOutcome {
  /// Keep execution history only; remove the local draft workout template.
  historyOnly,

  /// Promote draft, persist exercises, and append to the program cycle.
  save,
}

/// Parameters for [PromoteAdHocWorkout].
class PromoteAdHocWorkoutParams {
  final String workoutId;
  final String programId;
  final String name;
  final List<WorkoutExercise> exercises;
  final AdHocSaveOutcome outcome;

  const PromoteAdHocWorkoutParams({
    required this.workoutId,
    required this.programId,
    required this.name,
    required this.exercises,
    required this.outcome,
  });
}

/// Persists or archives a draft workout after an ad-hoc session ends.
class PromoteAdHocWorkout {
  final WorkoutRepository _workouts;
  final CycleRepository _cycle;

  const PromoteAdHocWorkout(this._workouts, this._cycle);

  Future<Result<void>> call(PromoteAdHocWorkoutParams params) async {
    if (params.exercises.isEmpty &&
        params.outcome != AdHocSaveOutcome.historyOnly) {
      return const Failure(
        ValidationException('Cannot save a workout without exercises'),
      );
    }

    switch (params.outcome) {
      case AdHocSaveOutcome.historyOnly:
        return _workouts.deleteDraft(params.workoutId);

      case AdHocSaveOutcome.save:
        final promote = await _workouts.promoteDraft(
          params.workoutId,
          name: params.name,
        );
        switch (promote) {
          case Failure(:final exception):
            return Failure(exception);
          case Success():
            break;
        }
        final update = await _workouts.update(
          (await _workouts.getById(params.workoutId)).getOrThrow()!,
          params.exercises,
        );
        switch (update) {
          case Failure(:final exception):
            return Failure(exception);
          case Success():
            break;
        }
        return _cycle.appendWorkoutToCycle(params.workoutId, params.programId);
    }
  }
}
