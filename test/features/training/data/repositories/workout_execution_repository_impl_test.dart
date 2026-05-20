import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/database/daos/sync_record_dao.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/sync_record_store.dart';
import 'package:athlos_app/core/sync/user_owned_sync_registry.dart';
import 'package:athlos_app/core/sync/user_owned_sync_runner.dart';
import 'package:athlos_app/features/training/data/datasources/daos/workout_execution_dao.dart';
import 'package:athlos_app/features/training/data/repositories/workout_execution_repository_impl.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set.dart'
    as domain;
import 'package:athlos_app/features/training/domain/entities/execution_set_segment.dart'
    as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutExecutionRepositoryImpl', () {
    late AppDatabase db;
    late WorkoutExecutionRepositoryImpl repository;
    const programId = 1;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = WorkoutExecutionRepositoryImpl(
        WorkoutExecutionDao(db),
        UserOwnedSyncRunner(UserOwnedSyncRegistry([])),
        SyncRecordStore(SyncRecordDao(db)),
      );
      await db.customSelect('SELECT 1').get();
      await db.customInsert(
        "INSERT INTO programs (name, focus, duration_mode, duration_value, is_active) "
        "VALUES ('Test', 'custom', 'sessions', 12, 1)",
      );
      await db.customInsert(
        'INSERT INTO "workouts" ("name", "description", "sort_order", "is_archived", "created_at") VALUES (\'W\', NULL, 0, 0, 1)',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'start/logSet/getSets/saveSegments/getSegments/finish/delete',
      () async {
        final executionId = (await repository.start(
          1,
          programId: programId,
        )).getOrThrow();
        expect(executionId, greaterThan(0));

        final setId = (await repository.logSet(
          domain.ExecutionSet(
            id: 0,
            executionId: executionId,
            exerciseId: 1,
            setNumber: 1,
            reps: 10,
            weight: 50,
            isCompleted: true,
          ),
        )).getOrThrow();
        expect(setId, greaterThan(0));

        final sets = (await repository.getSets(executionId)).getOrThrow();
        expect(sets, isNotEmpty);
        expect(sets.first.reps, 10);

        expect(
          (await repository.saveSegments(setId, const [
            domain.ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 1,
              reps: 10,
              weight: 50,
            ),
            domain.ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 2,
              reps: 8,
              weight: 40,
            ),
          ])).isSuccess,
          isTrue,
        );
        final segments = (await repository.getSegments(setId)).getOrThrow();
        expect(segments.length, 2);
        expect(segments.first.segmentOrder, 1);

        expect((await repository.finish(executionId)).isSuccess, isTrue);
        final lastFinished = (await repository.getLastFinished()).getOrThrow();
        expect(lastFinished, isNotNull);
        expect(lastFinished!.finishedAt, isNotNull);
        expect(lastFinished.programId, programId);

        expect((await repository.delete(executionId)).isSuccess, isTrue);
        expect((await repository.getById(executionId)).getOrThrow(), isNull);
      },
    );

    test('getLastTwoFinishedWithVolume calcula volume corretamente', () async {
      final e1 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e1,
          exerciseId: 1,
          setNumber: 1,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      );
      await repository.finish(e1);

      final e2 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e2,
          exerciseId: 1,
          setNumber: 1,
          reps: 8,
          weight: 60,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        1,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      expect(volumes, containsAll(<double>[480, 500]));
    });

    test('getLastTwoFinishedWithVolume soma drop-set segments', () async {
      // e1: 1 normal set (10 × 50 = 500) + 1 drop set with 2 segments
      //     (10 × 50 + 8 × 40 = 820), total = 1320.
      final e1 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e1,
          exerciseId: 1,
          setNumber: 1,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      );
      final dropSetId = (await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e1,
          exerciseId: 1,
          setNumber: 2,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      )).getOrThrow();
      await repository.saveSegments(dropSetId, const [
        domain.ExecutionSetSegment(
          id: 0,
          executionSetId: 0,
          segmentOrder: 1,
          reps: 10,
          weight: 50,
        ),
        domain.ExecutionSetSegment(
          id: 0,
          executionSetId: 0,
          segmentOrder: 2,
          reps: 8,
          weight: 40,
        ),
      ]);
      await repository.finish(e1);

      // e2: a single weighted set so a comparison can be computed.
      final e2 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e2,
          exerciseId: 1,
          setNumber: 1,
          reps: 5,
          weight: 100,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        1,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      expect(volumes, containsAll(<double>[1320, 500]));
    });

    test('getLastTwoFinishedWithVolume exclui sets de aquecimento', () async {
      // e1: 1 warmup (excluded) + 1 work set (counted).
      final e1 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e1,
          exerciseId: 1,
          setNumber: 1,
          reps: 10,
          weight: 30,
          isCompleted: true,
          isWarmup: true,
        ),
      );
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e1,
          exerciseId: 1,
          setNumber: 2,
          reps: 10,
          weight: 60,
          isCompleted: true,
        ),
      );
      await repository.finish(e1);

      final e2 = (await repository.start(1, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: e2,
          exerciseId: 1,
          setNumber: 1,
          reps: 8,
          weight: 70,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        1,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      // e1 should be 600 (warmup excluded), not 900.
      expect(volumes, containsAll(<double>[600, 560]));
    });

    test('getLastWeightsForExercises retorna ultimo peso concluido', () async {
      final executionId = (await repository.start(
        1,
        programId: programId,
      )).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: 0,
          executionId: executionId,
          exerciseId: 1,
          setNumber: 1,
          reps: 10,
          weight: 55.5,
          isCompleted: true,
        ),
      );
      await repository.finish(executionId);

      final weights = (await repository.getLastWeightsForExercises(const [
        1,
        2,
      ])).getOrThrow();
      expect(weights[1], 55.5);
      expect(weights.containsKey(2), isFalse);
    });

    test('start with exerciseConfigSnapshot stores snapshot', () async {
      const snapshot = '{"exercises":[]}';
      final executionId = (await repository.start(
        1,
        programId: programId,
        exerciseConfigSnapshot: snapshot,
      )).getOrThrow();

      final execution = (await repository.getById(executionId)).getOrThrow();
      expect(execution, isNotNull);
      expect(execution!.exerciseConfigSnapshot, snapshot);
    });
  });
}
