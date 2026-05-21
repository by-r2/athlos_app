import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/sync_trigger.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../../domain/repositories/body_metric_repository.dart';
import '../datasources/daos/body_metric_dao.dart';

class BodyMetricRepositoryImpl implements BodyMetricRepository {
  BodyMetricRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final BodyMetricDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  @override
  Future<Result<List<domain.BodyMetric>>> getAll() async {
    try {
      final rows = await _dao.getAll(_userId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load body metrics: $e'));
    }
  }

  @override
  Future<Result<domain.BodyMetric?>> getLatest() async {
    try {
      final row = await _dao.getLatest(_userId);
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
      final row = await _dao.getLatestAtOrBefore(_userId, instant);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load body metric at date: $e'),
      );
    }
  }

  @override
  Future<Result<String>> create(domain.BodyMetric metric) async {
    try {
      final id = metric.id.isNotEmpty ? metric.id : AppDatabase.uuid4();
      await _dao.create(
        BodyMetricsCompanion.insert(
          id: id,
          userId: _userId,
          weight: metric.weight,
          bodyFatPercent: Value(metric.bodyFatPercent),
          recordedAt: Value(metric.recordedAt),
          isDirty: const Value(true),
        ),
      );
      await _syncRunner.synchronizeTable('body_metrics');
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create body metric: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.BodyMetric metric) async {
    try {
      await _dao.updateMetric(
        metric.id,
        BodyMetricsCompanion(
          weight: Value(metric.weight),
          bodyFatPercent: Value(metric.bodyFatPercent),
          recordedAt: Value(metric.recordedAt),
        ),
      );
      await _syncRunner.synchronizeTable('body_metrics');
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update body metric: $e'));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _dao.deleteMetric(id);
      await _syncRunner.synchronizeTable('body_metrics');
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete body metric: $e'));
    }
  }

  @override
  Future<Result<void>> reconcileOnAuth() async {
    try {
      await _syncRunner.synchronizeAuthenticatedUserData(
        trigger: SyncTrigger.sessionChange,
      );
      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to reconcile body metrics: $e'),
      );
    }
  }

  @override
  Future<Result<void>> pushPendingLocalChanges() async {
    try {
      await _syncRunner.synchronizeAuthenticatedUserData(
        trigger: SyncTrigger.mutation,
      );
      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to push pending body metrics: $e'),
      );
    }
  }

  domain.BodyMetric _toDomain(BodyMetric row) => domain.BodyMetric(
    id: row.id,
    weight: row.weight,
    bodyFatPercent: row.bodyFatPercent,
    recordedAt: row.recordedAt,
  );
}
