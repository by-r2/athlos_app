import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/body_metrics_table.dart';

part 'body_metric_dao.g.dart';

@DriftAccessor(tables: [BodyMetrics])
class BodyMetricDao extends DatabaseAccessor<AppDatabase>
    with _$BodyMetricDaoMixin {
  BodyMetricDao(super.db);

  Future<List<BodyMetric>> getAll() => (select(
    bodyMetrics,
  )..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])).get();

  Future<BodyMetric?> getLatest() =>
      (select(bodyMetrics)
            ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Most recent entry with [recordedAt] on or before [instant] (inclusive).
  Future<BodyMetric?> getLatestAtOrBefore(DateTime instant) =>
      (select(bodyMetrics)
            ..where((m) => m.recordedAt.isSmallerOrEqualValue(instant))
            ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<BodyMetric?> getById(int id) =>
      (select(bodyMetrics)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> create(BodyMetricsCompanion entry) =>
      into(bodyMetrics).insert(entry);

  Future<void> updateMetric(int id, BodyMetricsCompanion entry) =>
      (update(bodyMetrics)..where((m) => m.id.equals(id))).write(entry);

  Future<void> deleteMetric(int id) =>
      (delete(bodyMetrics)..where((m) => m.id.equals(id))).go();

  Future<void> markSynced({
    required int id,
    required String remoteId,
    required DateTime syncedAt,
  }) => (update(bodyMetrics)..where((m) => m.id.equals(id))).write(
    BodyMetricsCompanion(
      remoteId: Value(remoteId),
      lastSyncedAt: Value(syncedAt),
    ),
  );

  Future<void> markLocalDirty(int id) {
    final now = DateTime.now().toUtc();
    return (update(bodyMetrics)..where((m) => m.id.equals(id))).write(
      BodyMetricsCompanion(localUpdatedAt: Value(now)),
    );
  }

  Future<BodyMetric?> getByRemoteId(String remoteId) =>
      (select(bodyMetrics)..where((m) => m.remoteId.equals(remoteId)))
          .getSingleOrNull();
}
