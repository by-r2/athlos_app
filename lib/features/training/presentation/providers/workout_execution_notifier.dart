import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/workout_exercise.dart';
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

/// Unfinished execution whose workout still exists. Null if clean.
/// Auto-deletes orphaned executions (workout was deleted) on first load.
@riverpod
Future<WorkoutExecution?> danglingExecution(Ref ref) async {
  final repo = ref.watch(workoutExecutionRepositoryProvider);
  await repo.deleteOrphaned();
  final result = await repo.getDangling();
  final list = result.getOrThrow();
  return list.firstOrNull;
}

/// Sets for a specific execution, with segments loaded.
@riverpod
Future<List<ExecutionSet>> executionSetsWithSegments(
    Ref ref, int executionId) async {
  final repo = ref.watch(workoutExecutionRepositoryProvider);
  final setsResult = await repo.getSets(executionId);
  final sets = setsResult.getOrThrow();

  final allSegments =
      (await repo.getSegmentsForExecution(executionId)).getOrThrow();

  // Group segments by executionSetId
  final segmentsBySetId = <int, List<ExecutionSetSegment>>{};
  for (final seg in allSegments) {
    segmentsBySetId.putIfAbsent(seg.executionSetId, () => []).add(seg);
  }

  return sets
      .map((s) {
        final segments = segmentsBySetId[s.id];
        if (segments != null && segments.isNotEmpty) {
          return ExecutionSet(
            id: s.id,
            executionId: s.executionId,
            exerciseId: s.exerciseId,
            setNumber: s.setNumber,
            plannedReps: s.plannedReps,
            plannedWeight: s.plannedWeight,
            reps: s.reps,
            weight: s.weight,
            isCompleted: s.isCompleted,
            isWarmup: s.isWarmup,
            rpe: s.rpe,
            bodyWeightSnapshot: s.bodyWeightSnapshot,
            loadModeOverride: s.loadModeOverride,
            segments: segments,
          );
        }
        return s;
      })
      .toList();
}

/// Resolves the exercise configuration for a past execution.
/// Prefers the JSON snapshot saved at execution time; falls back to the
/// live workout template for older executions without a snapshot.
@riverpod
Future<List<WorkoutExercise>> executionExerciseConfig(
    Ref ref, WorkoutExecution execution) async {
  final snapshot = execution.exerciseConfigSnapshot;
  if (snapshot != null && snapshot.isNotEmpty) {
    return _parseExerciseSnapshot(execution.workoutId, snapshot);
  }
  return ref.watch(workoutExercisesProvider(execution.workoutId).future);
}

List<WorkoutExercise> _parseExerciseSnapshot(
    int workoutId, String jsonSnapshot) {
  final list = (jsonDecode(jsonSnapshot) as List).cast<Map<String, dynamic>>();
  return list
      .map((e) => WorkoutExercise(
            workoutId: workoutId,
            exerciseId: e['exerciseId'] as int,
            order: e['order'] as int? ?? 0,
            sets: e['sets'] as int,
            minReps: e['minReps'] as int?,
            maxReps: e['maxReps'] as int?,
            isAmrap: e['isAmrap'] as bool? ?? false,
            rest: e['rest'] as int? ?? 0,
            duration: e['duration'] as int?,
            groupId: e['groupId'] as int?,
            isUnilateral: e['isUnilateral'] as bool? ?? false,
            notes: e['notes'] as String?,
          ))
      .toList();
}
