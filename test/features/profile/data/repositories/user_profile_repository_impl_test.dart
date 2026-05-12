import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
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
    late UserProfileRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = UserProfileRepositoryImpl(UserProfileDao(db));
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
  });
}
