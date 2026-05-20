import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../errors/app_exception.dart';
import 'sync_conflict_policy.dart';
import 'sync_deferred_exception.dart';
import 'sync_record_store.dart';
import 'sync_status.dart';
import 'user_owned_collection_sync_adapter.dart';
import 'user_owned_sync_target.dart';

/// Reconciles and pushes user-owned collections with stable remote identity.
class UserOwnedCollectionSyncEngine<T> implements UserOwnedSyncTarget {
  UserOwnedCollectionSyncEngine({
    required UserOwnedCollectionSyncAdapter<T> adapter,
    required SyncRecordStore store,
  }) : _adapter = adapter,
       _store = store;

  final UserOwnedCollectionSyncAdapter<T> _adapter;
  final SyncRecordStore _store;

  String get tableName => _adapter.tableName;

  Future<void> synchronize() async {
    final remoteUserId = _adapter.currentRemoteUserId;
    if (remoteUserId == null) return;

    await _pushTombstones(remoteUserId);
    await _reconcileRemotes(remoteUserId);
    await _pushDirtyLocals(remoteUserId);
  }

  Future<void> synchronizeAfterMutation(int localId) async {
    await _adapter.markLocalDirty(localId);
    await synchronize();
  }

  Future<void> _reconcileRemotes(String remoteUserId) async {
    final locals = await _adapter.loadLocalRows();
    final records = await _store.listForTable(_adapter.tableName);
    final remotes = await _adapter.fetchRemoteRows();

    final localByRemoteId = <String, UserOwnedSyncLocalRow<T>>{
      for (final local in locals)
        if (local.remoteId != null) local.remoteId!: local,
    };
    final recordByLocalId = {for (final record in records) record.localId: record};
    final recordBySyncId = <String, SyncRecord>{};
    final recordByRemoteId = <String, SyncRecord>{};
    for (final record in records) {
      recordBySyncId[record.syncId] = record;
      final remoteId = record.remoteId;
      if (remoteId != null) {
        recordByRemoteId[remoteId] = record;
      }
    }

    final processedRemoteIds = <String>{};

    for (final remote in remotes) {
      final remoteId = remote.remoteId;
      if (processedRemoteIds.contains(remoteId)) continue;

      final localId = _resolveLocalId(
        remoteId: remoteId,
        localByRemoteId: localByRemoteId,
        recordBySyncId: recordBySyncId,
        recordByRemoteId: recordByRemoteId,
      );

      if (localId != null) {
        processedRemoteIds.add(remoteId);
        final local = locals.cast<UserOwnedSyncLocalRow<T>?>().firstWhere(
          (row) => row?.localId == localId,
          orElse: () => null,
        );
        if (local == null) continue;
        final record = recordByLocalId[localId];
        if (record != null) {
          _assertRecordBelongsToSession(record, remoteUserId);
        }

        if (SyncConflictPolicy.remoteWins(
          remoteUpdatedAt: remote.remoteUpdatedAt,
          lastSyncedAt: local.lastSyncedAt,
          localUpdatedAt: local.localUpdatedAt,
        )) {
          try {
            await _adapter.updateLocalFromRemote(
              localId,
              remote,
              remoteUserId,
            );
          } on Exception catch (e) {
            if (kDebugMode) {
              debugPrint(
                '[Sync] pull failed ${_adapter.tableName}#$localId: $e',
              );
            }
            continue;
          }
          await _markReconciledFromRemote(
            localId: localId,
            remoteId: remoteId,
            remoteUserId: remoteUserId,
            record: record,
          );
        } else if (_isDirty(local, record)) {
          await _pushLocal(
            local: local,
            record: record,
            remoteUserId: remoteUserId,
            remoteId: record?.remoteId ?? remoteId,
          );
        } else if (record == null) {
          await _markReconciledFromRemote(
            localId: localId,
            remoteId: remoteId,
            remoteUserId: remoteUserId,
            record: null,
          );
        }
        continue;
      }

      if (localByRemoteId.containsKey(remoteId)) continue;

      processedRemoteIds.add(remoteId);
      try {
        final insertedLocalId = await _adapter.insertFromRemote(
          remote,
          remoteUserId,
        );
        await _markReconciledFromRemote(
          localId: insertedLocalId,
          remoteId: remoteId,
          remoteUserId: remoteUserId,
          record: null,
        );
      } on Exception catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[Sync] insert failed ${_adapter.tableName} remote=$remoteId: $e',
          );
        }
      }
    }
  }

  Future<void> _markReconciledFromRemote({
    required int localId,
    required String remoteId,
    required String remoteUserId,
    required SyncRecord? record,
  }) async {
    final syncId = record?.syncId ?? remoteId;
    await _store.upsert(
      tableName: _adapter.tableName,
      localId: localId,
      syncId: syncId,
      remoteId: remoteId,
      remoteUserId: remoteUserId,
      status: SyncStatus.synced,
    );
  }

  Future<void> _pushTombstones(String remoteUserId) async {
    final tombstones = await _store.listTombstones(_adapter.tableName);
    for (final record in tombstones) {
      _assertRecordBelongsToSession(record, remoteUserId);
      final remoteId = record.remoteId ?? record.syncId;
      try {
        await _adapter.pushDelete(remoteId);
        await _store.deleteByLocalId(
          tableName: _adapter.tableName,
          localId: record.localId,
        );
      } on Exception {
        await _store.upsert(
          tableName: _adapter.tableName,
          localId: record.localId,
          syncId: record.syncId,
          remoteId: record.remoteId,
          remoteUserId: record.remoteUserId,
          status: SyncStatus.failed,
          deletedAt: record.deletedAt,
        );
      }
    }
  }

  Future<void> _pushDirtyLocals(String remoteUserId) async {
    final locals = await _adapter.loadLocalRows();
    final records = await _store.listForTable(_adapter.tableName);
    final recordByLocalId = {for (final record in records) record.localId: record};

    for (final local in locals) {
      final record = recordByLocalId[local.localId];
      if (record != null) {
        _assertRecordBelongsToSession(record, remoteUserId);
        if (!_isDirty(local, record)) continue;
        final remoteId = record.remoteId ?? record.syncId;
        await _pushLocal(
          local: local,
          record: record,
          remoteUserId: remoteUserId,
          remoteId: remoteId,
        );
        continue;
      }

      if (!_isDirty(local, null)) continue;
      await _pushLocal(
        local: local,
        record: null,
        remoteUserId: remoteUserId,
        remoteId: local.remoteId,
      );
    }
  }

  Future<void> _pushLocal({
    required UserOwnedSyncLocalRow<T> local,
    required SyncRecord? record,
    required String remoteUserId,
    required String? remoteId,
  }) async {
    final syncId = _adapter.resolveStableSyncId(
      localId: local.localId,
      existingSyncId: record?.syncId,
      entityRemoteId: local.remoteId ?? remoteId,
    );
    final effectiveRemoteId = record?.remoteId ?? local.remoteId ?? syncId;

    await _store.upsert(
      tableName: _adapter.tableName,
      localId: local.localId,
      syncId: syncId,
      remoteId: effectiveRemoteId,
      remoteUserId: remoteUserId,
      status: SyncStatus.pending,
    );

    try {
      final syncedAt = await _adapter.pushUpsert(
        localId: local.localId,
        entity: local.entity,
        remoteId: effectiveRemoteId,
      );
      await _adapter.markLocalSynced(
        localId: local.localId,
        remoteId: effectiveRemoteId,
        syncedAt: syncedAt,
        remoteUserId: remoteUserId,
      );
      await _store.upsert(
        tableName: _adapter.tableName,
        localId: local.localId,
        syncId: syncId,
        remoteId: effectiveRemoteId,
        remoteUserId: remoteUserId,
        status: SyncStatus.synced,
        lastPushedAt: syncedAt,
      );
    } on SyncDeferredException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Sync] deferred ${_adapter.tableName}#${local.localId}: $e',
        );
      }
      await _store.upsert(
        tableName: _adapter.tableName,
        localId: local.localId,
        syncId: syncId,
        remoteId: effectiveRemoteId,
        remoteUserId: remoteUserId,
        status: SyncStatus.pending,
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Sync] failed ${_adapter.tableName}#${local.localId}: $e',
        );
      }
      await _store.upsert(
        tableName: _adapter.tableName,
        localId: local.localId,
        syncId: syncId,
        remoteId: effectiveRemoteId,
        remoteUserId: remoteUserId,
        status: SyncStatus.failed,
      );
    }
  }

  int? _resolveLocalId({
    required String remoteId,
    required Map<String, UserOwnedSyncLocalRow<T>> localByRemoteId,
    required Map<String, SyncRecord> recordBySyncId,
    required Map<String, SyncRecord> recordByRemoteId,
  }) {
    final record = recordByRemoteId[remoteId] ?? recordBySyncId[remoteId];
    if (record != null) return record.localId;
    return localByRemoteId[remoteId]?.localId;
  }

  bool _isDirty(UserOwnedSyncLocalRow<T> local, SyncRecord? record) =>
      _store.isDirty(
        localUpdatedAt: local.localUpdatedAt,
        lastSyncedAt: local.lastSyncedAt,
        status: record?.status,
      );

  void _assertRecordBelongsToSession(SyncRecord record, String remoteUserId) {
    if (record.remoteUserId != null && record.remoteUserId != remoteUserId) {
      throw const ValidationException(
        'Synced row is linked to a different account.',
      );
    }
  }
}
