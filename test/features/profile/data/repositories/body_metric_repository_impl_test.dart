import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/user_owned_sync_runner.dart';
import 'package:athlos_app/features/profile/data/datasources/daos/body_metric_dao.dart';
import 'package:athlos_app/features/profile/data/repositories/body_metric_repository_impl.dart';
import 'package:athlos_app/features/profile/domain/entities/body_metric.dart'
    as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BodyMetricRepositoryImpl', () {
    late AppDatabase db;
    late BodyMetricDao dao;
    late BodyMetricRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = BodyMetricDao(db);
      repository = BodyMetricRepositoryImpl(
        dao,
        UserOwnedSyncRunner.disabled(),
        'test-user',
      );
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create persiste localmente', () async {
      final id = (await repository.create(
        domain.BodyMetric(
          id: '',
          weight: 80,
          recordedAt: DateTime.utc(2026, 5, 1),
        ),
      )).getOrThrow();

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics, hasLength(1));
      expect(metrics.first.id, id);
    });

    test('getAll retorna em ordem decrescente', () async {
      await repository.create(
        domain.BodyMetric(
          id: '',
          weight: 80,
          recordedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      await repository.create(
        domain.BodyMetric(
          id: '',
          weight: 81,
          recordedAt: DateTime.utc(2026, 5, 2),
        ),
      );

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics, hasLength(2));
      expect(metrics.first.weight, 81);
      expect(metrics.last.weight, 80);
    });

    test('update altera peso', () async {
      final id = (await repository.create(
        domain.BodyMetric(
          id: '',
          weight: 80,
          recordedAt: DateTime.utc(2026, 5, 1),
        ),
      )).getOrThrow();

      await repository.update(
        domain.BodyMetric(
          id: id,
          weight: 82,
          recordedAt: DateTime.utc(2026, 5, 1),
        ),
      );

      final metrics = (await repository.getAll()).getOrThrow();
      expect(metrics.first.weight, 82);
    });

    test('delete remove entrada', () async {
      final id = (await repository.create(
        domain.BodyMetric(
          id: '',
          weight: 83,
          recordedAt: DateTime.utc(2026, 5, 5),
        ),
      )).getOrThrow();

      await repository.delete(id);

      expect((await repository.getAll()).getOrThrow(), isEmpty);
    });
  });
}
