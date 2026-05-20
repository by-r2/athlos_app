import '../database/app_database.dart';
import '../database/daos/sync_record_dao.dart';
import 'sync_conflict_policy.dart';
import 'sync_status.dart';

/// Unified API over [SyncRecordDao] for user-owned sync engines.
class SyncRecordStore {
  const SyncRecordStore(this._dao);

  final SyncRecordDao _dao;

  Future<SyncRecord?> getByLocalId({
    required String tableName,
    required int localId,
  }) =>
      _dao.getByLocalId(tableName: tableName, localId: localId);

  Future<SyncRecord?> getByRemoteId({
    required String tableName,
    required String remoteId,
  }) =>
      _dao.getByRemoteId(tableName: tableName, remoteId: remoteId);

  Future<SyncRecord?> getBySyncId(String syncId) => _dao.getBySyncId(syncId);

  Future<List<SyncRecord>> listForTable(String tableName) =>
      _dao.listForTable(tableName);

  Future<List<SyncRecord>> listPendingOrFailed(String tableName) =>
      _dao.listPendingOrFailed(tableName);

  Future<List<SyncRecord>> listTombstones(String tableName) =>
      _dao.listTombstones(tableName);

  Future<int> resetFailedToPending({String? tableName}) =>
      _dao.resetFailedToPending(tableName: tableName);

  Future<void> upsert({
    required String tableName,
    required int localId,
    required String syncId,
    String? remoteId,
    String? remoteUserId,
    required String status,
    DateTime? deletedAt,
    DateTime? lastPushedAt,
  }) =>
      _dao.upsertRecord(
        tableName: tableName,
        localId: localId,
        syncId: syncId,
        remoteId: remoteId,
        remoteUserId: remoteUserId,
        status: status,
        deletedAt: deletedAt,
        lastPushedAt: lastPushedAt,
      );

  Future<void> deleteByLocalId({
    required String tableName,
    required int localId,
  }) =>
      _dao.deleteByLocalId(tableName: tableName, localId: localId);

  Future<void> markTombstone({
    required String tableName,
    required int localId,
    required String syncId,
    String? remoteId,
    String? remoteUserId,
  }) =>
      upsert(
        tableName: tableName,
        localId: localId,
        syncId: syncId,
        remoteId: remoteId,
        remoteUserId: remoteUserId,
        status: SyncStatus.deleted,
        deletedAt: DateTime.now().toUtc(),
      );

  bool isDirty({
    required DateTime? localUpdatedAt,
    required DateTime? lastSyncedAt,
    required String? status,
  }) =>
      SyncConflictPolicy.isDirty(
        localUpdatedAt: localUpdatedAt,
        lastSyncedAt: lastSyncedAt,
        status: status,
      );
}
