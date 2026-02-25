import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import 'active_execution_state.dart';
export 'active_execution_state.dart';
import 'workout_execution_notifier.dart';
import 'workout_notifier.dart';

part 'active_execution_notifier.g.dart';

@Riverpod(keepAlive: true)
class ActiveExecution extends _$ActiveExecution {
  @override
  ActiveExecutionState? build() => null;

  /// Start a new execution, creating the DB record and pre-populating sets
  /// from the workout template.
  Future<void> startExecution(
    int workoutId,
    List<WorkoutExercise> exercises,
  ) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.start(workoutId);
    final executionId = result.getOrThrow();

    final exerciseIds = exercises.map((e) => e.exerciseId).toList();
    final weightsResult =
        await repo.getLastWeightsForExercises(exerciseIds);
    final lastWeights = weightsResult.getOrThrow();

    final exerciseSets = <int, List<SetEntry>>{};
    for (final ex in exercises) {
      final lastWeight = lastWeights[ex.exerciseId];
      exerciseSets[ex.exerciseId] = List.generate(
        ex.sets,
        (i) => SetEntry(
          setNumber: i + 1,
          plannedReps: ex.reps,
          plannedWeight: lastWeight,
          reps: ex.reps,
        ),
      );
    }

    state = ActiveExecutionState(
      executionId: executionId,
      workoutId: workoutId,
      exerciseSets: exerciseSets,
      exercises: exercises,
    );
  }

  /// Update local set values (weight/reps) without persisting yet.
  void updateSet(int exerciseId, int setNumber, {int? reps, double? weight}) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            reps: reps ?? s.reps,
            weight: weight != null ? () => weight : null,
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Add a drop segment to a set (in-memory only, persisted on complete).
  void addDropSegment(int exerciseId, int setNumber,
      {required int reps, double? weight}) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            segments: [
              ...s.segments,
              SegmentEntry(reps: reps, weight: weight),
            ],
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Remove a drop segment by index.
  void removeDropSegment(int exerciseId, int setNumber, int segmentIndex) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            segments: [
              for (var i = 0; i < s.segments.length; i++)
                if (i != segmentIndex) s.segments[i],
            ],
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Mark a set as completed and persist it to the database.
  /// Returns the restSeconds for the exercise so the caller can start the timer.
  Future<int> completeSet(
    int exerciseId,
    int setNumber, {
    required int reps,
    double? weight,
    List<SegmentEntry>? segments,
  }) async {
    final current = state;
    if (current == null) return 0;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return 0;

    final entry = sets.firstWhere((s) => s.setNumber == setNumber);
    final effectiveSegments = segments ?? entry.segments;

    final executionSet = ExecutionSet(
      id: entry.id ?? 0,
      executionId: current.executionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      plannedReps: entry.plannedReps,
      plannedWeight: entry.plannedWeight,
      reps: reps,
      weight: weight,
      isCompleted: true,
    );

    final domainSegments = effectiveSegments
        .map((s) => ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 0,
              reps: s.reps,
              weight: s.weight,
            ))
        .toList();

    final useCase = ref.read(completeSetUseCaseProvider);
    final result = await useCase(
      CompleteSetParams(set: executionSet, segments: domainSegments),
    );
    final setId = result.getOrThrow();

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            id: setId,
            reps: reps,
            weight: () => weight,
            isCompleted: true,
            segments: effectiveSegments,
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );

    final exercise = current.exercises.firstWhere(
      (e) => e.exerciseId == exerciseId,
    );
    return exercise.restSeconds;
  }

  /// Finish the active execution, persisting finishedAt.
  Future<void> finishExecution() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(isFinishing: true);

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.finish(current.executionId);
    result.getOrThrow();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);

    state = null;
  }

  /// Cancel the active execution, deleting the DB record.
  Future<void> cancelExecution() async {
    final current = state;
    if (current == null) return;

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.delete(current.executionId);
    result.getOrThrow();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);

    state = null;
  }
}
