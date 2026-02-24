import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/workout_execution.dart';
import 'workout_notifier.dart';

part 'workout_execution_notifier.g.dart';

/// All finished workout executions, most recent first.
@riverpod
class WorkoutExecutionList extends _$WorkoutExecutionList {
  @override
  Future<List<WorkoutExecution>> build() async {
    final repo = ref.watch(workoutExecutionRepositoryProvider);
    final result = await repo.getAll();
    return result.getOrThrow();
  }

  Future<void> deleteExecution(int id) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.delete(id);
    result.getOrThrow();
    ref.invalidateSelf();
    ref.invalidate(lastFinishedWorkoutIdProvider);
  }
}

/// Sets for a specific execution, with segments loaded.
@riverpod
Future<List<ExecutionSet>> executionSetsWithSegments(
    Ref ref, int executionId) async {
  final repo = ref.watch(workoutExecutionRepositoryProvider);
  final setsResult = await repo.getSets(executionId);
  final sets = setsResult.getOrThrow();

  final enriched = <ExecutionSet>[];
  for (final s in sets) {
    final segResult = await repo.getSegments(s.id);
    final segments = segResult.getOrThrow();
    if (segments.isNotEmpty) {
      enriched.add(ExecutionSet(
        id: s.id,
        executionId: s.executionId,
        exerciseId: s.exerciseId,
        setNumber: s.setNumber,
        plannedReps: s.plannedReps,
        plannedWeight: s.plannedWeight,
        reps: s.reps,
        weight: s.weight,
        isCompleted: s.isCompleted,
        notes: s.notes,
        segments: segments,
      ));
    } else {
      enriched.add(s);
    }
  }
  return enriched;
}
