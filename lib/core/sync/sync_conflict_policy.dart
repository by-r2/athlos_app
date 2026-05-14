import 'sync_status.dart';

/// Last-write-wins and dirty detection for user-owned sync.
abstract final class SyncConflictPolicy {
  static bool remoteWins({
    required DateTime? remoteUpdatedAt,
    required DateTime? lastSyncedAt,
    required DateTime? localUpdatedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (lastSyncedAt == null) return true;
    if (remoteUpdatedAt.isAfter(lastSyncedAt)) return true;
    if (lastSyncedAt.isAfter(remoteUpdatedAt)) return false;
    if (localUpdatedAt == null) return false;
    return remoteUpdatedAt.isAfter(localUpdatedAt);
  }

  static bool isDirty({
    required DateTime? localUpdatedAt,
    required DateTime? lastSyncedAt,
    required String? status,
  }) {
    if (status == SyncStatus.pending || status == SyncStatus.failed) {
      return true;
    }
    if (localUpdatedAt == null || lastSyncedAt == null) return true;
    return localUpdatedAt.isAfter(lastSyncedAt);
  }
}
