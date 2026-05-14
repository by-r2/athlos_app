import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/sync_record_dao.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../../domain/repositories/body_metric_repository.dart';
import '../datasources/body_metric_remote_sync_gateway.dart';
import '../datasources/daos/body_metric_dao.dart';

const _tableBodyMetrics = 'body_metrics';

class BodyMetricRepositoryImpl implements BodyMetricRepository {
  BodyMetricRepositoryImpl(
    this._dao,
    this._syncRecordDao, {
    BodyMetricRemoteSyncGateway? remoteGateway,
  }) : _remoteGateway = remoteGateway;

  final BodyMetricDao _dao;
  final SyncRecordDao _syncRecordDao;
  final BodyMetricRemoteSyncGateway? _remoteGateway;

  @override
  Future<Result<List<domain.BodyMetric>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load body metrics: $e'));
    }
  }

  @override
  Future<Result<domain.BodyMetric?>> getLatest() async {
    try {
      final row = await _dao.getLatest();
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load latest body metric: $e'),
      );
    }
  }

  @override
  Future<Result<domain.BodyMetric?>> getLatestAtOrBefore(
    DateTime instant,
  ) async {
    try {
      final row = await _dao.getLatestAtOrBefore(instant);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load body metric at date: $e'),
      );
    }
  }

  @override
  Future<Result<int>> create(domain.BodyMetric metric) async {
    try {
      final id = await _dao.create(_toInsertCompanion(metric));
      final created = metric.copyWith(id: id);
      await _queueAndPush(created);
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create body metric: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.BodyMetric metric) async {
    try {
      await _dao.updateMetric(metric.id, _toUpdateCompanion(metric));
      await _queueAndPush(metric);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update body metric: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      final record = await _syncRecordDao.getByLocalId(
        tableName: _tableBodyMetrics,
        localId: id,
      );
      final local = await _dao.getById(id);
      final remoteId = record?.remoteId ?? local?.remoteId;

      if (remoteId != null) {
        await _deleteRemoteIfPossible(remoteId, record?.remoteUserId);
      }

      await _syncRecordDao.deleteByLocalId(
        tableName: _tableBodyMetrics,
        localId: id,
      );
      await _dao.deleteMetric(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete body metric: $e'));
    }
  }

  @override
  Future<Result<void>> reconcileOnAuth() async {
    try {
      final remoteGateway = _remoteGateway;
      final remoteUserId = remoteGateway?.currentUserId;
      if (remoteGateway == null || remoteUserId == null) {
        return const Success(null);
      }

      final remoteMetrics = await remoteGateway.fetchAllForCurrentUser();
      final localRows = await _dao.getAll();
      final records = await _syncRecordDao.listForTable(_tableBodyMetrics);
      final recordByLocalId = {
        for (final record in records) record.localId: record,
      };
      final recordBySyncId = {
        for (final record in records) record.syncId: record,
      };

      for (final remote in remoteMetrics) {
        final remoteId = remote.remoteId;
        if (remoteId == null) continue;

        final record = recordBySyncId[remoteId];
        if (record != null) {
          final local = localRows.cast<BodyMetric?>().firstWhere(
            (row) => row?.id == record.localId,
            orElse: () => null,
          );
          if (local == null) continue;
          _assertRecordBelongsToSession(record, remoteUserId);
          final localMetric = _toDomain(local);
          if (_remoteIsNewer(localMetric, remote)) {
            await _updateLocalFromRemote(local.id, remote, remoteUserId);
          } else {
            await _pushLocalMetric(localMetric, record: record);
          }
          continue;
        }

        final existingLocal = await _dao.getByRemoteId(remoteId);
        if (existingLocal != null) {
          await _syncRecordDao.upsertRecord(
            tableName: _tableBodyMetrics,
            localId: existingLocal.id,
            syncId: remoteId,
            remoteId: remoteId,
            remoteUserId: remoteUserId,
            status: 'synced',
          );
          final localMetric = _toDomain(existingLocal);
          if (_remoteIsNewer(localMetric, remote)) {
            await _updateLocalFromRemote(existingLocal.id, remote, remoteUserId);
          }
          continue;
        }

        await _insertLocalFromRemote(remote, remoteUserId);
      }

      for (final local in localRows) {
        final metric = _toDomain(local);
        final record = recordByLocalId[local.id];
        if (record != null) {
          _assertRecordBelongsToSession(record, remoteUserId);
          if (record.status == 'pending' || record.status == 'failed') {
            await _pushLocalMetric(metric, record: record);
          }
          continue;
        }

        await _queueAndPush(metric);
      }

      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to reconcile body metrics: $e'));
    }
  }

  @override
  Future<Result<void>> pushPendingLocalChanges() async {
    try {
      final remoteGateway = _remoteGateway;
      final remoteUserId = remoteGateway?.currentUserId;
      if (remoteGateway == null || remoteUserId == null) {
        return const Success(null);
      }

      final pending = await _syncRecordDao.listPendingOrFailed(_tableBodyMetrics);
      for (final record in pending) {
        _assertRecordBelongsToSession(record, remoteUserId);
        final localRows = await _dao.getAll();
        final local = localRows.cast<BodyMetric?>().firstWhere(
          (row) => row?.id == record.localId,
          orElse: () => null,
        );
        if (local == null) continue;
        await _pushLocalMetric(_toDomain(local), record: record);
      }

      final localRows = await _dao.getAll();
      final records = await _syncRecordDao.listForTable(_tableBodyMetrics);
      final mappedLocalIds = records.map((record) => record.localId).toSet();
      for (final local in localRows) {
        if (mappedLocalIds.contains(local.id)) continue;
        await _queueAndPush(_toDomain(local));
      }

      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to push pending body metrics: $e'),
      );
    }
  }

  Future<void> _queueAndPush(domain.BodyMetric metric) async {
    final remoteGateway = _remoteGateway;
    final remoteUserId = remoteGateway?.currentUserId;
    if (remoteGateway == null || remoteUserId == null) return;

    final existing = await _syncRecordDao.getByLocalId(
      tableName: _tableBodyMetrics,
      localId: metric.id,
    );
    final syncId = existing?.syncId ?? metric.remoteId ?? generateSyncUuid();
    await _syncRecordDao.upsertRecord(
      tableName: _tableBodyMetrics,
      localId: metric.id,
      syncId: syncId,
      remoteId: existing?.remoteId ?? metric.remoteId,
      remoteUserId: remoteUserId,
      status: 'pending',
    );
    final record = await _syncRecordDao.getByLocalId(
      tableName: _tableBodyMetrics,
      localId: metric.id,
    );
    if (record == null) return;
    await _pushLocalMetric(metric, record: record);
  }

  Future<void> _pushLocalMetric(
    domain.BodyMetric metric, {
    required SyncRecord record,
  }) async {
    final remoteGateway = _remoteGateway;
    final remoteUserId = remoteGateway?.currentUserId;
    if (remoteGateway == null || remoteUserId == null) return;

    _assertRecordBelongsToSession(record, remoteUserId);

    try {
      final remoteId = record.remoteId ?? record.syncId;
      final syncedAt = await remoteGateway.upsert(
        remoteId: remoteId,
        metric: metric,
      );
      await _dao.markSynced(
        id: metric.id,
        remoteId: remoteId,
        syncedAt: syncedAt,
      );
      await _syncRecordDao.upsertRecord(
        tableName: _tableBodyMetrics,
        localId: metric.id,
        syncId: record.syncId,
        remoteId: remoteId,
        remoteUserId: remoteUserId,
        status: 'synced',
      );
    } on Exception {
      await _syncRecordDao.upsertRecord(
        tableName: _tableBodyMetrics,
        localId: metric.id,
        syncId: record.syncId,
        remoteId: record.remoteId,
        remoteUserId: remoteUserId,
        status: 'failed',
      );
    }
  }

  Future<void> _deleteRemoteIfPossible(
    String remoteId,
    String? linkedUserId,
  ) async {
    final remoteGateway = _remoteGateway;
    final remoteUserId = remoteGateway?.currentUserId;
    if (remoteGateway == null || remoteUserId == null) return;
    if (linkedUserId != null && linkedUserId != remoteUserId) return;

    try {
      await remoteGateway.delete(remoteId);
    } on Exception {
      // Local-first: local delete should not be blocked by transient network issues.
    }
  }

  Future<void> _insertLocalFromRemote(
    domain.BodyMetric remote,
    String remoteUserId,
  ) async {
    final remoteId = remote.remoteId;
    if (remoteId == null) return;

    final id = await _dao.create(_toInsertCompanion(remote));
    final syncedAt = remote.lastSyncedAt ?? DateTime.now().toUtc();
    await _dao.markSynced(id: id, remoteId: remoteId, syncedAt: syncedAt);
    await _syncRecordDao.upsertRecord(
      tableName: _tableBodyMetrics,
      localId: id,
      syncId: remoteId,
      remoteId: remoteId,
      remoteUserId: remoteUserId,
      status: 'synced',
    );
  }

  Future<void> _updateLocalFromRemote(
    int localId,
    domain.BodyMetric remote,
    String remoteUserId,
  ) async {
    final remoteId = remote.remoteId;
    if (remoteId == null) return;

    final syncedAt = remote.lastSyncedAt ?? DateTime.now().toUtc();
    await _dao.updateMetric(
      localId,
      _toUpdateCompanion(
        remote.copyWith(
          id: localId,
          remoteId: () => remoteId,
          lastSyncedAt: () => syncedAt,
        ),
      ),
    );
    await _dao.markSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);
    await _syncRecordDao.upsertRecord(
      tableName: _tableBodyMetrics,
      localId: localId,
      syncId: remoteId,
      remoteId: remoteId,
      remoteUserId: remoteUserId,
      status: 'synced',
    );
  }

  void _assertRecordBelongsToSession(SyncRecord record, String remoteUserId) {
    if (record.remoteUserId != null && record.remoteUserId != remoteUserId) {
      throw const ValidationException(
        'Body metric is linked to a different account.',
      );
    }
  }

  bool _remoteIsNewer(domain.BodyMetric local, domain.BodyMetric remote) {
    final remoteAt = remote.lastSyncedAt;
    if (remoteAt == null) return false;

    final localAt = local.lastSyncedAt;
    if (localAt == null) return true;

    return remoteAt.isAfter(localAt);
  }

  BodyMetricsCompanion _toInsertCompanion(domain.BodyMetric metric) =>
      BodyMetricsCompanion.insert(
        weight: metric.weight,
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
        remoteId: Value(metric.remoteId),
        lastSyncedAt: Value(metric.lastSyncedAt),
      );

  BodyMetricsCompanion _toUpdateCompanion(domain.BodyMetric metric) =>
      BodyMetricsCompanion(
        weight: Value(metric.weight),
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
        remoteId: Value(metric.remoteId),
        lastSyncedAt: Value(metric.lastSyncedAt),
      );

  domain.BodyMetric _toDomain(BodyMetric row) => domain.BodyMetric(
    id: row.id,
    weight: row.weight,
    bodyFatPercent: row.bodyFatPercent,
    recordedAt: row.recordedAt,
    remoteId: row.remoteId,
    lastSyncedAt: row.lastSyncedAt,
  );
}
