import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/user_owned_sync_runner.dart';
import 'package:athlos_app/core/utils/uuid.dart';
import 'package:athlos_app/features/profile/data/datasources/daos/user_profile_dao.dart';
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
    late UserProfileRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = UserProfileDao(db);
      repository = UserProfileRepositoryImpl(
        dao,
        UserOwnedSyncRunner.disabled(),
      );
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create/get/hasProfile fluxo basico', () async {
      final profileId = generateUuidV4();
      final createResult = await repository.create(
        domain.UserProfile(
          id: profileId,
          name: 'Rafa',
          height: 181,
          age: 24,
          lastActiveModule: AppModule.training,
        ),
      );
      final createdId = createResult.getOrThrow();

      expect(createdId, profileId);
      expect((await repository.hasProfile()).getOrThrow(), isTrue);

      final loaded = (await repository.get()).getOrThrow();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Rafa');
      expect(loaded.height, 181);
    });

    test('update altera campos esperados', () async {
      final profileId = generateUuidV4();
      final createdId = (await repository.create(
        domain.UserProfile(
          id: profileId,
          name: 'Antes',
          height: 180,
          age: 20,
          lastActiveModule: AppModule.training,
        ),
      )).getOrThrow();

      final updateResult = await repository.update(
        domain.UserProfile(
          id: createdId,
          name: 'Depois',
          height: 180,
          age: 20,
          lastActiveModule: AppModule.diet,
        ),
      );
      expect(updateResult.isSuccess, isTrue);

      final loaded = (await repository.get()).getOrThrow()!;
      expect(loaded.name, 'Depois');
      expect(loaded.lastActiveModule, AppModule.diet);
    });
  });
}
