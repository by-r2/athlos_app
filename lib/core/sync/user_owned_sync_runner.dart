import 'sync_engine_v2.dart';
import 'sync_trigger.dart';

/// Wraps [SyncEngineV2] with debouncing for resume triggers.
class UserOwnedSyncRunner {
  UserOwnedSyncRunner(this._engine);

  final SyncEngineV2? _engine;
  DateTime? _lastResumeSyncAt;

  static const Duration resumeDebounce = Duration(seconds: 30);

  UserOwnedSyncRunner.disabled() : _engine = null, _lastResumeSyncAt = null;

  Future<void> synchronizeAuthenticatedUserData({
    required SyncTrigger trigger,
  }) async {
    final engine = _engine;
    if (engine == null) return;

    if (trigger == SyncTrigger.resume) {
      final last = _lastResumeSyncAt;
      final now = DateTime.now();
      if (last != null && now.difference(last) < resumeDebounce) return;
      _lastResumeSyncAt = now;
    }

    await engine.synchronize();
  }

  Future<void> synchronizeTable(String tableName) async {
    await _engine?.synchronizeTable(tableName);
  }
}
