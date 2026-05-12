import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/data/datasources/daos/workout_dao.dart';
import 'package:athlos_app/features/training/data/repositories/workout_repository_impl.dart';
import 'package:athlos_app/features/training/domain/entities/workout.dart'
    as domain;
import 'package:athlos_app/features/training/domain/entities/workout_exercise.dart'
    as domain;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkoutRepositoryImpl', () {
    late AppDatabase db;
    late WorkoutRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = WorkoutRepositoryImpl(WorkoutDao(db));
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('create/getExercises/update/archive/unarchive/delete', () async {
      final createResult = await repository.create(
        domain.Workout(
          id: 0,
          name: 'Treino Repo',
          description: 'descricao',
          createdAt: DateTime.now(),
        ),
        const [
          domain.WorkoutExercise(
            workoutId: 0,
            exerciseId: 1,
            order: 0,
            sets: 3,
            minReps: 10,
            maxReps: 10,
            rest: 60,
          ),
        ],
      );
      final workoutId = createResult.getOrThrow();
      expect(workoutId, greaterThan(0));

      final exercises1 = (await repository.getExercises(
        workoutId,
      )).getOrThrow();
      expect(exercises1.length, 1);
      expect(exercises1.first.exerciseId, 1);

      final updateResult = await repository.update(
        domain.Workout(
          id: workoutId,
          name: 'Treino Repo V2',
          description: 'nova',
          createdAt: DateTime.now(),
        ),
        const [
          domain.WorkoutExercise(
            workoutId: 0,
            exerciseId: 2,
            order: 0,
            sets: 4,
            minReps: 8,
            maxReps: 12,
            rest: 90,
          ),
        ],
      );
      expect(updateResult.isSuccess, isTrue);
      expect(
        (await repository.getById(workoutId)).getOrThrow()!.name,
        'Treino Repo V2',
      );
      final exercises2 = (await repository.getExercises(
        workoutId,
      )).getOrThrow();
      expect(exercises2.single.exerciseId, 2);

      expect((await repository.archive(workoutId)).isSuccess, isTrue);
      expect(
        (await repository.getArchived()).getOrThrow().any(
          (w) => w.id == workoutId,
        ),
        isTrue,
      );

      expect((await repository.unarchive(workoutId)).isSuccess, isTrue);
      expect(
        (await repository.getActive()).getOrThrow().any(
          (w) => w.id == workoutId,
        ),
        isTrue,
      );

      expect((await repository.delete(workoutId)).isSuccess, isTrue);
      expect((await repository.getById(workoutId)).getOrThrow(), isNull);
    });

    test('duplicate retorna NotFound quando id nao existe', () async {
      final result = await repository.duplicate(999999, nameSuffix: '(copy)');
      expect(result.isFailure, isTrue);
      final failure = result as Failure<int>;
      expect(failure.exception, isA<NotFoundException>());
    });

    test('duplicate e reorder funcionam', () async {
      final id1 = (await repository.create(
        domain.Workout(id: 0, name: 'A', createdAt: DateTime.now()),
        const [],
      )).getOrThrow();
      final id2 = (await repository.create(
        domain.Workout(id: 0, name: 'B', createdAt: DateTime.now()),
        const [],
      )).getOrThrow();

      final duplicated = await repository.duplicate(id1, nameSuffix: '(copy)');
      expect(duplicated.isSuccess, isTrue);
      final duplicatedId = duplicated.getOrThrow();
      final duplicatedWorkout = (await repository.getById(
        duplicatedId,
      )).getOrThrow();
      expect(duplicatedWorkout, isNotNull);
      expect(duplicatedWorkout!.name.contains('(copy)'), isTrue);

      expect(
        (await repository.reorder([id2, id1, duplicatedId])).isSuccess,
        isTrue,
      );
      final active = (await repository.getActive()).getOrThrow();
      expect(active.take(3).map((w) => w.id).toList(), [
        id2,
        id1,
        duplicatedId,
      ]);
    });
  });
}
