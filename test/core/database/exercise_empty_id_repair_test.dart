import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/database/exercise_empty_id_repair.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/user_owned_sync_runner.dart';
import 'package:athlos_app/features/training/data/datasources/daos/exercise_dao.dart';
import 'package:athlos_app/features/training/data/repositories/exercise_repository_impl.dart';
import 'package:athlos_app/features/training/domain/entities/exercise.dart' as domain;
import 'package:athlos_app/features/training/domain/enums/muscle_group.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repairExercisesWithEmptyIds fixes broken custom exercise row', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.exercises).insert(
      ExercisesCompanion.insert(
        id: '',
        createdBy: const Value('user-1'),
        name: 'Broken Exercise',
        muscleGroup: MuscleGroup.chest,
      ),
    );

    await repairExercisesWithEmptyIds(db);

    final brokenAfter = await db
        .customSelect("SELECT id FROM exercises WHERE trim(id) = ''")
        .get();
    expect(brokenAfter, isEmpty);

    final row = await (db.select(db.exercises)
          ..where((e) => e.name.equals('Broken Exercise')))
        .getSingle();
    expect(row.id, isNotEmpty);
    expect(row.isDirty, isTrue);

    final repo = ExerciseRepositoryImpl(
      ExerciseDao(db),
      UserOwnedSyncRunner.disabled(),
      'user-1',
    );
    final loaded = (await repo.getById(row.id)).getOrThrow();
    expect(loaded?.name, 'Broken Exercise');
  });

  test('create no longer persists empty id', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = ExerciseRepositoryImpl(
      ExerciseDao(db),
      UserOwnedSyncRunner.disabled(),
      'user-1',
    );

    final id = (await repo.create(
      const domain.Exercise(
        id: '',
        name: 'New Exercise',
        muscleGroup: MuscleGroup.back,
      ),
    )).getOrThrow();

    expect(id, isNotEmpty);
    final row = await (db.select(db.exercises)
          ..where((e) => e.name.equals('New Exercise')))
        .getSingle();
    expect(row.id, id);
  });
}
