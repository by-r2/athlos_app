/// Standard sync record statuses for user-owned entities.
abstract final class SyncStatus {
  static const String pending = 'pending';
  static const String synced = 'synced';
  static const String failed = 'failed';
  static const String deleted = 'deleted';
}
