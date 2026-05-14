import 'sync_trigger.dart';
import 'user_owned_sync_registry.dart';

/// Runs registered user-owned sync engines in a stable order.
class UserOwnedSyncRunner {
  UserOwnedSyncRunner(this._registry);

  final UserOwnedSyncRegistry _registry;
  DateTime? _lastResumeSyncAt;

  static const Duration resumeDebounce = Duration(seconds: 30);

  Future<void> synchronizeAuthenticatedUserData({
    required SyncTrigger trigger,
  }) async {
    if (trigger == SyncTrigger.resume) {
      final lastResumeSyncAt = _lastResumeSyncAt;
      final now = DateTime.now();
      if (lastResumeSyncAt != null &&
          now.difference(lastResumeSyncAt) < resumeDebounce) {
        return;
      }
      _lastResumeSyncAt = now;
    }

    for (final target in _registry.targets) {
      await target.synchronize();
    }
  }

  Future<void> synchronizeTable(String tableName) async {
    final target = _registry.targetForTable(tableName);
    if (target == null) return;
    await target.synchronize();
  }
}
