import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/entities/body_metric.dart' as domain;
import '../datasources/body_metric_remote_sync_gateway.dart';
import '../datasources/daos/body_metric_dao.dart';

const bodyMetricsSyncTableName = 'body_metrics';

class BodyMetricSyncAdapter implements UserOwnedCollectionSyncAdapter<domain.BodyMetric> {
  BodyMetricSyncAdapter(this._dao, {BodyMetricRemoteSyncGateway? remoteGateway})
    : _remoteGateway = remoteGateway;

  final BodyMetricDao _dao;
  final BodyMetricRemoteSyncGateway? _remoteGateway;

  @override
  String get tableName => bodyMetricsSyncTableName;

  @override
  String? get currentRemoteUserId => _remoteGateway?.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<domain.BodyMetric>>> loadLocalRows() async {
    final rows = await _dao.getAll();
    return rows.map(_toLocalRow).toList(growable: false);
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<domain.BodyMetric>>> fetchRemoteRows() async {
    final gateway = _remoteGateway;
    if (gateway == null) return const [];

    final metrics = await gateway.fetchAllForCurrentUser();
    return metrics
        .where((metric) => metric.remoteId != null)
        .map(
          (metric) => UserOwnedSyncRemoteRow(
            remoteId: metric.remoteId!,
            entity: metric,
            remoteUpdatedAt: metric.lastSyncedAt ?? DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<domain.BodyMetric> remote,
    String remoteUserId,
  ) async {
    final id = await _dao.create(_toInsertCompanion(remote.entity));
    final syncedAt = remote.remoteUpdatedAt;
    await _dao.updateMetric(
      id,
      BodyMetricsCompanion(localUpdatedAt: Value(syncedAt)),
    );
    await _dao.markSynced(id: id, remoteId: remote.remoteId, syncedAt: syncedAt);
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<domain.BodyMetric> remote,
    String remoteUserId,
  ) async {
    final syncedAt = remote.remoteUpdatedAt;
    await _dao.updateMetric(
      localId,
      _toUpdateCompanion(
        remote.entity.copyWith(
          id: localId,
          remoteId: () => remote.remoteId,
          lastSyncedAt: () => syncedAt,
          localUpdatedAt: () => syncedAt,
        ),
      ),
    );
    await _dao.markSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: syncedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required domain.BodyMetric entity,
    required String remoteId,
  }) async {
    final gateway = _remoteGateway;
    if (gateway == null) {
      throw StateError('Remote gateway is not configured.');
    }

    return gateway.upsert(remoteId: remoteId, metric: entity);
  }

  @override
  Future<void> pushDelete(String remoteId) async {
    final gateway = _remoteGateway;
    if (gateway == null) return;
    await gateway.delete(remoteId);
  }

  @override
  Future<void> markLocalSynced({
    required int localId,
    required String remoteId,
    required DateTime syncedAt,
    required String remoteUserId,
  }) =>
      _dao.markSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);

  @override
  Future<void> markLocalDirty(int localId) => _dao.markLocalDirty(localId);

  @override
  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  }) =>
      existingSyncId ?? entityRemoteId ?? generateSyncUuid();

  UserOwnedSyncLocalRow<domain.BodyMetric> _toLocalRow(BodyMetric row) =>
      UserOwnedSyncLocalRow(
        localId: row.id,
        entity: _toDomain(row),
        remoteId: row.remoteId,
        localUpdatedAt: row.localUpdatedAt,
        lastSyncedAt: row.lastSyncedAt,
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

  BodyMetricsCompanion _toInsertCompanion(domain.BodyMetric metric) =>
      BodyMetricsCompanion.insert(
        weight: metric.weight,
        bodyFatPercent: Value(metric.bodyFatPercent),
        recordedAt: Value(metric.recordedAt),
        remoteId: Value(metric.remoteId),
        lastSyncedAt: Value(metric.lastSyncedAt),
        localUpdatedAt: Value(metric.localUpdatedAt ?? DateTime.now().toUtc()),
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
}
