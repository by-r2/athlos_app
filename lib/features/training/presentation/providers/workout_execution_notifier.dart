import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/sync/sync_user_id.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_execution.dart';
import 'active_execution_notifier.dart';
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

  Future<void> deleteExecution(String id) async {
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
  if (!isValidSyncUserId(ref.watch(authProvider).value?.id)) return null;

  // If there's an active in-memory session, it will always have an unfinished
  // DB row (by design). In that case we should not prompt "resume/discard".
  if (ref.watch(activeExecutionProvider) != null) return null;

  final repo = ref.watch(workoutExecutionRepositoryProvider);
  await repo.deleteOrphaned();
  final result = await repo.getDangling();
  final list = result.getOrThrow();
  return list.firstOrNull;
}

/// Sets for a specific execution, with segments loaded.
@riverpod
Future<List<ExecutionSet>> executionSetsWithSegments(
  Ref ref,
  String executionId,
) async {
  final repo = ref.watch(workoutExecutionRepositoryProvider);
  final setsResult = await repo.getSets(executionId);
  final sets = setsResult.getOrThrow();

  final allSegments = (await repo.getSegmentsForExecution(
    executionId,
  )).getOrThrow();

  // Group segments by executionSetId
  final segmentsBySetId = <String, List<ExecutionSetSegment>>{};
  for (final seg in allSegments) {
    segmentsBySetId.putIfAbsent(seg.executionSetId, () => []).add(seg);
  }

  return sets.map((s) {
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
  }).toList();
}

/// Resolves the exercise configuration for a past execution.
/// Falls back to the live workout template.
@riverpod
Future<List<WorkoutExercise>> executionExerciseConfig(
  Ref ref,
  WorkoutExecution execution,
) async {
  return ref.watch(workoutExercisesProvider(execution.workoutId).future);
}
