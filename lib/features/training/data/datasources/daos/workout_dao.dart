import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/workout_exercises_table.dart';
import '../tables/workouts_table.dart';

part 'workout_dao.g.dart';

@DriftAccessor(tables: [Workouts, WorkoutExercises, Exercises])
class WorkoutDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutDaoMixin {
  WorkoutDao(super.db);

  Future<List<Workout>> getAll() => select(workouts).get();

  Future<List<Workout>> getActive() => (select(workouts)
        ..where((w) => w.isArchived.equals(false))
        ..orderBy([
          (w) => OrderingTerm.asc(w.sortOrder),
          (w) => OrderingTerm.asc(w.createdAt),
        ]))
      .get();

  Future<List<Workout>> getArchived() => (select(workouts)
        ..where((w) => w.isArchived.equals(true))
        ..orderBy([(w) => OrderingTerm.asc(w.name)]))
      .get();

  Future<Workout?> getById(int id) =>
      (select(workouts)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<int> create(WorkoutsCompanion entry) =>
      into(workouts).insert(entry);

  Future<void> updateById(int id, WorkoutsCompanion entry) =>
      (update(workouts)..where((w) => w.id.equals(id))).write(entry);

  Future<void> deleteById(int id) async {
    await (delete(workoutExercises)
          ..where((we) => we.workoutId.equals(id)))
        .go();
    await (delete(workouts)..where((w) => w.id.equals(id))).go();
  }

  Future<void> archive(int id) =>
      (update(workouts)..where((w) => w.id.equals(id))).write(
        const WorkoutsCompanion(
          isArchived: Value(true),
          sortOrder: Value(null),
        ),
      );

  Future<void> unarchive(int id) =>
      (update(workouts)..where((w) => w.id.equals(id))).write(
        const WorkoutsCompanion(isArchived: Value(false)),
      );

  Future<int?> duplicate(int id, {required String nameSuffix}) async {
    final original = await getById(id);
    if (original == null) return null;

    final newId = await into(workouts).insert(
      WorkoutsCompanion.insert(
        name: '${original.name} $nameSuffix',
        description: Value(original.description),
      ),
    );

    final exercises = await getExercises(id);
    for (final ex in exercises) {
      await into(workoutExercises).insert(
        WorkoutExercisesCompanion.insert(
          workoutId: newId,
          exerciseId: ex.exerciseId,
          order: ex.order,
          sets: ex.sets,
          reps: ex.reps,
          restSeconds: Value(ex.restSeconds),
          groupId: Value(ex.groupId),
        ),
      );
    }

    return newId;
  }

  Future<void> reorder(List<int> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(workouts)..where((w) => w.id.equals(orderedIds[i])))
          .write(WorkoutsCompanion(sortOrder: Value(i)));
    }
  }

  // --- Workout exercises ---

  Future<List<WorkoutExercise>> getExercises(int workoutId) =>
      (select(workoutExercises)
            ..where((we) => we.workoutId.equals(workoutId))
            ..orderBy([(we) => OrderingTerm.asc(we.order)]))
          .get();

  Future<void> setExercises(
    int workoutId,
    List<WorkoutExercisesCompanion> entries,
  ) async {
    await (delete(workoutExercises)
          ..where((we) => we.workoutId.equals(workoutId)))
        .go();
    for (final entry in entries) {
      await into(workoutExercises).insert(entry);
    }
  }
}
