import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/domain/entities/execution_comparison.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set_segment.dart';
import 'package:athlos_app/features/training/domain/entities/workout_execution.dart';
import 'package:athlos_app/features/training/domain/repositories/workout_execution_repository.dart';
import 'package:athlos_app/features/training/domain/usecases/complete_set_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteSetUseCase', () {
    test('insere set novo quando id == 0', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success(99);
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: 0,
            executionId: 10,
            exerciseId: 20,
            setNumber: 1,
            reps: 10,
            weight: 40,
            isCompleted: true,
          ),
        ),
      );

      expect(result.getOrThrow(), 99);
      expect(repository.logSetCalls, 1);
      expect(repository.updateSetCalls, 0);
    });

    test('atualiza set existente quando id > 0', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.updateSetResult = const Success(null);
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: 42,
            executionId: 10,
            exerciseId: 20,
            setNumber: 2,
            reps: 8,
            weight: 50,
            isCompleted: true,
          ),
        ),
      );

      expect(result.getOrThrow(), 42);
      expect(repository.logSetCalls, 0);
      expect(repository.updateSetCalls, 1);
    });

    test('salva segmentos de drop-set com order sequencial', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success(123);
      repository.saveSegmentsResult = const Success(null);
      final useCase = CompleteSetUseCase(repository);

      final segments = const [
        ExecutionSetSegment(
          id: 0,
          executionSetId: 0,
          segmentOrder: 99,
          reps: 12,
          weight: 20,
        ),
        ExecutionSetSegment(
          id: 0,
          executionSetId: 0,
          segmentOrder: 77,
          reps: 10,
          weight: 15,
        ),
      ];

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: 0,
            executionId: 1,
            exerciseId: 2,
            setNumber: 3,
            reps: 12,
            weight: 20,
            isCompleted: true,
          ),
          segments: segments,
        ),
      );

      expect(result.getOrThrow(), 123);
      expect(repository.savedSegmentsExecutionSetId, 123);
      expect(repository.savedSegments.length, 2);
      expect(repository.savedSegments[0].segmentOrder, 1);
      expect(repository.savedSegments[1].segmentOrder, 2);
      expect(repository.savedSegments[0].executionSetId, 123);
      expect(repository.savedSegments[1].executionSetId, 123);
    });

    test('retorna falha quando salvar segmentos falha', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success(123);
      repository.saveSegmentsResult = const Failure(
        DatabaseException('segments error'),
      );
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: 0,
            executionId: 1,
            exerciseId: 2,
            setNumber: 1,
            reps: 10,
            weight: 30,
            isCompleted: true,
          ),
          segments: const [
            ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 1,
              reps: 10,
              weight: 30,
            ),
            ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 2,
              reps: 8,
              weight: 25,
            ),
          ],
        ),
      );

      expect(result.isFailure, isTrue);
    });
  });
}

class _FakeWorkoutExecutionRepository implements WorkoutExecutionRepository {
  Result<int> logSetResult = const Failure(DatabaseException('not configured'));
  Result<void> updateSetResult = const Failure(
    DatabaseException('not configured'),
  );
  Result<void> saveSegmentsResult = const Failure(
    DatabaseException('not configured'),
  );

  int logSetCalls = 0;
  int updateSetCalls = 0;
  int? savedSegmentsExecutionSetId;
  List<ExecutionSetSegment> savedSegments = const [];

  @override
  Future<Result<int>> logSet(ExecutionSet set) async {
    logSetCalls++;
    return logSetResult;
  }

  @override
  Future<Result<void>> updateSet(ExecutionSet set) async {
    updateSetCalls++;
    return updateSetResult;
  }

  @override
  Future<Result<void>> saveSegments(
    int executionSetId,
    List<ExecutionSetSegment> segments,
  ) async {
    savedSegmentsExecutionSetId = executionSetId;
    savedSegments = segments;
    return saveSegmentsResult;
  }

  @override
  Future<Result<List<WorkoutExecution>>> getAll() => _unsupported();
  @override
  Future<Result<List<WorkoutExecution>>> getByWorkout(int workoutId) =>
      _unsupported();
  @override
  Future<Result<WorkoutExecution?>> getById(int id) => _unsupported();
  @override
  Future<Result<WorkoutExecution?>> getLastFinished() => _unsupported();
  @override
  Future<Result<ExecutionComparison?>> getLastTwoFinishedWithVolume(
    int workoutId,
  ) => _unsupported();
  @override
  Future<Result<int>> start(
    int workoutId, {
    required int programId,
    String? exerciseConfigSnapshot,
  }) => _unsupported();
  @override
  Future<Result<void>> finish(int executionId, {String? notes}) =>
      _unsupported();
  @override
  Future<Result<void>> delete(int id) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getSets(int executionId) => _unsupported();
  @override
  Future<Result<Map<int, double>>> getLastWeightsForExercises(
    List<int> exerciseIds,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSetSegment>>> getSegments(int executionSetId) =>
      _unsupported();
  @override
  Future<Result<List<ExecutionSetSegment>>> getSegmentsForExecution(
    int executionId,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getLastCompletedSetsForExercise(
    int exerciseId,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getAllCompletedSetsForExercise(
    int exerciseId,
  ) => _unsupported();

  @override
  Future<Result<List<({ExecutionSet set, DateTime date})>>>
  getCompletedSetsWithDateForExercise(int exerciseId) => _unsupported();
  @override
  Future<Result<List<WorkoutExecution>>> getDangling() => _unsupported();
  @override
  Future<Result<void>> deleteUnfinishedByWorkout(int workoutId) =>
      _unsupported();
  @override
  Future<Result<void>> deleteOrphaned() => _unsupported();
}

Future<Result<T>> _unsupported<T>() async {
  throw UnimplementedError();
}
