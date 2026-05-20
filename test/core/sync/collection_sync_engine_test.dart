import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/database/daos/sync_record_dao.dart';
import 'package:athlos_app/core/sync/sync_record_store.dart';
import 'package:athlos_app/core/sync/user_owned_collection_sync_engine.dart';
import 'package:athlos_app/features/profile/data/datasources/body_metric_remote_sync_gateway.dart';
import 'package:athlos_app/features/profile/data/datasources/daos/body_metric_dao.dart';
import 'package:athlos_app/features/profile/data/sync/body_metric_sync_adapter.dart';
import 'package:athlos_app/features/profile/domain/entities/body_metric.dart'
    as domain;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserOwnedCollectionSyncEngine body metrics', () {
    late AppDatabase db;
    late BodyMetricDao dao;
    late SyncRecordStore store;
    late _FakeRemoteGateway remote;
    late UserOwnedCollectionSyncEngine<domain.BodyMetric> engine;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = BodyMetricDao(db);
      store = SyncRecordStore(SyncRecordDao(db));
      remote = _FakeRemoteGateway();
      engine = UserOwnedCollectionSyncEngine(
        adapter: BodyMetricSyncAdapter(dao, remoteGateway: remote),
        store: store,
      );
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('edicao local com remote_id existente mantem uma unica linha', () async {
      remote.currentUserId = 'user-1';
      final localId = await dao.create(
        BodyMetricsCompanion.insert(
          weight: 71.6,
          recordedAt: Value(DateTime.utc(2026, 5, 13)),
          remoteId: const Value('metric-1'),
          lastSyncedAt: Value(DateTime.utc(2026, 5, 13, 8)),
          localUpdatedAt: Value(DateTime.utc(2026, 5, 13, 8)),
        ),
      );
      await store.upsert(
        tableName: 'body_metrics',
        localId: localId,
        syncId: 'metric-1',
        remoteId: 'metric-1',
        remoteUserId: 'user-1',
        status: 'synced',
      );

      await dao.updateMetric(
        localId,
        BodyMetricsCompanion(
          weight: const Value(71.7),
          localUpdatedAt: Value(DateTime.utc(2026, 5, 13, 9)),
        ),
      );

      await engine.synchronize();

      final rows = await dao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.weight, 71.7);
      expect(rows.first.remoteId, 'metric-1');
      expect(remote.upserts, hasLength(1));
      expect(remote.upserts.first.weight, 71.7);
    });

    test('reconcile repara sync_record ausente sem duplicar linha local', () async {
      remote.currentUserId = 'user-1';
      final localId = await dao.create(
        BodyMetricsCompanion.insert(
          weight: 71.6,
          recordedAt: Value(DateTime.utc(2026, 5, 13)),
          remoteId: const Value('metric-1'),
          lastSyncedAt: Value(DateTime.utc(2026, 5, 13, 8)),
          localUpdatedAt: Value(DateTime.utc(2026, 5, 13, 8)),
        ),
      );

      remote.metrics = [
        domain.BodyMetric(
          id: 0,
          weight: 71.6,
          recordedAt: DateTime.utc(2026, 5, 13),
          remoteId: 'metric-1',
          lastSyncedAt: DateTime.utc(2026, 5, 13, 8),
        ),
      ];

      await engine.synchronize();

      final rows = await dao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.id, localId);

      final record = await store.getByLocalId(
        tableName: 'body_metrics',
        localId: localId,
      );
      expect(record?.remoteId, 'metric-1');
    });

    test('remoto mais novo atualiza linha local in place', () async {
      remote.currentUserId = 'user-1';
      final localId = await dao.create(
        BodyMetricsCompanion.insert(
          weight: 71.6,
          recordedAt: Value(DateTime.utc(2026, 5, 13)),
          remoteId: const Value('metric-1'),
          lastSyncedAt: Value(DateTime.utc(2026, 5, 13, 8)),
          localUpdatedAt: Value(DateTime.utc(2026, 5, 13, 8)),
        ),
      );
      await store.upsert(
        tableName: 'body_metrics',
        localId: localId,
        syncId: 'metric-1',
        remoteId: 'metric-1',
        remoteUserId: 'user-1',
        status: 'synced',
      );

      remote.metrics = [
        domain.BodyMetric(
          id: 0,
          weight: 71.7,
          recordedAt: DateTime.utc(2026, 5, 13),
          remoteId: 'metric-1',
          lastSyncedAt: DateTime.utc(2026, 5, 13, 12),
        ),
      ];

      await engine.synchronize();

      final rows = await dao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.weight, 71.7);
      expect(remote.upserts, isEmpty);
    });
  });
}

class _FakeRemoteGateway implements BodyMetricRemoteSyncGateway {
  String? currentUserId;
  List<domain.BodyMetric> metrics = [];
  final List<domain.BodyMetric> upserts = [];

  @override
  Future<void> delete(String remoteId) async {
    metrics.removeWhere((metric) => metric.remoteId == remoteId);
  }

  @override
  Future<List<domain.BodyMetric>> fetchAllForCurrentUser() async =>
      List<domain.BodyMetric>.from(metrics);

  @override
  Future<DateTime> upsert({
    required String remoteId,
    required domain.BodyMetric metric,
  }) async {
    upserts.add(metric);
    final syncedAt = DateTime.now().toUtc();
    metrics.removeWhere((entry) => entry.remoteId == remoteId);
    metrics.add(
      metric.copyWith(
        remoteId: () => remoteId,
        lastSyncedAt: () => syncedAt,
      ),
    );
    return syncedAt;
  }
}
