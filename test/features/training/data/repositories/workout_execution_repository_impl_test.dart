import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
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
    const programId = 'program-1';
    const workoutId = 'workout-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = WorkoutExecutionRepositoryImpl(
        WorkoutExecutionDao(db),
        UserOwnedSyncRunner.disabled(),
        'test-user-id',
      );
      await db.customSelect('SELECT 1').get();
      await db.customInsert(
        "INSERT INTO programs (id, user_id, name, focus, duration_mode, duration_value, is_active) "
        "VALUES ('$programId', '', 'Test', 'custom', 'sessions', 12, 1)",
      );
      await db.customInsert(
        "INSERT INTO workouts (id, user_id, name, sort_order, is_archived) "
        "VALUES ('$workoutId', '', 'W', 0, 0)",
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'start/logSet/getSets/saveSegments/getSegments/finish/delete',
      () async {
        final executionId = (await repository.start(
          workoutId,
          programId: programId,
        )).getOrThrow();
        expect(executionId, isNotEmpty);

        final setId = (await repository.logSet(
          domain.ExecutionSet(
            id: '',
            executionId: executionId,
            exerciseId: 'ex-1',
            setNumber: 1,
            reps: 10,
            weight: 50,
            isCompleted: true,
          ),
        )).getOrThrow();
        expect(setId, isNotEmpty);

        final sets = (await repository.getSets(executionId)).getOrThrow();
        expect(sets, isNotEmpty);
        expect(sets.first.reps, 10);

        expect(
          (await repository.saveSegments(setId, const [
            domain.ExecutionSetSegment(
              id: '',
              executionSetId: '',
              segmentOrder: 1,
              reps: 10,
              weight: 50,
            ),
            domain.ExecutionSetSegment(
              id: '',
              executionSetId: '',
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
      final e1 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e1,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      );
      await repository.finish(e1);

      final e2 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e2,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 8,
          weight: 60,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        workoutId,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      expect(volumes, containsAll(<double>[480, 500]));
    });

    test('getLastTwoFinishedWithVolume soma drop-set segments', () async {
      final e1 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e1,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      );
      final dropSetId = (await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e1,
          exerciseId: 'ex-1',
          setNumber: 2,
          reps: 10,
          weight: 50,
          isCompleted: true,
        ),
      )).getOrThrow();
      await repository.saveSegments(dropSetId, const [
        domain.ExecutionSetSegment(
          id: '',
          executionSetId: '',
          segmentOrder: 1,
          reps: 10,
          weight: 50,
        ),
        domain.ExecutionSetSegment(
          id: '',
          executionSetId: '',
          segmentOrder: 2,
          reps: 8,
          weight: 40,
        ),
      ]);
      await repository.finish(e1);

      final e2 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e2,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 5,
          weight: 100,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        workoutId,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      expect(volumes, containsAll(<double>[1320, 500]));
    });

    test('getLastTwoFinishedWithVolume exclui sets de aquecimento', () async {
      final e1 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e1,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 10,
          weight: 30,
          isCompleted: true,
          isWarmup: true,
        ),
      );
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e1,
          exerciseId: 'ex-1',
          setNumber: 2,
          reps: 10,
          weight: 60,
          isCompleted: true,
        ),
      );
      await repository.finish(e1);

      final e2 = (await repository.start(workoutId, programId: programId)).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: e2,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 8,
          weight: 70,
          isCompleted: true,
        ),
      );
      await repository.finish(e2);

      final comparison = (await repository.getLastTwoFinishedWithVolume(
        workoutId,
      )).getOrThrow();
      expect(comparison, isNotNull);
      final volumes = [comparison!.volumeLast, comparison.volumePrevious];
      expect(volumes, containsAll(<double>[600, 560]));
    });

    test('getLastWeightsForExercises retorna ultimo peso concluido', () async {
      final executionId = (await repository.start(
        workoutId,
        programId: programId,
      )).getOrThrow();
      await repository.logSet(
        domain.ExecutionSet(
          id: '',
          executionId: executionId,
          exerciseId: 'ex-1',
          setNumber: 1,
          reps: 10,
          weight: 55.5,
          isCompleted: true,
        ),
      );
      await repository.finish(executionId);

      final weights = (await repository.getLastWeightsForExercises(const [
        'ex-1',
        'ex-2',
      ])).getOrThrow();
      expect(weights['ex-1'], 55.5);
      expect(weights.containsKey('ex-2'), isFalse);
    });
  });
}
