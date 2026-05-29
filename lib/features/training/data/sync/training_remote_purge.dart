import 'package:flutter/foundation.dart';

import '../../../../core/services/supabase_config.dart';
import '../../../../core/sync/sync_user_id.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

/// Best-effort hard removal of a workout template from Supabase.
///
/// When [deleteExecutions] is true (draft cancel), in-progress/finished rows for
/// that workout are removed too. When false (catalog delete), execution history
/// is kept on the server.
Future<void> purgeWorkoutFromRemoteIfPresent({
  required TrainingRemoteClient remote,
  required String userId,
  required String workoutId,
  bool deleteExecutions = false,
}) async {
  if (!isSupabaseConfigured || !isValidSyncUserId(userId)) return;
  if (!isValidSyncUserId(workoutId)) return;
  if (remote.currentUserId == null) return;

  try {
    if (deleteExecutions) {
      final executionIds = await remote.selectIds(
        table: TrainingSyncTableNames.workoutExecutions,
        userId: userId,
        filters: {'workout_id': workoutId},
      );
      if (executionIds.isNotEmpty) {
        await remote.deleteByColumnIn(
          table: TrainingSyncTableNames.executionSets,
          column: 'execution_id',
          values: executionIds,
          userId: userId,
        );
        await remote.deleteByFilter(
          table: TrainingSyncTableNames.workoutExecutions,
          userId: userId,
          filters: {'workout_id': workoutId},
        );
      }
    }

    await remote.deleteByFilter(
      table: TrainingSyncTableNames.cycleSteps,
      userId: userId,
      filters: {'workout_id': workoutId},
    );

    await remote.deleteByFilter(
      table: TrainingSyncTableNames.workoutExercises,
      userId: userId,
      filters: {'workout_id': workoutId},
    );

    await remote.deleteRow(
      table: TrainingSyncTableNames.workouts,
      id: workoutId,
      userId: userId,
    );
  } on Exception catch (e, st) {
    debugPrint(
      '[TrainingRemotePurge] failed to purge workout $workoutId: $e\n$st',
    );
  }
}
