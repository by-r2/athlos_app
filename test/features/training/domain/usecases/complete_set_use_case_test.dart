import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/training/domain/entities/execution_comparison.dart';
import 'package:athlos_app/features/training/domain/entities/execution_context_fallback.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set.dart';
import 'package:athlos_app/features/training/domain/entities/execution_set_segment.dart';
import 'package:athlos_app/features/training/domain/entities/workout_execution.dart';
import 'package:athlos_app/features/training/domain/enums/session_kind.dart';
import 'package:athlos_app/features/training/domain/repositories/workout_execution_repository.dart';
import 'package:athlos_app/features/training/domain/usecases/complete_set_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompleteSetUseCase', () {
    test('insere set novo quando id.isEmpty', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success('uuid-99');
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: '',
            executionId: 'exec-10',
            exerciseId: 'ex-20',
            setNumber: 1,
            reps: 10,
            weight: 40,
            isCompleted: true,
          ),
        ),
      );

      expect(result.getOrThrow(), 'uuid-99');
      expect(repository.logSetCalls, 1);
      expect(repository.updateSetCalls, 0);
    });

    test('atualiza set existente quando id nao vazio', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.updateSetResult = const Success(null);
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: 'uuid-42',
            executionId: 'exec-10',
            exerciseId: 'ex-20',
            setNumber: 2,
            reps: 8,
            weight: 50,
            isCompleted: true,
          ),
        ),
      );

      expect(result.getOrThrow(), 'uuid-42');
      expect(repository.logSetCalls, 0);
      expect(repository.updateSetCalls, 1);
    });

    test('salva segmentos de drop-set com order sequencial', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success('uuid-123');
      repository.saveSegmentsResult = const Success(null);
      final useCase = CompleteSetUseCase(repository);

      final segments = const [
        ExecutionSetSegment(
          id: '',
          executionSetId: '',
          segmentOrder: 99,
          reps: 12,
          weight: 20,
        ),
        ExecutionSetSegment(
          id: '',
          executionSetId: '',
          segmentOrder: 77,
          reps: 10,
          weight: 15,
        ),
      ];

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: '',
            executionId: 'exec-1',
            exerciseId: 'ex-2',
            setNumber: 3,
            reps: 12,
            weight: 20,
            isCompleted: true,
          ),
          segments: segments,
        ),
      );

      expect(result.getOrThrow(), 'uuid-123');
      expect(repository.savedSegmentsExecutionSetId, 'uuid-123');
      expect(repository.savedSegments.length, 2);
      expect(repository.savedSegments[0].segmentOrder, 1);
      expect(repository.savedSegments[1].segmentOrder, 2);
      expect(repository.savedSegments[0].executionSetId, 'uuid-123');
      expect(repository.savedSegments[1].executionSetId, 'uuid-123');
    });

    test('retorna falha quando salvar segmentos falha', () async {
      final repository = _FakeWorkoutExecutionRepository();
      repository.logSetResult = const Success('uuid-123');
      repository.saveSegmentsResult = const Failure(
        DatabaseException('segments error'),
      );
      final useCase = CompleteSetUseCase(repository);

      final result = await useCase(
        CompleteSetParams(
          set: const ExecutionSet(
            id: '',
            executionId: 'exec-1',
            exerciseId: 'ex-2',
            setNumber: 1,
            reps: 10,
            weight: 30,
            isCompleted: true,
          ),
          segments: const [
            ExecutionSetSegment(
              id: '',
              executionSetId: '',
              segmentOrder: 1,
              reps: 10,
              weight: 30,
            ),
            ExecutionSetSegment(
              id: '',
              executionSetId: '',
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
  Result<String> logSetResult = const Failure(
    DatabaseException('not configured'),
  );
  Result<void> updateSetResult = const Failure(
    DatabaseException('not configured'),
  );
  Result<void> saveSegmentsResult = const Failure(
    DatabaseException('not configured'),
  );

  int logSetCalls = 0;
  int updateSetCalls = 0;
  String? savedSegmentsExecutionSetId;
  List<ExecutionSetSegment> savedSegments = const [];

  @override
  Future<Result<String>> logSet(ExecutionSet set) async {
    logSetCalls++;
    return logSetResult;
  }

  @override
  Future<Result<void>> updateSet(ExecutionSet set) async {
    updateSetCalls++;
    return updateSetResult;
  }

  @override
  Future<Result<void>> rekeySetCatalogExercise(ExecutionSet set) async =>
      updateSet(set);

  @override
  Future<Result<void>> saveSegments(
    String executionSetId,
    List<ExecutionSetSegment> segments,
  ) async {
    savedSegmentsExecutionSetId = executionSetId;
    savedSegments = segments;
    return saveSegmentsResult;
  }

  @override
  Future<Result<int>> countFinished() => _unsupported();

  @override
  Future<Result<List<WorkoutExecution>>> getAll() => _unsupported();
  @override
  Future<Result<List<WorkoutExecution>>> getByWorkout(String workoutId) =>
      _unsupported();
  @override
  Future<Result<WorkoutExecution?>> getById(String id) => _unsupported();
  @override
  Future<Result<WorkoutExecution?>> getLastFinished() => _unsupported();
  @override
  Future<Result<WorkoutExecution?>> getLastFinishedForCycle({
    required String programId,
    required List<String> cycleWorkoutIds,
  }) => _unsupported();
  @override
  Future<Result<ExecutionComparison?>> getLastTwoFinishedWithVolume(
    String workoutId,
  ) => _unsupported();
  @override
  Future<Result<String>> start(
    String workoutId, {
    String? programId,
    SessionKind sessionKind = SessionKind.planned,
  }) => _unsupported();
  @override
  Future<Result<void>> finish(String executionId) => _unsupported();

  @override
  Future<Result<void>> finishWithSnapshot({
    required String executionId,
    required String workoutNameSnapshot,
    String? programNameSnapshot,
    required ExecutionContextFallback contextFallback,
  }) => _unsupported();
  @override
  Future<Result<void>> delete(String id) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getSets(String executionId) =>
      _unsupported();
  @override
  Future<Result<Map<String, double>>> getLastWeightsForExercises(
    List<String> exerciseIds,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSetSegment>>> getSegments(
    String executionSetId,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSetSegment>>> getSegmentsForExecution(
    String executionId,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getLastCompletedSetsForExercise(
    String exerciseId,
  ) => _unsupported();
  @override
  Future<Result<List<ExecutionSet>>> getAllCompletedSetsForExercise(
    String exerciseId,
  ) => _unsupported();
  @override
  Future<Result<List<({ExecutionSet set, DateTime date})>>>
  getCompletedSetsWithDateForExercise(String exerciseId) => _unsupported();
  @override
  Future<Result<List<WorkoutExecution>>> getDangling() => _unsupported();
  @override
  Future<Result<void>> deleteUnfinishedByWorkout(String workoutId) =>
      _unsupported();
  @override
  Future<Result<void>> deleteOrphaned() => _unsupported();
}

Future<Result<T>> _unsupported<T>() async {
  throw UnimplementedError();
}
