import 'package:athlos_app/core/data/repositories/local_backup_providers.dart';
import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/features/profile/data/repositories/profile_providers.dart';
import 'package:athlos_app/features/training/data/repositories/training_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Providers wiring', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('training/profile/core providers resolvem dependencias', () {
      expect(container.read(exerciseDaoProvider), isNotNull);
      expect(container.read(workoutDaoProvider), isNotNull);
      expect(container.read(workoutExecutionDaoProvider), isNotNull);
      expect(container.read(cycleStepDaoProvider), isNotNull);

      expect(container.read(exerciseRepositoryProvider), isNotNull);
      expect(container.read(workoutRepositoryProvider), isNotNull);
      expect(container.read(workoutExecutionRepositoryProvider), isNotNull);
      expect(container.read(cycleRepositoryProvider), isNotNull);
      expect(container.read(completeSetUseCaseProvider), isNotNull);

      expect(container.read(userProfileDaoProvider), isNotNull);
      expect(container.read(userProfileRepositoryProvider), isNotNull);

      expect(container.read(localBackupRepositoryProvider), isNotNull);
      expect(container.read(exportLocalBackupUseCaseProvider), isNotNull);
      expect(
        container.read(previewLocalBackupImportUseCaseProvider),
        isNotNull,
      );
      expect(container.read(importLocalBackupUseCaseProvider), isNotNull);
    });
  });
}
