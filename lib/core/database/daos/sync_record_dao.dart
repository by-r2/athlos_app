import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_records_table.dart';

part 'sync_record_dao.g.dart';

@DriftAccessor(tables: [SyncRecords])
class SyncRecordDao extends DatabaseAccessor<AppDatabase>
    with _$SyncRecordDaoMixin {
  SyncRecordDao(super.db);

  Future<SyncRecord?> getByLocalId({
    required String tableName,
    required int localId,
  }) =>
      (select(syncRecords)
            ..where(
              (r) =>
                  r.entityTableName.equals(tableName) &
                  r.localId.equals(localId),
            ))
          .getSingleOrNull();

  Future<SyncRecord?> getBySyncId(String syncId) =>
      (select(syncRecords)..where((r) => r.syncId.equals(syncId)))
          .getSingleOrNull();

  Future<List<SyncRecord>> listForTable(
    String tableName, {
    String? status,
  }) {
    final query = select(syncRecords)
      ..where((r) => r.entityTableName.equals(tableName));
    if (status != null) {
      query.where((r) => r.status.equals(status));
    }
    return query.get();
  }

  Future<List<SyncRecord>> listPendingOrFailed(String tableName) =>
      (select(syncRecords)
            ..where(
              (r) =>
                  r.entityTableName.equals(tableName) &
                  r.status.isIn(const ['pending', 'failed']),
            ))
          .get();

  Future<void> upsertRecord({
    required String tableName,
    required int localId,
    required String syncId,
    String? remoteId,
    String? remoteUserId,
    required String status,
    DateTime? deletedAt,
  }) async {
    final existing = await getByLocalId(tableName: tableName, localId: localId);
    final now = DateTime.now();
    if (existing == null) {
      await into(syncRecords).insert(
        SyncRecordsCompanion.insert(
          entityTableName: tableName,
          localId: localId,
          syncId: syncId,
          remoteId: Value(remoteId),
          remoteUserId: Value(remoteUserId),
          status: Value(status),
          deletedAt: Value(deletedAt),
          updatedAt: Value(now),
        ),
      );
      return;
    }

    await (update(syncRecords)..where((r) => r.id.equals(existing.id))).write(
      SyncRecordsCompanion(
        syncId: Value(syncId),
        remoteId: Value(remoteId),
        remoteUserId: Value(remoteUserId),
        status: Value(status),
        deletedAt: Value(deletedAt),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteByLocalId({
    required String tableName,
    required int localId,
  }) async {
    await (delete(syncRecords)
          ..where(
            (r) =>
                r.entityTableName.equals(tableName) & r.localId.equals(localId),
          ))
        .go();
  }
}
