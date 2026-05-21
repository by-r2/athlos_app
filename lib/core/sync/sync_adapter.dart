/// Simplified sync adapter interface for UUID-first sync engine.
///
/// Each user-owned table implements this to handle push/pull.
/// [T] must expose a `String get id` field (Drift data classes satisfy this).
abstract class SyncAdapter<T> {
  String get tableName;

  String getId(T row);

  Future<List<T>> loadDirty();
  Future<List<T>> loadDirtyTombstones();
  Future<void> pushToRemote(List<T> rows);
  Future<void> pushDeletes(List<T> rows);
  Future<List<T>> pullFromRemote(DateTime lastPullAt);
  Future<void> applyRemoteRows(List<T> rows);
  Future<void> markClean(List<String> ids);
  Future<void> hardDelete(List<String> ids);
}
