import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_adapter.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../datasources/body_metric_remote_sync_gateway.dart';
import '../datasources/daos/body_metric_dao.dart';

class BodyMetricSyncAdapter implements SyncAdapter<domain.BodyMetric> {
  BodyMetricSyncAdapter({
    required BodyMetricDao dao,
    required BodyMetricRemoteSyncGateway remote,
    required String userId,
  })  : _dao = dao,
        _remote = remote,
        _userId = userId;

  final BodyMetricDao _dao;
  final BodyMetricRemoteSyncGateway _remote;
  final String _userId;

  @override
  String get tableName => 'body_metrics';

  @override
  String getId(domain.BodyMetric row) => row.id;

  @override
  Future<List<domain.BodyMetric>> loadDirty() async {
    final rows = await _dao.getDirty(_userId);
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<domain.BodyMetric>> loadDirtyTombstones() async {
    final rows = await _dao.getDirtyTombstones(_userId);
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> pushToRemote(List<domain.BodyMetric> rows) async {
    for (final metric in rows) {
      await _remote.upsert(id: metric.id, metric: metric);
    }
  }

  @override
  Future<void> pushDeletes(List<domain.BodyMetric> rows) async {
    for (final metric in rows) {
      await _remote.delete(metric.id);
    }
  }

  @override
  Future<List<domain.BodyMetric>> pullFromRemote(DateTime lastPullAt) =>
      _remote.fetchUpdatedSince(lastPullAt);

  @override
  Future<void> applyRemoteRows(List<domain.BodyMetric> rows) async {
    for (final metric in rows) {
      final local = await _dao.getById(metric.id);
      if (local != null && local.isDirty) continue;

      await _dao.upsertFromRemote(
        BodyMetricsCompanion.insert(
          id: metric.id,
          userId: _userId,
          weight: metric.weight,
          bodyFatPercent: Value(metric.bodyFatPercent),
          recordedAt: Value(metric.recordedAt),
          isDirty: const Value(false),
        ),
      );
    }
  }

  @override
  Future<void> markClean(List<String> ids) async {
    for (final id in ids) {
      await _dao.markClean(id);
    }
  }

  @override
  Future<void> hardDelete(List<String> ids) async {
    for (final id in ids) {
      await _dao.hardDelete(id);
    }
  }

  domain.BodyMetric _toDomain(BodyMetric row) => domain.BodyMetric(
    id: row.id,
    weight: row.weight,
    bodyFatPercent: row.bodyFatPercent,
    recordedAt: row.recordedAt,
  );
}
