import '../../features/training/data/sync/training_sync_table_names.dart';
import 'sync_engine_v2.dart';
import 'sync_trigger.dart';

/// Wraps [SyncEngineV2] for authenticated user-owned data.
class UserOwnedSyncRunner {
  UserOwnedSyncRunner(this._engine);

  final SyncEngineV2? _engine;

  UserOwnedSyncRunner.disabled() : _engine = null;

  Future<void> synchronizeAuthenticatedUserData({
    required SyncTrigger trigger,
  }) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.synchronize();
  }

  /// Push/pull only workout execution tables (post-workout or cancel).
  Future<void> syncWorkoutSessionTables() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.synchronizeTable(TrainingSyncTableNames.workoutExecutions);
    await engine.synchronizeTable(TrainingSyncTableNames.executionSets);
  }

  Future<void> synchronizeTable(String tableName) async {
    await _engine?.synchronizeTable(tableName);
  }
}
