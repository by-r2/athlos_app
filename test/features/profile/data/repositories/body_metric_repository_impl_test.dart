import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/database/daos/sync_record_dao.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/profile/data/datasources/body_metric_remote_sync_gateway.dart';
import 'package:athlos_app/features/profile/data/datasources/daos/body_metric_dao.dart';
import 'package:athlos_app/features/profile/data/repositories/body_metric_repository_impl.dart';
import 'package:athlos_app/features/profile/domain/entities/body_metric.dart'
    as domain;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BodyMetricRepositoryImpl', () {
    late AppDatabase db;
    late BodyMetricDao dao;
    late SyncRecordDao syncRecordDao;
    late _FakeRemoteGateway remote;
    late BodyMetricRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = BodyMetricDao(db);
      syncRecordDao = SyncRecordDao(db);
      remote = _FakeRemoteGateway();
      repository = BodyMetricRepositoryImpl(
        dao,
        syncRecordDao,
        remoteGateway: remote,
      );
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create persiste localmente sem sessao remota', () async {
      final id = (await repository.create(
        domain.BodyMetric(id: 0, weight: 80, recordedAt: DateTime.utc(2026, 5, 1)),
      )).getOrThrow();

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics, hasLength(1));
      expect(metrics.first.id, id);
      expect(remote.upserts, isEmpty);
    });

    test('create envia para remoto com sessao ativa', () async {
      remote.currentUserId = 'user-1';

      final id = (await repository.create(
        domain.BodyMetric(id: 0, weight: 81, recordedAt: DateTime.utc(2026, 5, 2)),
      )).getOrThrow();

      expect(remote.upserts, hasLength(1));
      expect(remote.upserts.first.weight, 81);

      final row = await dao.getById(id);
      expect(row?.remoteId, isNotEmpty);
      expect(row?.lastSyncedAt, isA<DateTime>());
    });

    test('reconcileOnAuth importa timeline remota sem dados locais', () async {
      remote.currentUserId = 'user-1';
      remote.metrics = [
        domain.BodyMetric(
          id: 0,
          weight: 79,
          bodyFatPercent: 14,
          recordedAt: DateTime.utc(2026, 5, 3),
          remoteId: 'remote-1',
          lastSyncedAt: DateTime.utc(2026, 5, 3, 12),
        ),
      ];

      await repository.reconcileOnAuth();

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics, hasLength(1));
      expect(metrics.first.weight, 79);
      expect(metrics.first.bodyFatPercent, 14);
      expect(metrics.first.remoteId, 'remote-1');
    });

    test('reconcileOnAuth aplica LWW remoto mais novo', () async {
      remote.currentUserId = 'user-1';
      final localId = await dao.create(
        BodyMetricsCompanion.insert(
          weight: 80,
          recordedAt: Value(DateTime.utc(2026, 5, 4)),
          remoteId: const Value('remote-1'),
          lastSyncedAt: Value(DateTime.utc(2026, 5, 4, 8)),
        ),
      );
      await syncRecordDao.upsertRecord(
        tableName: 'body_metrics',
        localId: localId,
        syncId: 'remote-1',
        remoteId: 'remote-1',
        remoteUserId: 'user-1',
        status: 'synced',
      );

      remote.metrics = [
        domain.BodyMetric(
          id: 0,
          weight: 82,
          recordedAt: DateTime.utc(2026, 5, 4),
          remoteId: 'remote-1',
          lastSyncedAt: DateTime.utc(2026, 5, 4, 12),
        ),
      ];

      await repository.reconcileOnAuth();

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics.first.weight, 82);
    });

    test('delete remove entrada remota mapeada', () async {
      remote.currentUserId = 'user-1';
      final localId = (await repository.create(
        domain.BodyMetric(id: 0, weight: 83, recordedAt: DateTime.utc(2026, 5, 5)),
      )).getOrThrow();
      final row = await dao.getById(localId);
      final remoteId = row!.remoteId!;

      await repository.delete(localId);

      expect(remote.deletedIds, contains(remoteId));
      expect((await repository.getAll()).getOrThrow(), isEmpty);
    });

    test('reconcileOnAuth falha quando mapeamento pertence a outra conta', () async {
      remote.currentUserId = 'user-2';
      final localId = (await repository.create(
        domain.BodyMetric(id: 0, weight: 84, recordedAt: DateTime.utc(2026, 5, 6)),
      )).getOrThrow();
      await syncRecordDao.upsertRecord(
        tableName: 'body_metrics',
        localId: localId,
        syncId: 'remote-2',
        remoteId: 'remote-2',
        remoteUserId: 'user-1',
        status: 'synced',
      );

      final result = await repository.reconcileOnAuth();

      expect(result.isFailure, isTrue);
    });

    test('pushPendingLocalChanges reenvia apos falha remota', () async {
      remote.currentUserId = 'user-1';
      remote.failNextUpsert = true;

      final localId = (await repository.create(
        domain.BodyMetric(id: 0, weight: 85, recordedAt: DateTime.utc(2026, 5, 7)),
      )).getOrThrow();

      final record = await syncRecordDao.getByLocalId(
        tableName: 'body_metrics',
        localId: localId,
      );
      expect(record?.status, 'failed');

      remote.failNextUpsert = false;
      await repository.pushPendingLocalChanges();

      final updated = await syncRecordDao.getByLocalId(
        tableName: 'body_metrics',
        localId: localId,
      );
      expect(updated?.status, 'synced');
      expect(remote.upserts, hasLength(1));
    });
  });
}

class _FakeRemoteGateway implements BodyMetricRemoteSyncGateway {
  String? currentUserId;
  List<domain.BodyMetric> metrics = [];
  final List<domain.BodyMetric> upserts = [];
  final List<String> deletedIds = [];
  bool failNextUpsert = false;

  @override
  Future<void> delete(String remoteId) async {
    deletedIds.add(remoteId);
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
    if (failNextUpsert) {
      failNextUpsert = false;
      throw Exception('network');
    }
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
