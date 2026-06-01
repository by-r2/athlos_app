import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../entities/exercise.dart';
import '../entities/workout_exercise.dart';
import '../helpers/build_execution_context_fallback.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/program_repository.dart';
import '../repositories/workout_execution_repository.dart';
import '../repositories/workout_repository.dart';

/// Parameters for [FinishWorkoutExecution].
class FinishWorkoutExecutionParams {
  final String executionId;
  final String workoutId;
  final String? programId;
  final List<WorkoutExercise> templateExercises;

  /// WorkoutExercise row id → catalog id before substitution.
  final Map<String, String> substitutionsByRowId;

  const FinishWorkoutExecutionParams({
    required this.executionId,
    required this.workoutId,
    this.programId,
    this.templateExercises = const [],
    this.substitutionsByRowId = const {},
  });
}

/// Finishes a workout execution and persists minimal context snapshots.
class FinishWorkoutExecution {
  final WorkoutExecutionRepository _executions;
  final WorkoutRepository _workouts;
  final ProgramRepository _programs;
  final ExerciseRepository _exercises;

  const FinishWorkoutExecution(
    this._executions,
    this._workouts,
    this._programs,
    this._exercises,
  );

  Future<Result<void>> call(FinishWorkoutExecutionParams params) async {
    final workoutResult = await _workouts.getById(params.workoutId);
    switch (workoutResult) {
      case Success(:final value):
        if (value == null) {
          return const Failure(NotFoundException('Workout not found'));
        }
        final workoutName = value.name;

        String? programName;
        final programId = params.programId;
        if (programId != null && programId.isNotEmpty) {
          final programResult = await _programs.getById(programId);
          switch (programResult) {
            case Success(:final value):
              programName = value?.name;
            case Failure(:final exception):
              return Failure(exception);
          }
        }

        final setsResult = await _executions.getSets(params.executionId);
        switch (setsResult) {
          case Success(:final value):
            final sessionExerciseIds = value.map((s) => s.exerciseId).toSet();
            final templateIds = params.templateExercises
                .map((e) => e.exerciseId)
                .toSet();
            final allIds = {...sessionExerciseIds, ...templateIds};

            final exercisesById = <String, Exercise>{};
            for (final id in allIds) {
              final exerciseResult = await _exercises.getById(id);
              switch (exerciseResult) {
                case Success(:final value):
                  if (value != null) exercisesById[id] = value;
                case Failure(:final exception):
                  return Failure(exception);
              }
            }

            final contextFallback = buildExecutionContextFallback(
              templateExercises: params.templateExercises,
              exercisesById: exercisesById,
              sessionExerciseIds: sessionExerciseIds,
              substitutionsByRowId: params.substitutionsByRowId,
            );

            return _executions.finishWithSnapshot(
              executionId: params.executionId,
              workoutNameSnapshot: workoutName,
              programNameSnapshot: programName,
              contextFallback: contextFallback,
            );
          case Failure(:final exception):
            return Failure(exception);
        }
      case Failure(:final exception):
        return Failure(exception);
    }
  }
}
