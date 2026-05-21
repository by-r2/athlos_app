import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/body_metrics_table.dart';

part 'body_metric_dao.g.dart';

@DriftAccessor(tables: [BodyMetrics])
class BodyMetricDao extends DatabaseAccessor<AppDatabase>
    with _$BodyMetricDaoMixin {
  BodyMetricDao(super.db);

  Expression<bool> _notDeleted($BodyMetricsTable m) => m.deletedAt.isNull();

  Future<List<BodyMetric>> getAll(String userId) => (select(bodyMetrics)
        ..where((m) => m.userId.equals(userId) & _notDeleted(m))
        ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)]))
      .get();

  Future<BodyMetric?> getLatest(String userId) => (select(bodyMetrics)
        ..where((m) => m.userId.equals(userId) & _notDeleted(m))
        ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<BodyMetric?> getLatestAtOrBefore(String userId, DateTime instant) =>
      (select(bodyMetrics)
            ..where((m) =>
                m.userId.equals(userId) &
                _notDeleted(m) &
                m.recordedAt.isSmallerOrEqualValue(instant))
            ..orderBy([(m) => OrderingTerm.desc(m.recordedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<BodyMetric?> getById(String id) =>
      (select(bodyMetrics)..where((m) => m.id.equals(id) & _notDeleted(m)))
          .getSingleOrNull();

  Future<void> create(BodyMetricsCompanion entry) =>
      into(bodyMetrics).insert(entry);

  Future<void> upsertFromRemote(BodyMetricsCompanion entry) =>
      into(bodyMetrics).insertOnConflictUpdate(entry);

  Future<void> updateMetric(String id, BodyMetricsCompanion entry) {
    final now = DateTime.now().toUtc();
    return (update(bodyMetrics)..where((m) => m.id.equals(id))).write(
      entry.copyWith(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteMetric(String id) {
    final now = DateTime.now().toUtc();
    return (update(bodyMetrics)..where((m) => m.id.equals(id))).write(
      BodyMetricsCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> hardDelete(String id) =>
      (delete(bodyMetrics)..where((m) => m.id.equals(id))).go();

  Future<List<BodyMetric>> getDirty(String userId) => (select(bodyMetrics)
        ..where(
          (m) =>
              m.userId.equals(userId) &
              m.isDirty.equals(true) &
              m.deletedAt.isNull(),
        ))
      .get();

  Future<List<BodyMetric>> getDirtyTombstones(String userId) =>
      (select(bodyMetrics)
            ..where(
              (m) =>
                  m.userId.equals(userId) &
                  m.isDirty.equals(true) &
                  m.deletedAt.isNotNull(),
            ))
          .get();

  Future<void> markClean(String id) =>
      (update(bodyMetrics)..where((m) => m.id.equals(id)))
          .write(const BodyMetricsCompanion(isDirty: Value(false)));
}
