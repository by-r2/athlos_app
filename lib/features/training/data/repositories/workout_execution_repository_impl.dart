import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/execution_set.dart' as domain;
import '../../domain/entities/execution_set_segment.dart' as domain;
import '../../domain/entities/workout_execution.dart' as domain;
import '../../domain/repositories/workout_execution_repository.dart';
import '../datasources/daos/workout_execution_dao.dart';

class WorkoutExecutionRepositoryImpl implements WorkoutExecutionRepository {
  final WorkoutExecutionDao _dao;

  WorkoutExecutionRepositoryImpl(this._dao);

  @override
  Future<Result<List<domain.WorkoutExecution>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load executions: $e'));
    }
  }

  @override
  Future<Result<List<domain.WorkoutExecution>>> getByWorkout(
      int workoutId) async {
    try {
      final rows = await _dao.getByWorkout(workoutId);
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load executions for workout: $e'));
    }
  }

  @override
  Future<Result<domain.WorkoutExecution?>> getById(int id) async {
    try {
      final row = await _dao.getById(id);
      return Success(row != null ? _executionToDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load execution $id: $e'));
    }
  }

  @override
  Future<Result<domain.WorkoutExecution?>> getLastFinished() async {
    try {
      final row = await _dao.getLastFinished();
      return Success(row != null ? _executionToDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load last finished execution: $e'));
    }
  }

  @override
  Future<Result<int>> start(int workoutId) async {
    try {
      final id = await _dao.create(
        WorkoutExecutionsCompanion.insert(workoutId: workoutId),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to start execution: $e'));
    }
  }

  @override
  Future<Result<void>> finish(int executionId, {String? notes}) async {
    try {
      await _dao.finish(executionId, notes: notes);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to finish execution: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _dao.deleteById(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete execution $id: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getSets(int executionId) async {
    try {
      final rows = await _dao.getSets(executionId);
      return Success(rows.map(_setToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load sets: $e'));
    }
  }

  @override
  Future<Result<int>> logSet(domain.ExecutionSet set) async {
    try {
      final id = await _dao.insertSet(
        ExecutionSetsCompanion.insert(
          executionId: set.executionId,
          exerciseId: set.exerciseId,
          setNumber: set.setNumber,
          plannedReps: set.plannedReps,
          plannedWeight: Value(set.plannedWeight),
          reps: set.reps,
          weight: Value(set.weight),
          isCompleted: Value(set.isCompleted),
          notes: Value(set.notes),
        ),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to log set: $e'));
    }
  }

  @override
  Future<Result<void>> updateSet(domain.ExecutionSet set) async {
    try {
      await _dao.updateSet(
        set.id,
        ExecutionSetsCompanion(
          reps: Value(set.reps),
          weight: Value(set.weight),
          isCompleted: Value(set.isCompleted),
          notes: Value(set.notes),
        ),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update set: $e'));
    }
  }

  @override
  Future<Result<Map<int, double>>> getLastWeightsForExercises(
      List<int> exerciseIds) async {
    try {
      final weights = await _dao.getLastWeightsForExercises(exerciseIds);
      return Success(weights);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load last weights: $e'));
    }
  }

  domain.WorkoutExecution _executionToDomain(dynamic row) =>
      domain.WorkoutExecution(
        id: row.id as int,
        workoutId: row.workoutId as int,
        startedAt: row.startedAt as DateTime,
        finishedAt: row.finishedAt as DateTime?,
        notes: row.notes as String?,
      );

  domain.ExecutionSet _setToDomain(dynamic row) => domain.ExecutionSet(
        id: row.id as int,
        executionId: row.executionId as int,
        exerciseId: row.exerciseId as int,
        setNumber: row.setNumber as int,
        plannedReps: row.plannedReps as int,
        plannedWeight: row.plannedWeight as double?,
        reps: row.reps as int,
        weight: row.weight as double?,
        isCompleted: row.isCompleted as bool,
        notes: row.notes as String?,
      );

  domain.ExecutionSetSegment _segmentToDomain(dynamic row) =>
      domain.ExecutionSetSegment(
        id: row.id as int,
        executionSetId: row.executionSetId as int,
        segmentOrder: row.segmentOrder as int,
        reps: row.reps as int,
        weight: row.weight as double?,
      );

  @override
  Future<Result<List<domain.ExecutionSetSegment>>> getSegments(
      int executionSetId) async {
    try {
      final rows = await _dao.getSegments(executionSetId);
      return Success(rows.map(_segmentToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load segments: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSetSegment>>> getSegmentsForExecution(
      int executionId) async {
    try {
      final rows = await _dao.getSegmentsForExecution(executionId);
      return Success(rows.map(_segmentToDomain).toList());
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load segments for execution: $e'));
    }
  }

  @override
  Future<Result<void>> saveSegments(
    int executionSetId,
    List<domain.ExecutionSetSegment> segments,
  ) async {
    try {
      await _dao.replaceSegments(
        executionSetId,
        segments
            .map((s) => ExecutionSetSegmentsCompanion.insert(
                  executionSetId: executionSetId,
                  segmentOrder: s.segmentOrder,
                  reps: s.reps,
                  weight: Value(s.weight),
                ))
            .toList(),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to save segments: $e'));
    }
  }
}
