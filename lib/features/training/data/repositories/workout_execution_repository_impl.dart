import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/execution_comparison.dart';
import '../../../profile/domain/repositories/body_metric_repository.dart';
import '../../domain/entities/execution_set.dart' as domain;
import '../../domain/entities/execution_set_segment.dart' as domain;
import '../../domain/entities/workout_execution.dart' as domain;
import '../../domain/enums/load_mode.dart';
import '../../domain/helpers/training_metrics.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/daos/workout_execution_dao.dart';

class WorkoutExecutionRepositoryImpl implements WorkoutExecutionRepository {
  final WorkoutExecutionDao _dao;
  final ExerciseRepository? _exerciseRepository;
  final WorkoutRepository? _workoutRepository;
  final BodyMetricRepository? _bodyMetricRepository;

  WorkoutExecutionRepositoryImpl(
    this._dao, {
    ExerciseRepository? exerciseRepository,
    WorkoutRepository? workoutRepository,
    BodyMetricRepository? bodyMetricRepository,
  }) : _exerciseRepository = exerciseRepository,
       _workoutRepository = workoutRepository,
       _bodyMetricRepository = bodyMetricRepository;

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
    int workoutId,
  ) async {
    try {
      final rows = await _dao.getByWorkout(workoutId);
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load executions for workout: $e'),
      );
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
        DatabaseException('Failed to load last finished execution: $e'),
      );
    }
  }

  @override
  Future<Result<ExecutionComparison?>> getLastTwoFinishedWithVolume(
    int workoutId,
  ) async {
    try {
      final byWorkout = await _dao.getByWorkout(workoutId);
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

  /// Loads sets for [executionId] and attaches drop-set segments. Mirrors the
  /// presentation-side `executionSetsWithSegments` provider so server-side
  /// consumers (volume comparisons, future analytics) see the full picture.
  Future<List<domain.ExecutionSet>> _setsWithSegments(int executionId) async {
    final sets = (await getSets(executionId)).getOrThrow();
    final segments = (await getSegmentsForExecution(executionId)).getOrThrow();

    if (segments.isEmpty) return sets;

    final segmentsBySetId = <int, List<domain.ExecutionSetSegment>>{};
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
        duration: s.duration,
        distance: s.distance,
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
      final rows = await _dao.getDangling();
      return Success(rows.map(_executionToDomain).toList());
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load dangling executions: $e'),
      );
    }
  }

  @override
  Future<Result<void>> deleteUnfinishedByWorkout(int workoutId) async {
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
  Future<Result<int>> start(
    int workoutId, {
    required int programId,
    String? exerciseConfigSnapshot,
  }) async {
    try {
      final id = await _dao.create(
        WorkoutExecutionsCompanion.insert(
          workoutId: workoutId,
          programId: programId,
          startedAt: Value(DateTime.now()),
          exerciseConfigSnapshot: Value(exerciseConfigSnapshot),
        ),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to start execution: $e'));
    }
  }

  @override
  Future<Result<void>> finish(int executionId) async {
    try {
      await _dao.finish(executionId);
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
          plannedReps: Value(set.plannedReps),
          plannedWeight: Value(set.plannedWeight),
          reps: Value(set.reps),
          weight: Value(set.weight),
          duration: Value(set.duration),
          distance: Value(set.distance),
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
          duration: Value(set.duration),
          distance: Value(set.distance),
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
  Future<Result<Map<int, double>>> getLastWeightsForExercises(
    List<int> exerciseIds,
  ) async {
    try {
      final weights = await _dao.getLastWeightsForExercises(exerciseIds);
      return Success(weights);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load last weights: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getLastCompletedSetsForExercise(
    int exerciseId,
  ) async {
    try {
      final rows = await _dao.getLastCompletedSetsForExercise(exerciseId);
      return Success(
        rows
            .map(
              (r) => domain.ExecutionSet(
                id: r.id,
                executionId: r.executionId,
                exerciseId: r.exerciseId,
                setNumber: r.setNumber,
                plannedReps: r.plannedReps,
                plannedWeight: r.plannedWeight,
                reps: r.reps,
                weight: r.weight,
                duration: r.duration,
                distance: r.distance,
                isCompleted: r.isCompleted,
                isWarmup: r.isWarmup,
                rpe: r.rpe,
              ),
            )
            .toList(),
      );
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load last sets: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExecutionSet>>> getAllCompletedSetsForExercise(
    int exerciseId,
  ) async {
    try {
      final rows = await _dao.getAllCompletedSetsForExercise(exerciseId);
      return Success(
        rows
            .map(
              (r) => domain.ExecutionSet(
                id: r.id,
                executionId: r.executionId,
                exerciseId: r.exerciseId,
                setNumber: r.setNumber,
                plannedReps: r.plannedReps,
                plannedWeight: r.plannedWeight,
                reps: r.reps,
                weight: r.weight,
                duration: r.duration,
                distance: r.distance,
                isCompleted: r.isCompleted,
                isWarmup: r.isWarmup,
                rpe: r.rpe,
              ),
            )
            .toList(),
      );
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

    final bySetId = <int, List<domain.ExecutionSetSegment>>{};
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
        duration: s.duration,
        distance: s.distance,
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
  getCompletedSetsWithDateForExercise(int exerciseId) async {
    try {
      final rows = await _dao.getCompletedSetsWithDateForExercise(exerciseId);
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

  domain.WorkoutExecution _executionToDomain(dynamic row) =>
      domain.WorkoutExecution(
        id: row.id as int,
        workoutId: row.workoutId as int,
        programId: row.programId as int,
        startedAt: row.startedAt as DateTime,
        finishedAt: row.finishedAt as DateTime?,
        exerciseConfigSnapshot: row.exerciseConfigSnapshot as String?,
      );

  domain.ExecutionSet _setToDomain(dynamic row) => domain.ExecutionSet(
    id: row.id as int,
    executionId: row.executionId as int,
    exerciseId: row.exerciseId as int,
    setNumber: row.setNumber as int,
    plannedReps: row.plannedReps as int?,
    plannedWeight: row.plannedWeight as double?,
    reps: row.reps as int?,
    weight: row.weight as double?,
    duration: row.duration as int?,
    distance: row.distance as double?,
    isCompleted: row.isCompleted as bool,
    isWarmup: row.isWarmup as bool,
    rpe: row.rpe as int?,
    bodyWeightSnapshot: row.bodyWeightSnapshot as double?,
    loadModeOverride: row.loadModeOverride as LoadMode?,
    leftReps: row.leftReps as int?,
    leftWeight: row.leftWeight as double?,
    rightReps: row.rightReps as int?,
    rightWeight: row.rightWeight as double?,
    isUnilateral: row.isUnilateral as bool?,
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
    int executionSetId,
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
    int executionId,
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
    int executionSetId,
    List<domain.ExecutionSetSegment> segments,
  ) async {
    try {
      await _dao.replaceSegments(
        executionSetId,
        segments
            .map(
              (s) => ExecutionSetSegmentsCompanion.insert(
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
