import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/sync_record_store.dart';
import '../../../../core/sync/user_owned_collection_sync_engine.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../../domain/repositories/body_metric_repository.dart';
import '../datasources/daos/body_metric_dao.dart';
import '../sync/body_metric_sync_adapter.dart';

class BodyMetricRepositoryImpl implements BodyMetricRepository {
  BodyMetricRepositoryImpl(
    this._dao,
    this._syncStore,
    this._syncEngine,
  );

  final BodyMetricDao _dao;
  final SyncRecordStore _syncStore;
  final UserOwnedCollectionSyncEngine _syncEngine;

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
      final now = DateTime.now().toUtc();
      final id = await _dao.create(
        _toInsertCompanion(
          metric.copyWith(localUpdatedAt: () => now),
        ),
      );
      await _syncEngine.synchronizeAfterMutation(id);
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create body metric: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.BodyMetric metric) async {
    try {
      final now = DateTime.now().toUtc();
      await _dao.updateMetric(
        metric.id,
        _toUpdateCompanion(metric.copyWith(localUpdatedAt: () => now)),
      );
      await _syncEngine.synchronizeAfterMutation(metric.id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update body metric: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      final record = await _syncStore.getByLocalId(
        tableName: bodyMetricsSyncTableName,
        localId: id,
      );
      final local = await _dao.getById(id);
      final remoteId = record?.remoteId ?? local?.remoteId;
      final syncId = record?.syncId ?? remoteId ?? generateSyncUuid();

      if (remoteId != null || record != null) {
        await _syncStore.markTombstone(
          tableName: bodyMetricsSyncTableName,
          localId: id,
          syncId: syncId,
          remoteId: remoteId,
          remoteUserId: record?.remoteUserId,
        );
      }

      await _dao.deleteMetric(id);
      await _syncEngine.synchronize();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete body metric: $e'));
    }
  }

  @override
  Future<Result<void>> reconcileOnAuth() async {
    try {
      await _syncEngine.synchronize();
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
      await _syncEngine.synchronize();
      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to push pending body metrics: $e'),
      );
    }
  }

  BodyMetricsCompanion _toInsertCompanion(domain.BodyMetric metric) =>
      BodyMetricsCompanion.insert(
        weight: metric.weight,
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
        remoteId: Value(metric.remoteId),
        lastSyncedAt: Value(metric.lastSyncedAt),
        localUpdatedAt: Value(metric.localUpdatedAt),
      );

  BodyMetricsCompanion _toUpdateCompanion(domain.BodyMetric metric) =>
      BodyMetricsCompanion(
        weight: Value(metric.weight),
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
        remoteId: Value(metric.remoteId),
        lastSyncedAt: Value(metric.lastSyncedAt),
        localUpdatedAt: Value(metric.localUpdatedAt),
      );

  domain.BodyMetric _toDomain(BodyMetric row) => domain.BodyMetric(
    id: row.id,
    weight: row.weight,
    bodyFatPercent: row.bodyFatPercent,
    recordedAt: row.recordedAt,
    remoteId: row.remoteId,
    lastSyncedAt: row.lastSyncedAt,
    localUpdatedAt: row.localUpdatedAt,
  );
}
