import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/profile/data/datasources/daos/user_profile_dao.dart';
import 'package:athlos_app/features/profile/data/datasources/user_profile_remote_sync_gateway.dart';
import 'package:athlos_app/features/profile/data/repositories/user_profile_repository_impl.dart';
import 'package:athlos_app/features/profile/domain/entities/user_profile.dart'
    as domain;
import 'package:athlos_app/features/profile/domain/enums/selected_module.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileRepositoryImpl', () {
    late AppDatabase db;
    late UserProfileDao dao;
    late _FakeRemoteGateway remote;
    late UserProfileRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = UserProfileDao(db);
      remote = _FakeRemoteGateway();
      repository = UserProfileRepositoryImpl(dao, remoteDataSource: remote);
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create/get/hasProfile fluxo basico', () async {
      final createResult = await repository.create(
        const domain.UserProfile(
          id: 0,
          name: 'Rafa',
          height: 181,
          age: 24,
          lastActiveModule: AppModule.training,
        ),
      );
      final createdId = createResult.getOrThrow();

      expect(createdId, greaterThan(0));
      expect((await repository.hasProfile()).getOrThrow(), isTrue);

      final loaded = (await repository.get()).getOrThrow();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Rafa');
      expect(loaded.height, 181);
    });

    test('update altera campos esperados', () async {
      final createdId = (await repository.create(
        const domain.UserProfile(
          id: 0,
          name: 'Antes',
          height: 180,
          age: 20,
          lastActiveModule: AppModule.training,
        ),
      )).getOrThrow();

      final updateResult = await repository.update(
        const domain.UserProfile(
          id: 0,
          name: 'Depois',
          height: 180,
          age: 20,
          lastActiveModule: AppModule.diet,
        ).copyWith(id: createdId),
      );
      expect(updateResult.isSuccess, isTrue);

      final loaded = (await repository.get()).getOrThrow()!;
      expect(loaded.name, 'Depois');
      expect(loaded.lastActiveModule, AppModule.diet);
    });

    test('pull remoto preserva streaks quando nao ha perfil local', () async {
      remote.currentUserId = 'user-1';
      remote.profile = domain.UserProfile(
        id: 0,
        name: 'Remoto',
        currentCycleStreak: 4,
        bestCycleStreak: 7,
        currentFrequencyStreak: 2,
        bestFrequencyStreak: 5,
        trainingStreaksSchema: 2,
        lastActiveModule: AppModule.training,
        remoteUserId: 'user-1',
        lastSyncedAt: DateTime.utc(2026, 5, 10, 12),
      );

      final loaded = (await repository.get()).getOrThrow()!;

      expect(loaded.name, 'Remoto');
      expect(loaded.currentCycleStreak, 4);
      expect(loaded.bestCycleStreak, 7);
      expect(loaded.currentFrequencyStreak, 2);
      expect(loaded.bestFrequencyStreak, 5);
      expect(loaded.trainingStreaksSchema, 2);
      expect(loaded.remoteUserId, 'user-1');
    });

    test('reconcileOnAuth puxa remoto mais novo', () async {
      remote.currentUserId = 'user-1';
      final localId = (await repository.create(
        const domain.UserProfile(
          id: 0,
          name: 'Local',
          lastActiveModule: AppModule.training,
        ),
      )).getOrThrow();
      await dao.markSynced(
        id: localId,
        remoteUserId: 'user-1',
        syncedAt: DateTime.utc(2026, 5, 10, 12),
      );

      remote.profile = domain.UserProfile(
        id: 0,
        name: 'Nuvem',
        currentCycleStreak: 3,
        bestCycleStreak: 3,
        currentFrequencyStreak: 1,
        bestFrequencyStreak: 1,
        trainingStreaksSchema: 2,
        lastActiveModule: AppModule.training,
        remoteUserId: 'user-1',
        lastSyncedAt: DateTime.utc(2026, 5, 12, 12),
      );

      final reconciled = (await repository.reconcileOnAuth()).getOrThrow()!;

      expect(reconciled.name, 'Nuvem');
      expect(reconciled.currentCycleStreak, 3);
      expect(reconciled.trainingStreaksSchema, 2);
    });

    test('reconcileOnAuth envia local mais novo para remoto', () async {
      remote.currentUserId = 'user-1';
      final localId = (await repository.create(
        const domain.UserProfile(
          id: 0,
          name: 'Local novo',
          lastActiveModule: AppModule.training,
        ),
      )).getOrThrow();
      await dao.markSynced(
        id: localId,
        remoteUserId: 'user-1',
        syncedAt: DateTime.utc(2026, 5, 12, 12),
      );

      remote.profile = domain.UserProfile(
        id: 0,
        name: 'Nuvem antigo',
        lastActiveModule: AppModule.training,
        remoteUserId: 'user-1',
        lastSyncedAt: DateTime.utc(2026, 5, 10, 12),
      );

      await repository.reconcileOnAuth();

      expect(remote.lastUpserted?.name, 'Local novo');
    });

    test('reconcileOnAuth falha quando perfil pertence a outra conta', () async {
      remote.currentUserId = 'user-2';
      final localId = (await repository.create(
        const domain.UserProfile(
          id: 0,
          name: 'Local',
          lastActiveModule: AppModule.training,
          remoteUserId: 'user-1',
        ),
      )).getOrThrow();
      await dao.markSynced(
        id: localId,
        remoteUserId: 'user-1',
        syncedAt: DateTime.utc(2026, 5, 10, 12),
      );

      final result = await repository.reconcileOnAuth();

      expect(result.isFailure, isTrue);
    });
  });
}

class _FakeRemoteGateway implements UserProfileRemoteSyncGateway {
  String? currentUserId;
  domain.UserProfile? profile;
  domain.UserProfile? lastUpserted;

  @override
  Future<domain.UserProfile?> fetchCurrentProfile() async => profile;

  @override
  Future<DateTime> upsertCurrentProfile(domain.UserProfile profile) async {
    lastUpserted = profile;
    final syncedAt = DateTime.now().toUtc();
    this.profile = profile.copyWith(lastSyncedAt: () => syncedAt);
    return syncedAt;
  }
}
