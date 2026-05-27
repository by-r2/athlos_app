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

  Future<void> _markExecutionDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
      WorkoutExecutionsCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _markSetDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(executionSets)..where((s) => s.id.equals(id))).write(
      ExecutionSetsCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<WorkoutExecution>> getAll(String userId) =>
      (select(workoutExecutions)
            ..where(
              (e) =>
                  e.userId.equals(userId) &
                  e.finishedAt.isNotNull() &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  /// Total finished, non-deleted executions for [userId].
  Future<int> countFinished(String userId) async {
    final count = countAll(
      filter:
          workoutExecutions.userId.equals(userId) &
          workoutExecutions.finishedAt.isNotNull() &
          workoutExecutions.deletedAt.isNull(),
    );
    final query = selectOnly(workoutExecutions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<WorkoutExecution?> getLastFinished(String userId) =>
      (select(workoutExecutions)
            ..where(
              (e) =>
                  e.userId.equals(userId) &
                  e.finishedAt.isNotNull() &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.finishedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<WorkoutExecution>> getByWorkout(String workoutId, String userId) =>
      (select(workoutExecutions)
            ..where(
              (e) =>
                  e.userId.equals(userId) &
                  e.workoutId.equals(workoutId) &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  Future<WorkoutExecution?> getById(String id) =>
      (select(workoutExecutions)
            ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> create(WorkoutExecutionsCompanion entry) async {
    await into(workoutExecutions).insert(entry);
    await _markExecutionDirty(entry.id.value);
  }

  Future<void> finish(String id) async {
    await (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
      WorkoutExecutionsCompanion(finishedAt: Value(DateTime.now())),
    );
    await _markExecutionDirty(id);
  }

  Future<void> updateExecution(
    String id,
    WorkoutExecutionsCompanion entry,
  ) async {
    await (update(workoutExecutions)..where((e) => e.id.equals(id)))
        .write(entry);
    await _markExecutionDirty(id);
  }

  /// Returns unfinished, non-deleted executions.
  Future<List<WorkoutExecution>> getDangling(String userId) =>
      (select(workoutExecutions)
            ..where(
              (e) =>
                  e.userId.equals(userId) &
                  e.finishedAt.isNull() &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  /// Soft-deletes only **unfinished** executions (and their sets/segments) for
  /// a given workout. Finished executions are preserved as training history.
  Future<void> deleteUnfinishedByWorkout(String workoutId) async {
    final execIds =
        await (select(workoutExecutions)
              ..where(
                (e) =>
                    e.workoutId.equals(workoutId) &
                    e.finishedAt.isNull() &
                    e.deletedAt.isNull(),
              ))
            .map((e) => e.id)
            .get();
    if (execIds.isEmpty) return;

    await _softDeleteExecutionCascade(execIds);
  }

  /// Soft-deletes **unfinished** executions referencing workouts that no
  /// longer exist or are soft-deleted. Finished executions are kept.
  Future<void> deleteOrphaned() async {
    final orphanedIds = await customSelect(
      'SELECT we.id FROM workout_executions we '
      'WHERE we.finished_at IS NULL '
      'AND we.deleted_at IS NULL '
      'AND we.workout_id NOT IN '
      '(SELECT id FROM workouts WHERE deleted_at IS NULL)',
    ).map((row) => row.read<String>('id')).get();
    if (orphanedIds.isEmpty) return;

    await _softDeleteExecutionCascade(orphanedIds);
  }

  Future<void> deleteById(String id) =>
      _softDeleteExecutionCascade([id]);

  /// Cascading soft-delete: hard-deletes segments, soft-deletes sets and
  /// executions.
  Future<void> _softDeleteExecutionCascade(List<String> execIds) async {
    final now = DateTime.now().toUtc();

    final setIds =
        await (select(executionSets)
              ..where((s) => s.executionId.isIn(execIds)))
            .map((s) => s.id)
            .get();

    if (setIds.isNotEmpty) {
      await (delete(executionSetSegments)
            ..where((seg) => seg.executionSetId.isIn(setIds)))
          .go();
      await (update(executionSets)
            ..where((s) => s.executionId.isIn(execIds)))
          .write(
        ExecutionSetsCompanion(
          deletedAt: Value(now),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
    }

    await (update(workoutExecutions)
          ..where((e) => e.id.isIn(execIds)))
        .write(
      WorkoutExecutionsCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Returns the last recorded weight per exercise from finished executions.
  Future<Map<String, double>> getLastWeightsForExercises(
    List<String> exerciseIds,
    String userId,
  ) async {
    if (exerciseIds.isEmpty) return {};

    final result = <String, double>{};
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
                      executionSets.userId.equals(userId) &
                      executionSets.isCompleted.equals(true) &
                      executionSets.weight.isNotNull() &
                      executionSets.deletedAt.isNull() &
                      workoutExecutions.userId.equals(userId) &
                      workoutExecutions.finishedAt.isNotNull() &
                      workoutExecutions.deletedAt.isNull(),
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
    String exerciseId,
    String userId,
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
                    executionSets.userId.equals(userId) &
                    executionSets.isCompleted.equals(true) &
                    executionSets.deletedAt.isNull() &
                    workoutExecutions.userId.equals(userId) &
                    workoutExecutions.finishedAt.isNotNull() &
                    workoutExecutions.deletedAt.isNull(),
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
                s.isCompleted.equals(true) &
                s.deletedAt.isNull(),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
        .get();
  }

  /// All completed sets for [exerciseId] across all finished
  /// executions. Used for PR detection and 1RM history.
  Future<List<ExecutionSet>> getAllCompletedSetsForExercise(
    String exerciseId,
    String userId,
  ) async {
    return (select(executionSets).join([
              innerJoin(
                workoutExecutions,
                workoutExecutions.id.equalsExp(executionSets.executionId),
              ),
            ])
          ..where(
            executionSets.exerciseId.equals(exerciseId) &
                executionSets.userId.equals(userId) &
                executionSets.isCompleted.equals(true) &
                executionSets.deletedAt.isNull() &
                workoutExecutions.userId.equals(userId) &
                workoutExecutions.finishedAt.isNotNull() &
                workoutExecutions.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(workoutExecutions.startedAt)]))
        .map((row) => row.readTable(executionSets))
        .get();
  }

  /// Returns completed sets for [exerciseId] paired with
  /// the execution's startedAt date (for charting over time).
  Future<List<({ExecutionSet set, DateTime date})>>
      getCompletedSetsWithDateForExercise(String exerciseId, String userId) async {
    final rows =
        await (select(executionSets).join([
                  innerJoin(
                    workoutExecutions,
                    workoutExecutions.id.equalsExp(executionSets.executionId),
                  ),
                ])
              ..where(
                executionSets.exerciseId.equals(exerciseId) &
                    executionSets.userId.equals(userId) &
                    executionSets.isCompleted.equals(true) &
                    executionSets.deletedAt.isNull() &
                    workoutExecutions.userId.equals(userId) &
                    workoutExecutions.finishedAt.isNotNull() &
                    workoutExecutions.deletedAt.isNull(),
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

  Future<List<ExecutionSet>> getSets(String executionId) =>
      (select(executionSets)
            ..where(
              (s) =>
                  s.executionId.equals(executionId) & s.deletedAt.isNull(),
            )
            ..orderBy([
              (s) => OrderingTerm.asc(s.exerciseId),
              (s) => OrderingTerm.asc(s.setNumber),
            ]))
          .get();

  Future<void> insertSet(ExecutionSetsCompanion entry) async {
    await into(executionSets).insert(entry);
    await _markSetDirty(entry.id.value);
  }

  Future<void> updateSet(String id, ExecutionSetsCompanion entry) async {
    await (update(executionSets)..where((s) => s.id.equals(id))).write(entry);
    await _markSetDirty(id);
  }

  // --- Execution set segments (drop sets) ---

  Future<List<ExecutionSetSegment>> getSegments(String executionSetId) =>
      (select(executionSetSegments)
            ..where((s) => s.executionSetId.equals(executionSetId))
            ..orderBy([(s) => OrderingTerm.asc(s.segmentOrder)]))
          .get();

  Future<List<ExecutionSetSegment>> getSegmentsForExecutionSetIds(
    List<String> executionSetIds,
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
    String executionId,
  ) async {
    final setIds =
        await (select(executionSets)
              ..where(
                (s) =>
                    s.executionId.equals(executionId) & s.deletedAt.isNull(),
              ))
            .map((s) => s.id)
            .get();
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

  Future<void> deleteSegments(String executionSetId) =>
      (delete(executionSetSegments)
            ..where((s) => s.executionSetId.equals(executionSetId)))
          .go();

  Future<void> replaceSegments(
    String executionSetId,
    List<ExecutionSetSegmentsCompanion> entries,
  ) async {
    await deleteSegments(executionSetId);
    await insertSegments(entries);
    await _markSetDirty(executionSetId);
  }
}
