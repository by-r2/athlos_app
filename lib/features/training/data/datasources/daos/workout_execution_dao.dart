import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/execution_sets_table.dart';
import '../tables/workout_executions_table.dart';
import '../tables/workouts_table.dart';

part 'workout_execution_dao.g.dart';

@DriftAccessor(tables: [WorkoutExecutions, ExecutionSets, Workouts])
class WorkoutExecutionDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutExecutionDaoMixin {
  WorkoutExecutionDao(super.db);

  Future<List<WorkoutExecution>> getAll() =>
      (select(workoutExecutions)
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
    await (delete(executionSets)
          ..where((s) => s.executionId.equals(id)))
        .go();
    await (delete(workoutExecutions)..where((e) => e.id.equals(id))).go();
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
}
