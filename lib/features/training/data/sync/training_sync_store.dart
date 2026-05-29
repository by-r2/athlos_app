import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';

/// Local read/write helpers for UUID-first user-owned training sync.
class TrainingSyncStore {
  TrainingSyncStore(this._db);

  final AppDatabase _db;

  Future<int> countDirty(String userId) async {
    final result = await _db.customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM exercises WHERE created_by = ?1 AND is_verified = 0 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM workouts WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM workout_exercises WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM programs WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM progression_rules WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM cycle_steps WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM workout_executions WHERE user_id = ?1 AND is_dirty = 1) +
        (SELECT COUNT(*) FROM execution_sets WHERE user_id = ?1 AND is_dirty = 1)
        AS total
      ''',
      variables: [Variable.withString(userId)],
    ).getSingle();
    return result.read<int>('total');
  }

  // --- Exercises (user custom only) ---

  Future<List<Exercise>> getDirtyExercises(String userId) => (_db.select(_db.exercises)
        ..where(
          (e) =>
              e.createdBy.equals(userId) &
              e.isVerified.equals(false) &
              e.isDirty.equals(true) &
              e.deletedAt.isNull(),
        ))
      .get();

  Future<List<Exercise>> getDirtyTombstonesExercises(String userId) =>
      (_db.select(_db.exercises)
            ..where(
              (e) =>
                  e.createdBy.equals(userId) &
                  e.isVerified.equals(false) &
                  e.isDirty.equals(true) &
                  e.deletedAt.isNotNull(),
            ))
          .get();

  Future<Exercise?> getExerciseById(String id) =>
      (_db.select(_db.exercises)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<void> upsertExerciseFromRemote(ExercisesCompanion entry) =>
      _db.into(_db.exercises).insertOnConflictUpdate(entry);

  Future<void> markExerciseClean(String id) =>
      (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
          .write(const ExercisesCompanion(isDirty: Value(false)));

  Future<void> hardDeleteExercise(String id) =>
      (_db.delete(_db.exercises)..where((e) => e.id.equals(id))).go();

  // --- Workouts ---

  Future<List<Workout>> getDirtyWorkouts(String userId) => (_db.select(_db.workouts)
        ..where(
          (w) =>
              w.userId.equals(userId) &
              w.isDraft.equals(false) &
              w.isDirty.equals(true) &
              w.deletedAt.isNull(),
        ))
      .get();

  Future<List<Workout>> getDirtyTombstonesWorkouts(String userId) =>
      (_db.select(_db.workouts)
            ..where(
              (w) =>
                  w.userId.equals(userId) &
                  w.isDraft.equals(false) &
                  w.isDirty.equals(true) &
                  w.deletedAt.isNotNull(),
            ))
          .get();

  Future<Workout?> getWorkoutById(String id) =>
      (_db.select(_db.workouts)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<void> upsertWorkoutFromRemote(WorkoutsCompanion entry) =>
      _db.into(_db.workouts).insertOnConflictUpdate(entry);

  Future<void> markWorkoutClean(String id) =>
      (_db.update(_db.workouts)..where((w) => w.id.equals(id)))
          .write(const WorkoutsCompanion(isDirty: Value(false)));

  Future<void> hardDeleteWorkout(String id) =>
      (_db.delete(_db.workouts)..where((w) => w.id.equals(id))).go();

  // --- Workout exercises ---

  Future<List<WorkoutExercise>> getDirtyWorkoutExercises(String userId) async {
    final rows = await (_db.select(_db.workoutExercises)
          ..where(
            (we) =>
                we.userId.equals(userId) &
                we.isDirty.equals(true) &
                we.deletedAt.isNull(),
          ))
        .get();
    return _excludeExercisesForDraftWorkouts(rows);
  }

  Future<List<WorkoutExercise>> getDirtyTombstonesWorkoutExercises(
    String userId,
  ) async {
    final rows = await (_db.select(_db.workoutExercises)
          ..where(
            (we) =>
                we.userId.equals(userId) &
                we.isDirty.equals(true) &
                we.deletedAt.isNotNull(),
          ))
        .get();
    return _excludeExercisesForDraftWorkouts(rows);
  }

  Future<List<WorkoutExercise>> _excludeExercisesForDraftWorkouts(
    List<WorkoutExercise> rows,
  ) async {
    if (rows.isEmpty) return rows;
    final result = <WorkoutExercise>[];
    for (final row in rows) {
      final workout = await getWorkoutById(row.workoutId);
      if (workout?.isDraft != true) result.add(row);
    }
    return result;
  }

  /// In-progress sessions on local draft workouts are not pushed to the cloud.
  Future<bool> shouldSyncWorkoutExecution(WorkoutExecution execution) async {
    if (execution.finishedAt != null) return true;
    final workout = await getWorkoutById(execution.workoutId);
    return workout?.isDraft != true;
  }

  Future<bool> shouldSyncExecutionSet(ExecutionSet set) async {
    final execution = await getWorkoutExecutionById(set.executionId);
    if (execution == null) return false;
    return shouldSyncWorkoutExecution(execution);
  }

  Future<WorkoutExercise?> getWorkoutExerciseById(String id) => (_db.select(
        _db.workoutExercises,
      )..where((we) => we.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertWorkoutExerciseFromRemote(WorkoutExercisesCompanion entry) =>
      _db.into(_db.workoutExercises).insertOnConflictUpdate(entry);

  Future<void> markWorkoutExerciseClean(String id) =>
      (_db.update(_db.workoutExercises)..where((we) => we.id.equals(id)))
          .write(const WorkoutExercisesCompanion(isDirty: Value(false)));

  Future<void> hardDeleteWorkoutExercise(String id) =>
      (_db.delete(_db.workoutExercises)..where((we) => we.id.equals(id))).go();

  // --- Programs ---

  Future<List<Program>> getDirtyPrograms(String userId) => (_db.select(_db.programs)
        ..where(
          (p) =>
              p.userId.equals(userId) &
              p.isDirty.equals(true) &
              p.deletedAt.isNull(),
        ))
      .get();

  Future<List<Program>> getDirtyTombstonesPrograms(String userId) =>
      (_db.select(_db.programs)
            ..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.isDirty.equals(true) &
                  p.deletedAt.isNotNull(),
            ))
          .get();

  Future<Program?> getProgramById(String id) =>
      (_db.select(_db.programs)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> upsertProgramFromRemote(ProgramsCompanion entry) =>
      _db.into(_db.programs).insertOnConflictUpdate(entry);

  Future<void> markProgramClean(String id) =>
      (_db.update(_db.programs)..where((p) => p.id.equals(id)))
          .write(const ProgramsCompanion(isDirty: Value(false)));

  Future<void> hardDeleteProgram(String id) =>
      (_db.delete(_db.programs)..where((p) => p.id.equals(id))).go();

  // --- Progression rules ---

  Future<List<ProgressionRule>> getDirtyProgressionRules(String userId) =>
      (_db.select(_db.progressionRules)
            ..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.isDirty.equals(true) &
                  r.deletedAt.isNull(),
            ))
          .get();

  Future<List<ProgressionRule>> getDirtyTombstonesProgressionRules(String userId) =>
      (_db.select(_db.progressionRules)
            ..where(
              (r) =>
                  r.userId.equals(userId) &
                  r.isDirty.equals(true) &
                  r.deletedAt.isNotNull(),
            ))
          .get();

  Future<ProgressionRule?> getProgressionRuleById(String id) => (_db.select(
        _db.progressionRules,
      )..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertProgressionRuleFromRemote(ProgressionRulesCompanion entry) =>
      _db.into(_db.progressionRules).insertOnConflictUpdate(entry);

  Future<void> markProgressionRuleClean(String id) =>
      (_db.update(_db.progressionRules)..where((r) => r.id.equals(id)))
          .write(const ProgressionRulesCompanion(isDirty: Value(false)));

  Future<void> hardDeleteProgressionRule(String id) =>
      (_db.delete(_db.progressionRules)..where((r) => r.id.equals(id))).go();

  // --- Cycle steps ---

  Future<List<CycleStep>> getDirtyCycleSteps(String userId) => (_db.select(_db.cycleSteps)
        ..where(
          (s) =>
              s.userId.equals(userId) &
              s.isDirty.equals(true) &
              s.deletedAt.isNull(),
        ))
      .get();

  Future<List<CycleStep>> getDirtyTombstonesCycleSteps(String userId) =>
      (_db.select(_db.cycleSteps)
            ..where(
              (s) =>
                  s.userId.equals(userId) &
                  s.isDirty.equals(true) &
                  s.deletedAt.isNotNull(),
            ))
          .get();

  Future<CycleStep?> getCycleStepById(String id) =>
      (_db.select(_db.cycleSteps)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> upsertCycleStepFromRemote(CycleStepsCompanion entry) =>
      _db.into(_db.cycleSteps).insertOnConflictUpdate(entry);

  Future<void> markCycleStepClean(String id) =>
      (_db.update(_db.cycleSteps)..where((s) => s.id.equals(id)))
          .write(const CycleStepsCompanion(isDirty: Value(false)));

  Future<void> hardDeleteCycleStep(String id) =>
      (_db.delete(_db.cycleSteps)..where((s) => s.id.equals(id))).go();

  // --- Workout executions ---

  Future<List<WorkoutExecution>> getDirtyWorkoutExecutions(String userId) async {
    final rows = await (_db.select(_db.workoutExecutions)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.isDirty.equals(true) &
                e.deletedAt.isNull(),
          ))
        .get();
    final result = <WorkoutExecution>[];
    for (final row in rows) {
      if (await shouldSyncWorkoutExecution(row)) result.add(row);
    }
    return result;
  }

  Future<List<WorkoutExecution>> getDirtyTombstonesWorkoutExecutions(
    String userId,
  ) async {
    final rows = await (_db.select(_db.workoutExecutions)
          ..where(
            (e) =>
                e.userId.equals(userId) &
                e.isDirty.equals(true) &
                e.deletedAt.isNotNull(),
          ))
        .get();
    final result = <WorkoutExecution>[];
    for (final row in rows) {
      if (await shouldSyncWorkoutExecution(row)) result.add(row);
    }
    return result;
  }

  Future<WorkoutExecution?> getWorkoutExecutionById(String id) => (_db.select(
        _db.workoutExecutions,
      )..where((e) => e.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertWorkoutExecutionFromRemote(WorkoutExecutionsCompanion entry) =>
      _db.into(_db.workoutExecutions).insertOnConflictUpdate(entry);

  Future<void> markWorkoutExecutionClean(String id) =>
      (_db.update(_db.workoutExecutions)..where((e) => e.id.equals(id)))
          .write(const WorkoutExecutionsCompanion(isDirty: Value(false)));

  Future<void> hardDeleteWorkoutExecution(String id) =>
      (_db.delete(_db.workoutExecutions)..where((e) => e.id.equals(id))).go();

  // --- Execution sets ---

  Future<List<ExecutionSet>> getDirtyExecutionSets(String userId) async {
    final rows = await (_db.select(_db.executionSets)
          ..where(
            (s) =>
                s.userId.equals(userId) &
                s.isDirty.equals(true) &
                s.deletedAt.isNull(),
          ))
        .get();
    final result = <ExecutionSet>[];
    for (final row in rows) {
      if (await shouldSyncExecutionSet(row)) result.add(row);
    }
    return result;
  }

  Future<List<ExecutionSet>> getDirtyTombstonesExecutionSets(String userId) async {
    final rows = await (_db.select(_db.executionSets)
          ..where(
            (s) =>
                s.userId.equals(userId) &
                s.isDirty.equals(true) &
                s.deletedAt.isNotNull(),
          ))
        .get();
    final result = <ExecutionSet>[];
    for (final row in rows) {
      if (await shouldSyncExecutionSet(row)) result.add(row);
    }
    return result;
  }

  Future<ExecutionSet?> getExecutionSetById(String id) => (_db.select(
        _db.executionSets,
      )..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  Future<void> upsertExecutionSetFromRemote(ExecutionSetsCompanion entry) =>
      _db.into(_db.executionSets).insertOnConflictUpdate(entry);

  Future<void> markExecutionSetClean(String id) =>
      (_db.update(_db.executionSets)..where((s) => s.id.equals(id)))
          .write(const ExecutionSetsCompanion(isDirty: Value(false)));

  Future<void> hardDeleteExecutionSet(String id) =>
      (_db.delete(_db.executionSets)..where((s) => s.id.equals(id))).go();

  // --- Execution set segments (no is_dirty; keyed by set) ---

  Future<List<ExecutionSetSegment>> getSegmentsForSet(String setId) =>
      (_db.select(_db.executionSetSegments)
            ..where((seg) => seg.executionSetId.equals(setId))
            ..orderBy([(seg) => OrderingTerm.asc(seg.segmentOrder)]))
          .get();

  Future<void> replaceSegmentsForSet(
    String setId,
    List<ExecutionSetSegmentsCompanion> segments,
  ) async {
    await (_db.delete(_db.executionSetSegments)
          ..where((seg) => seg.executionSetId.equals(setId)))
        .go();
    for (final segment in segments) {
      await _db.into(_db.executionSetSegments).insertOnConflictUpdate(segment);
    }
  }

  Future<void> deleteSegmentsForSet(String setId) => (_db.delete(
        _db.executionSetSegments,
      )..where((seg) => seg.executionSetId.equals(setId)))
          .go();
}
