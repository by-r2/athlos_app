import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/workout_exercises_table.dart';
import '../tables/workouts_table.dart';

part 'workout_dao.g.dart';

@DriftAccessor(tables: [Workouts, WorkoutExercises, Exercises])
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(super.db);

  Future<void> _markDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(workouts)..where((w) => w.id.equals(id))).write(
      WorkoutsCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<Workout>> getAll(String userId) =>
      (select(workouts)
            ..where((w) => w.userId.equals(userId) & w.deletedAt.isNull()))
          .get();

  Future<List<Workout>> getActive(String userId) =>
      (select(workouts)
            ..where(
              (w) =>
                  w.userId.equals(userId) &
                  w.isArchived.equals(false) &
                  w.deletedAt.isNull(),
            )
            ..orderBy([
              (w) => OrderingTerm.asc(w.sortOrder),
              (w) => OrderingTerm.asc(w.createdAt),
            ]))
          .get();

  Future<List<Workout>> getArchived(String userId) =>
      (select(workouts)
            ..where(
              (w) =>
                  w.userId.equals(userId) &
                  w.isArchived.equals(true) &
                  w.deletedAt.isNull(),
            )
            ..orderBy([(w) => OrderingTerm.asc(w.name)]))
          .get();

  Future<Workout?> getById(String id) =>
      (select(workouts)
            ..where((w) => w.id.equals(id) & w.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> create(WorkoutsCompanion entry) async {
    await into(workouts).insert(entry);
    await _markDirty(entry.id.value);
  }

  Future<void> updateById(String id, WorkoutsCompanion entry) async {
    await (update(workouts)..where((w) => w.id.equals(id))).write(entry);
    await _markDirty(id);
  }

  Future<void> deleteById(String id) {
    final now = DateTime.now().toUtc();
    return transaction(() async {
      await (update(workoutExercises)
            ..where((we) => we.workoutId.equals(id)))
          .write(
        WorkoutExercisesCompanion(
          deletedAt: Value(now),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await (update(workouts)..where((w) => w.id.equals(id))).write(
        WorkoutsCompanion(
          deletedAt: Value(now),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
    });
  }

  Future<void> archive(String id) async {
    await (update(workouts)..where((w) => w.id.equals(id))).write(
      const WorkoutsCompanion(
        isArchived: Value(true),
        sortOrder: Value(null),
      ),
    );
    await _markDirty(id);
  }

  Future<void> unarchive(String id) async {
    await (update(workouts)..where((w) => w.id.equals(id))).write(
      const WorkoutsCompanion(isArchived: Value(false)),
    );
    await _markDirty(id);
  }

  Future<String?> duplicate(
    String id, {
    required String newId,
    required String userId,
    required String nameSuffix,
    required String Function() generateId,
  }) async {
    final original = await getById(id);
    if (original == null) return null;

    await into(workouts).insert(
      WorkoutsCompanion.insert(
        id: newId,
        userId: userId,
        name: '${original.name} $nameSuffix',
        description: Value(original.description),
      ),
    );
    await _markDirty(newId);

    final exerciseList = await getExercises(id);
    for (final ex in exerciseList) {
      final newExId = generateId();
      await into(workoutExercises).insert(
        WorkoutExercisesCompanion.insert(
          id: newExId,
          userId: userId,
          workoutId: newId,
          exerciseId: ex.exerciseId,
          sortOrder: ex.sortOrder,
          sets: Value(ex.sets),
          minReps: Value(ex.minReps),
          maxReps: Value(ex.maxReps),
          isAmrap: Value(ex.isAmrap),
          restSeconds: Value(ex.restSeconds),
          durationSeconds: Value(ex.durationSeconds),
          groupId: Value(ex.groupId),
          isUnilateral: Value(ex.isUnilateral),
          loadModeOverride: Value(ex.loadModeOverride),
          notes: Value(ex.notes),
        ),
      );
      await _markWorkoutExerciseDirty(newExId);
    }

    return newId;
  }

  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(workouts)..where((w) => w.id.equals(orderedIds[i]))).write(
        WorkoutsCompanion(sortOrder: Value(i)),
      );
      await _markDirty(orderedIds[i]);
    }
  }

  // --- Workout exercises ---

  Future<List<WorkoutExercise>> getExercises(String workoutId) =>
      (select(workoutExercises)
            ..where(
              (we) =>
                  we.workoutId.equals(workoutId) & we.deletedAt.isNull(),
            )
            ..orderBy([(we) => OrderingTerm.asc(we.sortOrder)]))
          .get();

  Future<void> setExercises(
    String workoutId,
    List<WorkoutExercisesCompanion> entries,
  ) async {
    final now = DateTime.now().toUtc();
    final newIds = entries.map((e) => e.id.value).toSet();

    if (newIds.isEmpty) {
      await (update(workoutExercises)
            ..where((we) => we.workoutId.equals(workoutId)))
          .write(
        WorkoutExercisesCompanion(
          deletedAt: Value(now),
          isDirty: const Value(true),
          updatedAt: Value(now),
        ),
      );
      return;
    }

    // Tombstone workout rows that were removed (still needed for sync).
    await (update(workoutExercises)
          ..where(
            (we) =>
                we.workoutId.equals(workoutId) &
                we.id.isNotIn(newIds.toList()),
          ))
        .write(
      WorkoutExercisesCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );

    // Re-use or revive existing rows without violating PK UNIQUE (same id can
    // still exist physically after soft-delete).
    for (final entry in entries) {
      final merged = WorkoutExercisesCompanion(
        id: entry.id,
        userId: entry.userId,
        workoutId: entry.workoutId,
        exerciseId: entry.exerciseId,
        sortOrder: entry.sortOrder,
        sets: entry.sets,
        minReps: entry.minReps,
        maxReps: entry.maxReps,
        isAmrap: entry.isAmrap,
        restSeconds: entry.restSeconds,
        durationSeconds: entry.durationSeconds,
        groupId: entry.groupId,
        isUnilateral: entry.isUnilateral,
        loadModeOverride: entry.loadModeOverride,
        notes: entry.notes,
        deletedAt: const Value(null),
        isDirty: const Value(true),
        updatedAt: Value(now),
      );
      await into(workoutExercises).insertOnConflictUpdate(merged);
    }
  }

  Future<void> _markWorkoutExerciseDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(workoutExercises)..where((we) => we.id.equals(id))).write(
      WorkoutExercisesCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Purges obviously corrupted local rows that cannot be synced (e.g. empty
  /// UUID strings in PK/FK columns). These rows are unrecoverable because
  /// their references cannot be inferred safely.
  ///
  /// This is intended as a "sync repair" action surfaced in the UI.
  Future<int> purgeCorruptedRowsForUser(String userId) async {
    return transaction(() async {
      var deleted = 0;
      deleted += await (delete(workoutExercises)
            ..where(
              (we) =>
                  we.userId.equals(userId) &
                  (we.id.equals('') |
                      we.workoutId.equals('') |
                      we.exerciseId.equals('')),
            ))
          .go();
      deleted += await (delete(workouts)
            ..where((w) => w.userId.equals(userId) & w.id.equals('')))
          .go();
      return deleted;
    });
  }
}
