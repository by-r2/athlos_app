import 'sync_record_store.dart';

/// Maps local Drift integer IDs to remote UUIDs via [SyncRecordStore].
class SyncRemoteIdResolver {
  const SyncRemoteIdResolver(this._store);

  final SyncRecordStore _store;

  Future<String?> remoteIdFor({
    required String tableName,
    required int localId,
  }) async {
    final record = await _store.getByLocalId(
      tableName: tableName,
      localId: localId,
    );
    return record?.remoteId ?? record?.syncId;
  }

  Future<int?> localIdFor({
    required String tableName,
    required String remoteId,
  }) async {
    final record = await _store.getByRemoteId(
      tableName: tableName,
      remoteId: remoteId,
    );
    return record?.localId;
  }
}
