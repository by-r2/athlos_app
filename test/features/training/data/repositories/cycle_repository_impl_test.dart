import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/database/daos/sync_record_dao.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/sync_record_store.dart';
import 'package:athlos_app/core/sync/user_owned_sync_registry.dart';
import 'package:athlos_app/core/sync/user_owned_sync_runner.dart';
import 'package:athlos_app/features/training/data/datasources/daos/cycle_step_dao.dart';
import 'package:athlos_app/features/training/data/repositories/cycle_repository_impl.dart';
import 'package:athlos_app/features/training/domain/entities/cycle_step.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CycleRepositoryImpl', () {
    late AppDatabase db;
    late CycleRepositoryImpl repository;
    const programId = 1;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CycleRepositoryImpl(
        CycleStepDao(db),
        UserOwnedSyncRunner(UserOwnedSyncRegistry([])),
      );
      await db.customSelect('SELECT 1').get();

      await db.customInsert(
        "INSERT INTO programs (name, focus, duration_mode, duration_value, is_active) "
        "VALUES ('Test', 'custom', 'sessions', 12, 1)",
      );
      for (final wId in [1, 2, 3, 10, 20]) {
        await db.customInsert(
          "INSERT INTO workouts (id, name, sort_order, is_archived, created_at) "
          "VALUES ($wId, 'W$wId', 0, 0, 1)",
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('setSteps/getSteps preserva ordem', () async {
      final result = await repository.setSteps(const [
        TrainingCycleStep(id: 0, orderIndex: 0, workoutId: 10),
        TrainingCycleStep(id: 0, orderIndex: 1, workoutId: 20),
      ], programId);
      expect(result.isSuccess, isTrue);

      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 2);
      expect(loaded[0].workoutId, 10);
      expect(loaded[1].workoutId, 20);
    });

    test('appendWorkoutToCycle adiciona no final', () async {
      await repository.setSteps(const [], programId);

      expect(
        (await repository.appendWorkoutToCycle(1, programId)).isSuccess,
        isTrue,
      );
      expect(
        (await repository.appendWorkoutToCycle(2, programId)).isSuccess,
        isTrue,
      );

      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 2);
      expect(loaded[0].workoutId, 1);
      expect(loaded[0].orderIndex, 0);
      expect(loaded[1].workoutId, 2);
      expect(loaded[1].orderIndex, 1);
    });

    test('removeWorkoutFromCycle remove e reindexa', () async {
      await repository.setSteps(const [
        TrainingCycleStep(id: 0, orderIndex: 0, workoutId: 1),
        TrainingCycleStep(id: 0, orderIndex: 1, workoutId: 2),
        TrainingCycleStep(id: 0, orderIndex: 2, workoutId: 3),
      ], programId);

      expect(
        (await repository.removeWorkoutFromCycle(1, programId)).isSuccess,
        isTrue,
      );
      final loaded = (await repository.getSteps(programId)).getOrThrow();

      expect(loaded.length, 2);
      expect(loaded[0].orderIndex, 0);
      expect(loaded[0].workoutId, 2);
      expect(loaded[1].orderIndex, 1);
      expect(loaded[1].workoutId, 3);
    });

    test('removeWorkoutFromAllCycles remove de todos os programas', () async {
      await repository.setSteps(const [
        TrainingCycleStep(id: 0, orderIndex: 0, workoutId: 1),
        TrainingCycleStep(id: 0, orderIndex: 1, workoutId: 2),
      ], programId);

      expect(
        (await repository.removeWorkoutFromAllCycles(1)).isSuccess,
        isTrue,
      );
      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 1);
      expect(loaded[0].workoutId, 2);
    });
  });
}
