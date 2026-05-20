import '../database/app_database.dart';
import '../errors/app_exception.dart';
import 'sync_conflict_policy.dart';
import 'sync_record_store.dart';
import 'sync_status.dart';
import 'user_owned_singleton_sync_adapter.dart';
import 'user_owned_sync_target.dart';

/// Reconciles and pushes a single user-owned row (profile).
class UserOwnedSingletonSyncEngine<T> implements UserOwnedSyncTarget {
  UserOwnedSingletonSyncEngine({
    required UserOwnedSingletonSyncAdapter<T> adapter,
    required SyncRecordStore store,
  }) : _adapter = adapter,
       _store = store;

  final UserOwnedSingletonSyncAdapter<T> _adapter;
  final SyncRecordStore _store;

  String get tableName => _adapter.tableName;

  Future<void> synchronize() async {
    final remoteUserId = _adapter.currentRemoteUserId;
    if (remoteUserId == null) return;

    final local = await _adapter.loadLocalRow();
    final remote = await _adapter.fetchRemoteRow();

    if (local == null && remote == null) return;

    if (local == null && remote != null) {
      await _adapter.insertFromRemote(remote, remoteUserId);
      return;
    }

    final localRow = local!;
    _assertProfileBelongsToSession(localRow, remoteUserId);

    if (remote == null) {
      if (_isDirty(localRow, null)) {
        await _pushLocal(localRow, remoteUserId);
      }
      return;
    }

    if (SyncConflictPolicy.remoteWins(
      remoteUpdatedAt: remote.remoteUpdatedAt,
      lastSyncedAt: localRow.lastSyncedAt,
      localUpdatedAt: localRow.localUpdatedAt,
    )) {
      await _adapter.updateLocalFromRemote(
        localRow.localId,
        remote,
        remoteUserId,
      );
      return;
    }

    if (_isDirty(localRow, null) ||
        localRow.remoteUserId == null ||
        localRow.remoteUserId != remoteUserId) {
      await _pushLocal(localRow, remoteUserId);
    }
  }

  Future<void> synchronizeAfterMutation(int localId) async {
    await _adapter.markLocalDirty(localId);
    await synchronize();
  }

  Future<void> _pushLocal(
    UserOwnedSingletonLocalRow<T> local,
    String remoteUserId,
  ) async {
    final record = await _store.getByLocalId(
      tableName: _adapter.tableName,
      localId: local.localId,
    );
    final syncId = record?.syncId ?? remoteUserId;

    await _store.upsert(
      tableName: _adapter.tableName,
      localId: local.localId,
      syncId: syncId,
      remoteId: remoteUserId,
      remoteUserId: remoteUserId,
      status: SyncStatus.pending,
    );

    try {
      final syncedAt = await _adapter.pushUpsert(
        localId: local.localId,
        entity: local.entity,
      );
      await _adapter.markLocalSynced(
        localId: local.localId,
        remoteUserId: remoteUserId,
        syncedAt: syncedAt,
      );
      await _store.upsert(
        tableName: _adapter.tableName,
        localId: local.localId,
        syncId: syncId,
        remoteId: remoteUserId,
        remoteUserId: remoteUserId,
        status: SyncStatus.synced,
        lastPushedAt: syncedAt,
      );
    } on Exception {
      await _store.upsert(
        tableName: _adapter.tableName,
        localId: local.localId,
        syncId: syncId,
        remoteId: remoteUserId,
        remoteUserId: remoteUserId,
        status: SyncStatus.failed,
      );
    }
  }

  bool _isDirty(UserOwnedSingletonLocalRow<T> local, SyncRecord? record) =>
      _store.isDirty(
        localUpdatedAt: local.localUpdatedAt,
        lastSyncedAt: local.lastSyncedAt,
        status: record?.status,
      );

  void _assertProfileBelongsToSession(
    UserOwnedSingletonLocalRow<T> local,
    String remoteUserId,
  ) {
    if (local.remoteUserId != null && local.remoteUserId != remoteUserId) {
      throw const ValidationException(
        'Profile is linked to a different account.',
      );
    }
  }
}
