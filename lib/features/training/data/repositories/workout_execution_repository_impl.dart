import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/uuid.dart';
import '../../domain/entities/execution_comparison.dart';
import '../../domain/entities/execution_context_fallback.dart';
import '../../../profile/domain/repositories/body_metric_repository.dart';
import '../../domain/entities/execution_set.dart' as domain;
import '../../domain/entities/execution_set_segment.dart' as domain;
import '../../domain/entities/workout_execution.dart' as domain;
import '../../domain/enums/session_kind.dart';
import '../../domain/helpers/training_metrics.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/daos/workout_execution_dao.dart';

class WorkoutExecutionRepositoryImpl implements WorkoutExecutionRepository {
  WorkoutExecutionRepositoryImpl(
    this._dao,
    this._userId, {
    ExerciseRepository? exerciseRepository,
    WorkoutRepository? workoutRepository,
    BodyMetricRepository? bodyMetricRepository,
  }) : _exerciseRepository = exerciseRepository,
       _workoutRepository = workoutRepository,
       _bodyMetricRepository = bodyMetricRepository;

  final WorkoutExecutionDao _dao;
  final String _userId;
  final ExerciseRepository? _exerciseRepository;
  final WorkoutRepository? _workoutRepository;
  final BodyMetricRepository? _bodyMetricRepository;

  @override
  Future<Result<List<domain.WorkoutExecution>>> getAll() async {
    try {
      final rows = await _dao.getAll(_userId);
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load executions: $e'));
    }
  }

  @override
  Future<Result<int>> countFinished() async {
    try {
      final count = await _dao.countFinished(_userId);
      return Success(count);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to count finished executions: $e'));
    }
  }

