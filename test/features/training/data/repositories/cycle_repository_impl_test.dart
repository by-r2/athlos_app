import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
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
    const programId = 'program-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CycleRepositoryImpl(
        CycleStepDao(db),
        UserOwnedSyncRunner.disabled(),
        'test-user-id',
      );
      await db.customSelect('SELECT 1').get();

      await db.customInsert(
        "INSERT INTO programs (id, user_id, name, focus, duration_mode, duration_value, is_active) "
        "VALUES ('$programId', '', 'Test', 'custom', 'sessions', 12, 1)",
      );
      for (final wId in ['w-1', 'w-2', 'w-3', 'w-10', 'w-20']) {
        await db.customInsert(
          "INSERT INTO workouts (id, user_id, name, sort_order, is_archived) "
          "VALUES ('$wId', '', 'W$wId', 0, 0)",
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('setSteps/getSteps preserva ordem', () async {
      final result = await repository.setSteps(const [
        TrainingCycleStep(id: '', orderIndex: 0, workoutId: 'w-10'),
        TrainingCycleStep(id: '', orderIndex: 1, workoutId: 'w-20'),
      ], programId);
      expect(result.isSuccess, isTrue);

      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 2);
      expect(loaded[0].workoutId, 'w-10');
      expect(loaded[1].workoutId, 'w-20');
    });

    test('appendWorkoutToCycle adiciona no final', () async {
      await repository.setSteps(const [], programId);

      expect(
        (await repository.appendWorkoutToCycle('w-1', programId)).isSuccess,
        isTrue,
      );
      expect(
        (await repository.appendWorkoutToCycle('w-2', programId)).isSuccess,
        isTrue,
      );

      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 2);
      expect(loaded[0].workoutId, 'w-1');
      expect(loaded[0].orderIndex, 0);
      expect(loaded[1].workoutId, 'w-2');
      expect(loaded[1].orderIndex, 1);
    });

    test('removeWorkoutFromCycle remove e reindexa', () async {
      await repository.setSteps(const [
        TrainingCycleStep(id: '', orderIndex: 0, workoutId: 'w-1'),
        TrainingCycleStep(id: '', orderIndex: 1, workoutId: 'w-2'),
        TrainingCycleStep(id: '', orderIndex: 2, workoutId: 'w-3'),
      ], programId);

      expect(
        (await repository.removeWorkoutFromCycle('w-1', programId)).isSuccess,
        isTrue,
      );
      final loaded = (await repository.getSteps(programId)).getOrThrow();

      expect(loaded.length, 2);
      expect(loaded[0].orderIndex, 0);
      expect(loaded[0].workoutId, 'w-2');
      expect(loaded[1].orderIndex, 1);
      expect(loaded[1].workoutId, 'w-3');
    });

    test('removeWorkoutFromAllCycles remove de todos os programas', () async {
      await repository.setSteps(const [
        TrainingCycleStep(id: '', orderIndex: 0, workoutId: 'w-1'),
        TrainingCycleStep(id: '', orderIndex: 1, workoutId: 'w-2'),
      ], programId);

      expect(
        (await repository.removeWorkoutFromAllCycles('w-1')).isSuccess,
        isTrue,
      );
      final loaded = (await repository.getSteps(programId)).getOrThrow();
      expect(loaded.length, 1);
      expect(loaded[0].workoutId, 'w-2');
    });
  });
}
