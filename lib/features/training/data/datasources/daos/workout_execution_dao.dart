import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/execution_set_segments_table.dart';
import '../tables/execution_sets_table.dart';
import '../tables/workout_executions_table.dart';
import '../tables/workouts_table.dart';

part 'workout_execution_dao.g.dart';

@DriftAccessor(
    tables: [WorkoutExecutions, ExecutionSets, ExecutionSetSegments, Workouts])
class WorkoutExecutionDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutExecutionDaoMixin {
  WorkoutExecutionDao(super.db);

  Future<List<WorkoutExecution>> getAll() =>
      (select(workoutExecutions)
            ..where((e) => e.finishedAt.isNotNull())
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  /// Returns the most recently finished execution, or null.
  Future<WorkoutExecution?> getLastFinished() => (select(workoutExecutions)
        ..where((e) => e.finishedAt.isNotNull())
        ..orderBy([(e) => OrderingTerm.desc(e.finishedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<List<WorkoutExecution>> getByWorkout(int workoutId) =>
      (select(workoutExecutions)
            ..where((e) => e.workoutId.equals(workoutId))
            ..orderBy([(e) => OrderingTerm.desc(e.startedAt)]))
          .get();

  Future<WorkoutExecution?> getById(int id) =>
      (select(workoutExecutions)..where((e) => e.id.equals(id)))
          .getSingleOrNull();

  Future<int> create(WorkoutExecutionsCompanion entry) =>
      into(workoutExecutions).insert(entry);

  Future<void> finish(int id, {String? notes}) =>
      (update(workoutExecutions)..where((e) => e.id.equals(id))).write(
        WorkoutExecutionsCompanion(
          finishedAt: Value(DateTime.now()),
          notes: Value(notes),
        ),
      );

  Future<void> deleteById(int id) async {
    final setIds = await (select(executionSets)
          ..where((s) => s.executionId.equals(id)))
        .map((s) => s.id)
        .get();

    if (setIds.isNotEmpty) {
      await (delete(executionSetSegments)
            ..where((seg) => seg.executionSetId.isIn(setIds)))
          .go();
    }

    await (delete(executionSets)
          ..where((s) => s.executionId.equals(id)))
        .go();
    await (delete(workoutExecutions)..where((e) => e.id.equals(id))).go();
  }

  /// Returns the last recorded weight per exercise from finished executions.
  Future<Map<int, double>> getLastWeightsForExercises(
      List<int> exerciseIds) async {
    if (exerciseIds.isEmpty) return {};

    final result = <int, double>{};
    for (final exerciseId in exerciseIds) {
      final row = await (select(executionSets).join([
        innerJoin(workoutExecutions,
            workoutExecutions.id.equalsExp(executionSets.executionId)),
      ])
            ..where(executionSets.exerciseId.equals(exerciseId) &
                executionSets.isCompleted.equals(true) &
                executionSets.weight.isNotNull() &
                workoutExecutions.finishedAt.isNotNull())
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

  Future<List<ExecutionSetSegment>> getSegmentsForExecution(
      int executionId) async {
    final setIds = await (select(executionSets)
          ..where((s) => s.executionId.equals(executionId)))
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
      List<ExecutionSetSegmentsCompanion> entries) async {
    await batch((b) => b.insertAll(executionSetSegments, entries));
  }

  Future<void> deleteSegments(int executionSetId) =>
      (delete(executionSetSegments)
            ..where((s) => s.executionSetId.equals(executionSetId)))
          .go();

  Future<void> replaceSegments(
    int executionSetId,
    List<ExecutionSetSegmentsCompanion> entries,
  ) async {
    await deleteSegments(executionSetId);
    await insertSegments(entries);
  }
}