  @override
  Future<Result<List<domain.WorkoutExecution>>> getByWorkout(
    String workoutId,
  ) async {
    try {
      final rows = await _dao.getByWorkout(workoutId, _userId);
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load executions for workout: $e'),
      );
    }
  }

  @override
  Future<Result<domain.WorkoutExecution?>> getById(String id) async {
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
      final row = await _dao.getLastFinished(_userId);
      return Success(row != null ? _executionToDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load last finished execution: $e'),
      );
    }
  }

  @override
  Future<Result<domain.WorkoutExecution?>> getLastFinishedForCycle({
    required String programId,
    required List<String> cycleWorkoutIds,
  }) async {
    try {
      final row = await _dao.getLastFinishedForCycle(
        userId: _userId,
        programId: programId,
        cycleWorkoutIds: cycleWorkoutIds,
      );
      return Success(row != null ? _executionToDomain(row) : null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load last cycle execution: $e'),
      );
    }
  }

  @override
  Future<Result<ExecutionComparison?>> getLastTwoFinishedWithVolume(
    String workoutId,
  ) async {
    try {
      final byWorkout = await _dao.getByWorkout(workoutId, _userId);
      final finished = byWorkout
          .where((e) => e.finishedAt != null)
          .take(2)
          .toList();
      if (finished.length < 2) return const Success(null);

      final last = _executionToDomain(finished[0]);
      final previous = _executionToDomain(finished[1]);

      final volumeLast = await _volumeForExecution(last);
      final volumePrevious = await _volumeForExecution(previous);

      return Success(
        ExecutionComparison(
          last: last,
          previous: previous,
          volumeLast: volumeLast,
          volumePrevious: volumePrevious,
        ),
      );
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load last two executions with volume: $e'),
      );
    }
  }

  Future<double> _volumeForExecution(domain.WorkoutExecution exec) async {
    final sets = await _setsWithSegments(exec.id);
    final exerciseRepo = _exerciseRepository;
    final workoutRepo = _workoutRepository;
    final bodyMetricRepo = _bodyMetricRepository;
    if (exerciseRepo == null || workoutRepo == null || bodyMetricRepo == null) {
      return computeTotalVolume(sets);
    }

    final exercisesResult = await exerciseRepo.getAll();
    final workoutWeResult = await workoutRepo.getExercises(exec.workoutId);
    if (!exercisesResult.isSuccess || !workoutWeResult.isSuccess) {
      return computeTotalVolume(sets);
    }
    final exerciseById = {
      for (final e in exercisesResult.getOrThrow()) e.id: e,
    };
    final workoutExerciseByExerciseId = {
      for (final we in workoutWeResult.getOrThrow()) we.exerciseId: we,
    };

    final historical = (await bodyMetricRepo.getLatestAtOrBefore(
      exec.startedAt,
    )).getOrThrow()?.weight;
    final latest = (await bodyMetricRepo.getLatest()).getOrThrow()?.weight;

    return computeTotalVolume(
      sets,
      exerciseById: exerciseById,
      workoutExerciseByExerciseId: workoutExerciseByExerciseId,
      profileBodyWeightOnExecutionDate: historical,
      latestBodyWeight: latest,
    );
  }

  Future<List<domain.ExecutionSet>> _setsWithSegments(
    String executionId,
  ) async {
    final sets = (await getSets(executionId)).getOrThrow();
    final segments = (await getSegmentsForExecution(executionId)).getOrThrow();

    if (segments.isEmpty) return sets;

    final segmentsBySetId = <String, List<domain.ExecutionSetSegment>>{};
    for (final seg in segments) {
      segmentsBySetId.putIfAbsent(seg.executionSetId, () => []).add(seg);
    }

    return sets.map((s) {
      final attached = segmentsBySetId[s.id];
      if (attached == null || attached.isEmpty) return s;
      return domain.ExecutionSet(
        id: s.id,
        executionId: s.executionId,
        exerciseId: s.exerciseId,
        setNumber: s.setNumber,
        plannedReps: s.plannedReps,
        plannedWeight: s.plannedWeight,
        reps: s.reps,
        weight: s.weight,
        durationSeconds: s.durationSeconds,
        distanceMeters: s.distanceMeters,
        isCompleted: s.isCompleted,
        isWarmup: s.isWarmup,
        rpe: s.rpe,
        bodyWeightSnapshot: s.bodyWeightSnapshot,
        loadModeOverride: s.loadModeOverride,
        leftReps: s.leftReps,
        leftWeight: s.leftWeight,
        rightReps: s.rightReps,
        rightWeight: s.rightWeight,
        isUnilateral: s.isUnilateral,
        segments: attached,
      );
    }).toList();
  }

  @override
  Future<Result<List<domain.WorkoutExecution>>> getDangling() async {
    try {
      final rows = await _dao.getDangling(_userId);
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load dangling executions: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteUnfinishedByWorkout(String workoutId) async {
    try {
      await _dao.deleteUnfinishedByWorkout(workoutId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException(
          'Failed to delete unfinished executions for workout $workoutId: $e',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteOrphaned() async {
    try {
      await _dao.deleteOrphaned();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to delete orphaned executions: $e'),
      );
    }
  }

  @override
  Future<Result<String>> start(
    String workoutId, {
    String? programId,
    SessionKind sessionKind = SessionKind.planned,
  }) async {
    try {
      final id = generateUuidV4();
      await _dao.create(
        WorkoutExecutionsCompanion.insert(
          id: id,
          userId: _userId,
          workoutId: workoutId,
          programId: programId ?? '',
          sessionKind: Value(sessionKind),
          startedAt: Value(DateTime.now()),
        ),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to start execution: $e'));
    }
  }

  @override
  Future<Result<void>> finish(String executionId) async {
    try {
      await _dao.finish(executionId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to finish execution: $e'));
    }
  }

  @override
  Future<Result<void>> finishWithSnapshot({
    required String executionId,
    required String workoutNameSnapshot,
    String? programNameSnapshot,
    required ExecutionContextFallback contextFallback,
  }) async {
    try {
      await _dao.finishWithSnapshot(
        executionId,
        workoutNameSnapshot: workoutNameSnapshot,
        programNameSnapshot: programNameSnapshot,
        contextFallback: contextFallback,
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to finish execution with snapshot: $e'),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final execution = await _dao.getById(id);
      if (execution != null) {
        final workoutRepo = _workoutRepository;
        if (workoutRepo == null) {
          await _dao.deleteById(id);
          return const Success(null);
        }
        final workout =
            (await workoutRepo.getById(execution.workoutId)).getOrThrow();
        if (workout?.isDraft == true && execution.finishedAt == null) {
          await _dao.hardDeleteSession(id);
          return const Success(null);
        }
      }
      await _dao.deleteById(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete execution $id: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getSets(String executionId) async {
    try {
      final rows = await _dao.getSets(executionId);
      return Success(rows.map(_setToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load sets: $e'));
    }
  }

  @override
  Future<Result<String>> logSet(domain.ExecutionSet set) async {
    try {
      final setId = set.id.isEmpty ? generateUuidV4() : set.id;
      await _dao.insertSet(
        ExecutionSetsCompanion.insert(
          id: setId,
          userId: _userId,
          executionId: set.executionId,
          exerciseId: set.exerciseId,
          setNumber: set.setNumber,
          plannedReps: Value(set.plannedReps),
          plannedWeight: Value(set.plannedWeight),
          reps: Value(set.reps),
          weight: Value(set.weight),
          durationSeconds: Value(set.durationSeconds),
          distanceMeters: Value(set.distanceMeters),
          isCompleted: Value(set.isCompleted),
          isWarmup: Value(set.isWarmup),
          rpe: Value(set.rpe),
          bodyWeightSnapshot: Value(set.bodyWeightSnapshot),
          loadModeOverride: Value(set.loadModeOverride),
          leftReps: Value(set.leftReps),
          leftWeight: Value(set.leftWeight),
          rightReps: Value(set.rightReps),
          rightWeight: Value(set.rightWeight),
          isUnilateral: Value(set.isUnilateral),
        ),
      );
      return Success(setId);
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
          durationSeconds: Value(set.durationSeconds),
          distanceMeters: Value(set.distanceMeters),
          isCompleted: Value(set.isCompleted),
          isWarmup: Value(set.isWarmup),
          rpe: Value(set.rpe),
          bodyWeightSnapshot: Value(set.bodyWeightSnapshot),
          loadModeOverride: Value(set.loadModeOverride),
          leftReps: Value(set.leftReps),
          leftWeight: Value(set.leftWeight),
          rightReps: Value(set.rightReps),
          rightWeight: Value(set.rightWeight),
          isUnilateral: Value(set.isUnilateral),
        ),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update set: $e'));
    }
  }

  @override
  Future<Result<Map<String, double>>> getLastWeightsForExercises(
    List<String> exerciseIds,
  ) async {
    try {
      final weights = await _dao.getLastWeightsForExercises(exerciseIds, _userId);
      return Success(weights);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load last weights: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getLastCompletedSetsForExercise(
    String exerciseId,
  ) async {
    try {
      final rows = await _dao.getLastCompletedSetsForExercise(exerciseId, _userId);
      return Success(rows.map(_setToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load last sets: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getAllCompletedSetsForExercise(
    String exerciseId,
  ) async {
    try {
      final rows = await _dao.getAllCompletedSetsForExercise(exerciseId, _userId);
      return Success(rows.map(_setToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load all sets: $e'));
    }
  }

  Future<List<domain.ExecutionSet>> _attachSegmentsIfAny(
    List<domain.ExecutionSet> sets,
  ) async {
    if (sets.isEmpty) return sets;
    final ids = sets.map((s) => s.id).toList();
    final raw = await _dao.getSegmentsForExecutionSetIds(ids);
    if (raw.isEmpty) return sets;

    final bySetId = <String, List<domain.ExecutionSetSegment>>{};
    for (final row in raw) {
      final d = _segmentToDomain(row);
      bySetId.putIfAbsent(d.executionSetId, () => []).add(d);
    }
    return sets.map((s) {
      final attached = bySetId[s.id];
      if (attached == null || attached.isEmpty) return s;
      return domain.ExecutionSet(
        id: s.id,
        executionId: s.executionId,
        exerciseId: s.exerciseId,
        setNumber: s.setNumber,
        plannedReps: s.plannedReps,
        plannedWeight: s.plannedWeight,
        reps: s.reps,
        weight: s.weight,
        durationSeconds: s.durationSeconds,
        distanceMeters: s.distanceMeters,
        isCompleted: s.isCompleted,
        isWarmup: s.isWarmup,
        rpe: s.rpe,
        bodyWeightSnapshot: s.bodyWeightSnapshot,
        loadModeOverride: s.loadModeOverride,
        leftReps: s.leftReps,
        leftWeight: s.leftWeight,
        rightReps: s.rightReps,
        rightWeight: s.rightWeight,
        isUnilateral: s.isUnilateral,
        segments: attached,
      );
    }).toList();
  }

  @override
  Future<Result<List<({domain.ExecutionSet set, DateTime date})>>>
  getCompletedSetsWithDateForExercise(String exerciseId) async {
    try {
      final rows = await _dao.getCompletedSetsWithDateForExercise(
        exerciseId,
        _userId,
      );
      if (rows.isEmpty) return const Success([]);

      final domainSets = rows.map((r) => _setToDomain(r.set)).toList();
      final hydrated = await _attachSegmentsIfAny(domainSets);

      return Success([
        for (var i = 0; i < rows.length; i++)
          (set: hydrated[i], date: rows[i].date),
      ]);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load sets with date: $e'));
    }
  }

  domain.WorkoutExecution _executionToDomain(WorkoutExecution row) =>
      domain.WorkoutExecution(
        id: row.id,
        workoutId: row.workoutId,
        programId: row.programId,
        sessionKind: row.sessionKind,
        startedAt: row.startedAt,
        finishedAt: row.finishedAt,
        workoutNameSnapshot: row.workoutNameSnapshot,
        programNameSnapshot: row.programNameSnapshot,
        contextFallback: row.contextFallback,
      );

  domain.ExecutionSet _setToDomain(ExecutionSet row) => domain.ExecutionSet(
    id: row.id,
    executionId: row.executionId,
    exerciseId: row.exerciseId,
    setNumber: row.setNumber,
    plannedReps: row.plannedReps,
    plannedWeight: row.plannedWeight,
    reps: row.reps,
    weight: row.weight,
    durationSeconds: row.durationSeconds,
    distanceMeters: row.distanceMeters,
    isCompleted: row.isCompleted,
    isWarmup: row.isWarmup,
    rpe: row.rpe,
    bodyWeightSnapshot: row.bodyWeightSnapshot,
    loadModeOverride: row.loadModeOverride,
    leftReps: row.leftReps,
    leftWeight: row.leftWeight,
    rightReps: row.rightReps,
    rightWeight: row.rightWeight,
    isUnilateral: row.isUnilateral,
  );

  domain.ExecutionSetSegment _segmentToDomain(ExecutionSetSegment row) =>
      domain.ExecutionSetSegment(
        id: row.id,
        executionSetId: row.executionSetId,
        segmentOrder: row.segmentOrder,
        reps: row.reps,
        weight: row.weight,
      );

  @override
  Future<Result<List<domain.ExecutionSetSegment>>> getSegments(
    String executionSetId,
  ) async {
    try {
      final rows = await _dao.getSegments(executionSetId);
      return Success(rows.map(_segmentToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load segments: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSetSegment>>> getSegmentsForExecution(
    String executionId,
  ) async {
    try {
      final rows = await _dao.getSegmentsForExecution(executionId);
      return Success(rows.map(_segmentToDomain).toList());
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load segments for execution: $e'),
      );
    }
  }

  @override
  Future<Result<void>> saveSegments(
    String executionSetId,
    List<domain.ExecutionSetSegment> segments,
  ) async {
    try {
      await _dao.replaceSegments(
        executionSetId,
        segments
            .map(
              (s) => ExecutionSetSegmentsCompanion.insert(
                id: s.id.isEmpty ? generateUuidV4() : s.id,
                executionSetId: executionSetId,
                segmentOrder: s.segmentOrder,
                reps: s.reps,
                weight: Value(s.weight),
              ),
            )
            .toList(),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to save segments: $e'));
    }
  }
}
