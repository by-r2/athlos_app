import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/execution_set_segments_table.dart';
import '../tables/execution_sets_table.dart';
import '../tables/workout_executions_table.dart';
import '../tables/workouts_table.dart';

part 'workout_execution_dao.g.dart';

@DriftAccessor(
  tables: [WorkoutExecutions, ExecutionSets, ExecutionSetSegments, Workouts],
)
class WorkoutExecutionDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutExecutionDaoMixin {
  WorkoutExecutionDao(super.db);

  Future<List<WorkoutExecution>> getAll() =>
      (select(workoutExecutions)
            ..where((e) => e.finishedAt.isNotNull())
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  /// Returns the most recently finished execution, or null.
  Future<WorkoutExecution?> getLastFinished() =>
      (select(workoutExecutions)
            ..where((e) => e.finishedAt.isNotNull())
            ..orderBy([(e) => OrderingTerm.desc(e.finishedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<WorkoutExecution>> getByWorkout(int workoutId) =>
      (select(workoutExecutions)
            ..where((e) => e.workoutId.equals(workoutId))
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  Future<WorkoutExecution?> getById(int id) => (select(
    workoutExecutions,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> create(WorkoutExecutionsCompanion entry) =>
      into(workoutExecutions).insert(entry);

  Future<void> finish(int id) =>
      (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
        WorkoutExecutionsCompanion(finishedAt: Value(DateTime.now())),
      );

  Future<void> updateExecution(int id, WorkoutExecutionsCompanion entry) =>
      (update(workoutExecutions)..where((e) => e.id.equals(id))).write(entry);

  /// Returns unfinished executions whose workout still exists.
  /// Used to offer resume/discard on app launch.
  Future<List<WorkoutExecution>> getDangling() =>
      (select(workoutExecutions)
            ..where((e) => e.finishedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  /// Deletes only **unfinished** executions (and their sets/segments) for a
  /// given workout. Finished executions are preserved as training history.
  Future<void> deleteUnfinishedByWorkout(int workoutId) async {
    final execIds =
        await (select(workoutExecutions)..where(
              (e) => e.workoutId.equals(workoutId) & e.finishedAt.isNull(),
            ))
            .map((e) => e.id)
            .get();
    if (execIds.isEmpty) return;

    final setIds = await (select(
      executionSets,
    )..where((s) => s.executionId.isIn(execIds))).map((s) => s.id).get();

    if (setIds.isNotEmpty) {
      await (delete(
        executionSetSegments,
      )..where((seg) => seg.executionSetId.isIn(setIds))).go();
    }
    await (delete(
      executionSets,
    )..where((s) => s.executionId.isIn(execIds))).go();
    await (delete(workoutExecutions)..where((e) => e.id.isIn(execIds))).go();
  }

  /// Deletes **unfinished** executions referencing workouts that no longer
  /// exist. Finished executions are kept as training history (they carry
  /// their own exercise config snapshot).
  Future<void> deleteOrphaned() async {
    final orphanedIds = await customSelect(
      'SELECT we.id FROM workout_executions we '
      'WHERE we.finished_at IS NULL '
      'AND we.workout_id NOT IN (SELECT id FROM workouts)',
    ).map((row) => row.read<int>('id')).get();
    if (orphanedIds.isEmpty) return;

    final setIds = await (select(
      executionSets,
    )..where((s) => s.executionId.isIn(orphanedIds))).map((s) => s.id).get();

    if (setIds.isNotEmpty) {
      await (delete(
        executionSetSegments,
      )..where((seg) => seg.executionSetId.isIn(setIds))).go();
    }
    await (delete(
      executionSets,
    )..where((s) => s.executionId.isIn(orphanedIds))).go();
    await (delete(
      workoutExecutions,
    )..where((e) => e.id.isIn(orphanedIds))).go();
  }

  Future<void> deleteById(int id) async {
    final setIds = await (select(
      executionSets,
    )..where((s) => s.executionId.equals(id))).map((s) => s.id).get();

    if (setIds.isNotEmpty) {
      await (delete(
        executionSetSegments,
      )..where((seg) => seg.executionSetId.isIn(setIds))).go();
    }

    await (delete(executionSets)..where((s) => s.executionId.equals(id))).go();
    await (delete(workoutExecutions)..where((e) => e.id.equals(id))).go();
  }

  /// Returns the last recorded weight per exercise from finished executions.
  Future<Map<int, double>> getLastWeightsForExercises(
    List<int> exerciseIds,
  ) async {
    if (exerciseIds.isEmpty) return {};

    final result = <int, double>{};
    for (final exerciseId in exerciseIds) {
      final row =
          await (select(executionSets).join([
                  innerJoin(
                    workoutExecutions,
                    workoutExecutions.id.equalsExp(executionSets.executionId),
                  ),
                ])
                ..where(
                  executionSets.exerciseId.equals(exerciseId) &
                      executionSets.isCompleted.equals(true) &
                      executionSets.weight.isNotNull() &
                      workoutExecutions.finishedAt.isNotNull(),
                )
                ..orderBy([
                  OrderingTerm.desc(workoutExecutions.startedAt),
                  OrderingTerm.desc(executionSets.setNumber),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (row != null) {
        result[exerciseId] = row.readTable(executionSets).weight!;
      }
    }
    return result;
  }

  /// Returns completed sets from the most recent finished execution
  /// that included [exerciseId]. Empty list if no history found.
  Future<List<ExecutionSet>> getLastCompletedSetsForExercise(
    int exerciseId,
  ) async {
    final lastExec =
        await (select(workoutExecutions).join([
                innerJoin(
                  executionSets,
                  executionSets.executionId.equalsExp(workoutExecutions.id),
                ),
              ])
              ..where(
                executionSets.exerciseId.equals(exerciseId) &
                    executionSets.isCompleted.equals(true) &
                    workoutExecutions.finishedAt.isNotNull(),
              )
              ..orderBy([OrderingTerm.desc(workoutExecutions.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (lastExec == null) return [];

    final execId = lastExec.readTable(workoutExecutions).id;
    return (select(executionSets)
          ..where(
            (s) =>
                s.executionId.equals(execId) &
                s.exerciseId.equals(exerciseId) &
                s.isCompleted.equals(true),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
        .get();
  }

  /// All completed sets for [exerciseId] across all finished
  /// executions. Used for PR detection and 1RM history.
  Future<List<ExecutionSet>> getAllCompletedSetsForExercise(
    int exerciseId,
  ) async {
    return (select(executionSets).join([
            innerJoin(
              workoutExecutions,
              workoutExecutions.id.equalsExp(executionSets.executionId),
            ),
          ])
          ..where(
            executionSets.exerciseId.equals(exerciseId) &
                executionSets.isCompleted.equals(true) &
                workoutExecutions.finishedAt.isNotNull(),
          )
          ..orderBy([OrderingTerm.desc(workoutExecutions.startedAt)]))
        .map((row) => row.readTable(executionSets))
        .get();
  }

  /// Returns completed sets for [exerciseId] paired with
  /// the execution's startedAt date (for charting over time).
  Future<List<({ExecutionSet set, DateTime date})>>
  getCompletedSetsWithDateForExercise(int exerciseId) async {
    final rows =
        await (select(executionSets).join([
                innerJoin(
                  workoutExecutions,
                  workoutExecutions.id.equalsExp(executionSets.executionId),
                ),
              ])
              ..where(
                executionSets.exerciseId.equals(exerciseId) &
                    executionSets.isCompleted.equals(true) &
                    workoutExecutions.finishedAt.isNotNull(),
              )
              ..orderBy([OrderingTerm.asc(workoutExecutions.startedAt)]))
            .get();
    return rows
        .map(
          (row) => (
            set: row.readTable(executionSets),
            date: row.readTable(workoutExecutions).startedAt,
          ),
        )
        .toList();
  }

  // --- Execution sets ---

  Future<List<ExecutionSet>> getSets(int executionId) =>
      (select(executionSets)
            ..where((s) => s.executionId.equals(executionId))
            ..orderBy([
              (s) => OrderingTerm.asc(s.exerciseId),
              (s) => OrderingTerm.asc(s.setNumber),
            ]))
          .get();

  Future<int> insertSet(ExecutionSetsCompanion entry) =>
      into(executionSets).insert(entry);

  Future<void> updateSet(int id, ExecutionSetsCompanion entry) =>
      (update(executionSets)..where((s) => s.id.equals(id))).write(entry);

  // --- Execution set segments (drop sets) ---

  Future<List<ExecutionSetSegment>> getSegments(int executionSetId) =>
      (select(executionSetSegments)
            ..where((s) => s.executionSetId.equals(executionSetId))
            ..orderBy([(s) => OrderingTerm.asc(s.segmentOrder)]))
          .get();

  /// Segments belonging to any of [executionSetIds] (bulk attach for charts/PR).
  Future<List<ExecutionSetSegment>> getSegmentsForExecutionSetIds(
    List<int> executionSetIds,
  ) async {
    if (executionSetIds.isEmpty) return [];
    return (select(executionSetSegments)
          ..where((s) => s.executionSetId.isIn(executionSetIds))
          ..orderBy([
            (s) => OrderingTerm.asc(s.executionSetId),
            (s) => OrderingTerm.asc(s.segmentOrder),
          ]))
        .get();
  }

  Future<List<ExecutionSetSegment>> getSegmentsForExecution(
    int executionId,
  ) async {
    final setIds = await (select(
      executionSets,
    )..where((s) => s.executionId.equals(executionId))).map((s) => s.id).get();
    if (setIds.isEmpty) return [];
    return (select(executionSetSegments)
          ..where((s) => s.executionSetId.isIn(setIds))
          ..orderBy([
            (s) => OrderingTerm.asc(s.executionSetId),
            (s) => OrderingTerm.asc(s.segmentOrder),
          ]))
        .get();
  }

  Future<void> insertSegments(
    List<ExecutionSetSegmentsCompanion> entries,
  ) async {
    await batch((b) => b.insertAll(executionSetSegments, entries));
  }

  Future<void> deleteSegments(int executionSetId) => (delete(
    executionSetSegments,
  )..where((s) => s.executionSetId.equals(executionSetId))).go();

  Future<void> replaceSegments(
    int executionSetId,
    List<ExecutionSetSegmentsCompanion> entries,
  ) async {
    await deleteSegments(executionSetId);
    await insertSegments(entries);
  }

  Future<List<WorkoutExecution>> getAllForSync() =>
      select(workoutExecutions).get();

  Future<List<ExecutionSet>> getAllSetsForSync() =>
      select(executionSets).get();

  Future<void> markExecutionSynced({
    required int id,
    required String remoteId,
    required DateTime syncedAt,
  }) =>
      (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
        WorkoutExecutionsCompanion(
          remoteId: Value(remoteId),
          lastSyncedAt: Value(syncedAt),
        ),
      );

  Future<void> markExecutionLocalDirty(int id) {
    final now = DateTime.now().toUtc();
    return (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
      WorkoutExecutionsCompanion(localUpdatedAt: Value(now)),
    );
  }

  Future<WorkoutExecution?> getExecutionByRemoteId(String remoteId) =>
      (select(workoutExecutions)..where((e) => e.remoteId.equals(remoteId)))
          .getSingleOrNull();

  Future<void> markSetSynced({
    required int id,
    required String remoteId,
    required DateTime syncedAt,
  }) =>
      (update(executionSets)..where((s) => s.id.equals(id))).write(
        ExecutionSetsCompanion(
          remoteId: Value(remoteId),
          lastSyncedAt: Value(syncedAt),
        ),
      );

  Future<void> markSetLocalDirty(int id) {
    final now = DateTime.now().toUtc();
    return (update(executionSets)..where((s) => s.id.equals(id))).write(
      ExecutionSetsCompanion(localUpdatedAt: Value(now)),
    );
  }

  Future<ExecutionSet?> getSetByRemoteId(String remoteId) =>
      (select(executionSets)..where((s) => s.remoteId.equals(remoteId)))
          .getSingleOrNull();
}
