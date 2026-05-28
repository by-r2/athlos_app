import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/sync/sync_user_id.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

/// Hard-deletes rows on Supabase that were already removed locally during merge.
///
/// Exercise delete is scoped to [ownerId] (`created_by`); verified catalog rows
/// are not user-owned and are never targeted by duplicate resolution.
Future<void> pushDuplicateMergeDeletesToRemote({
  required TrainingRemoteClient remote,
  required String userId,
  required RuntimeDuplicateMergeSyncPayload payload,
}) async {
  if (!isValidSyncUserId(userId)) return;

  for (final id in payload.removedWorkoutExerciseIds) {
    if (!isValidSyncUserId(id)) continue;
    await remote.deleteRow(
      table: TrainingSyncTableNames.workoutExercises,
      id: id,
      userId: userId,
    );
  }

  for (final id in payload.removedProgressionRuleIds) {
    if (!isValidSyncUserId(id)) continue;
    await remote.deleteRow(
      table: TrainingSyncTableNames.progressionRules,
      id: id,
      userId: userId,
    );
  }

  final exerciseId = payload.removedExerciseId;
  if (isValidSyncUserId(exerciseId)) {
    await remote.deleteRow(
      table: TrainingSyncTableNames.exercises,
      id: exerciseId,
      ownerColumn: 'created_by',
      ownerId: userId,
    );
  }
}
