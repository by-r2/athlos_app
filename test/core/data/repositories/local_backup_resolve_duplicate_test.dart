import 'package:athlos_app/core/data/repositories/local_backup_repository_impl.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/domain/entities/local_backup_models.dart';
import 'package:athlos_app/core/utils/uuid.dart';
import 'package:athlos_app/features/training/domain/enums/load_mode.dart';
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBackupRepositoryImpl.resolveRuntimeDuplicate', () {
    late AppDatabase db;
    late LocalBackupRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = LocalBackupRepositoryImpl(db);
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('confirmDuplicate merges custom loser into verified winner', () async {
      final verifiedId = generateUuidV4();
      final customId = generateUuidV4();

      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: verifiedId,
          name: 'Supino Reto',
          muscleGroup: MuscleGroup.chest,
          isVerified: const Value(true),
          defaultLoadMode: Value(LoadMode.weighted),
        ),
      );
      await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          id: customId,
          name: 'Supino Reto ',
          muscleGroup: MuscleGroup.chest,
          isVerified: const Value(false),
          defaultLoadMode: Value(LoadMode.weighted),
        ),
      );

      final result = await repository.resolveRuntimeDuplicate(
        entityType: BackupConflictType.exercise,
        leftEntityId: customId,
        rightEntityId: verifiedId,
        decision: RuntimeDuplicateDecision.confirmDuplicate,
        winnerId: verifiedId,
      );

      expect(result.isSuccess, isTrue);

      final customRow = await (db.select(
        db.exercises,
      )..where((e) => e.id.equals(customId))).getSingleOrNull();
      expect(customRow, isNull);

      final verifiedRow = await (db.select(
        db.exercises,
      )..where((e) => e.id.equals(verifiedId))).getSingleOrNull();
      expect(verifiedRow, isNotNull);
    });
  });
}
