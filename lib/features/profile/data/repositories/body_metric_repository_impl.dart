import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../../domain/repositories/body_metric_repository.dart';
import '../datasources/daos/body_metric_dao.dart';

class BodyMetricRepositoryImpl implements BodyMetricRepository {
  BodyMetricRepositoryImpl(this._dao);

  final BodyMetricDao _dao;

  @override
  Future<Result<List<domain.BodyMetric>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load body metrics: $e'));
    }
  }

  @override
  Future<Result<domain.BodyMetric?>> getLatest() async {
    try {
      final row = await _dao.getLatest();
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load latest body metric: $e'));
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
          DatabaseException('Failed to load body metric at date: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.BodyMetric metric) async {
    try {
      final id = await _dao.create(BodyMetricsCompanion.insert(
        weight: metric.weight,
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
      ));
      return Success(id);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to create body metric: $e'));
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
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to update body metric: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _dao.deleteMetric(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to delete body metric: $e'));
    }
  }

  domain.BodyMetric _toDomain(BodyMetric row) => domain.BodyMetric(
        id: row.id,
        weight: row.weight,
        bodyFatPercent: row.bodyFatPercent,
        recordedAt: row.recordedAt,
      );
}
