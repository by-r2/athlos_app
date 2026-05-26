import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../../../core/utils/uuid.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/workout.dart' as domain;
import '../../domain/entities/workout_exercise.dart' as domain;
import '../../domain/repositories/workout_repository.dart';
import '../datasources/daos/workout_dao.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final WorkoutDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  Future<void> _syncWorkoutTables() async {
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.workouts);
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.workoutExercises);
  }

  /// Ensures Postgres-safe UUIDs: empty workout / row ids become v4 UUIDs,
  /// and every exercise row references the persisted workout id.
  Result<
      ({
        domain.Workout workout,
        List<domain.WorkoutExercise> exercises,
      })> _normalizeWorkoutPayload(
    domain.Workout workout,
    List<domain.WorkoutExercise> exercises, {
    required bool forCreate,
  }) {
    for (final e in exercises) {
      if (e.exerciseId.trim().isEmpty) {
        return const Failure(
          ValidationException(
            'Each workout exercise must reference a catalog exercise',
          ),
        );
      }
    }

    late final domain.Workout resolvedWorkout;
    if (forCreate) {
      final workoutId =
          workout.id.trim().isEmpty ? generateUuidV4() : workout.id;
      resolvedWorkout = workout.copyWith(id: workoutId);
    } else {
      if (workout.id.trim().isEmpty) {
        return const Failure(
          ValidationException('Workout id required for update'),
        );
      }
      resolvedWorkout = workout;
    }

    final workoutId = resolvedWorkout.id;
    final resolvedExercises = exercises
        .map(
          (e) => domain.WorkoutExercise(
            id: e.id.trim().isEmpty ? generateUuidV4() : e.id,
            workoutId: workoutId,
            exerciseId: e.exerciseId,
            sortOrder: e.sortOrder,
            sets: e.sets,
            minReps: e.minReps,
            maxReps: e.maxReps,
            isAmrap: e.isAmrap,
            restSeconds: e.restSeconds,
            durationSeconds: e.durationSeconds,
            groupId: e.groupId,
            isUnilateral: e.isUnilateral,
            loadModeOverride: e.loadModeOverride,
            notes: e.notes,
          ),
        )
        .toList();

    return Success((workout: resolvedWorkout, exercises: resolvedExercises));
  }

  @override
  Future<Result<List<domain.Workout>>> getAll() async {
    try {
      final rows = await _dao.getAll(_userId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.Workout>>> getActive() async {
    try {
      final rows = await _dao.getActive(_userId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load active workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.Workout>>> getArchived() async {
    try {
      final rows = await _dao.getArchived(_userId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load archived workouts: $e'));
    }
  }

  @override
  Future<Result<domain.Workout?>> getById(String id) async {
    try {
      final row = await _dao.getById(id);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load workout $id: $e'));
    }
  }

  @override
  Future<Result<String>> create(
    domain.Workout workout,
    List<domain.WorkoutExercise> exercises,
  ) async {
    final ({
      domain.Workout workout,
      List<domain.WorkoutExercise> exercises,
    }) normalized;
    switch (_normalizeWorkoutPayload(workout, exercises, forCreate: true)) {
      case Failure(:final exception):
        return Failure(exception);
      case Success(:final value):
        normalized = value;
    }
    try {
      await _dao.create(
        WorkoutsCompanion.insert(
          id: normalized.workout.id,
          userId: _userId,
          name: normalized.workout.name,
          description: Value(normalized.workout.description),
        ),
      );
      await _dao.setExercises(
        normalized.workout.id,
        normalized.exercises.map(_workoutExerciseToCompanion).toList(),
      );
      await _syncWorkoutTables();
      return Success(normalized.workout.id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create workout: $e'));
    }
  }

  @override
  Future<Result<void>> update(
    domain.Workout workout,
    List<domain.WorkoutExercise> exercises,
  ) async {
    final ({
      domain.Workout workout,
      List<domain.WorkoutExercise> exercises,
    }) normalized;
    switch (_normalizeWorkoutPayload(workout, exercises, forCreate: false)) {
      case Failure(:final exception):
        return Failure(exception);
      case Success(:final value):
        normalized = value;
    }
    try {
      await _dao.updateById(
        normalized.workout.id,
        WorkoutsCompanion(
          name: Value(normalized.workout.name),
          description: Value(normalized.workout.description),
        ),
      );
      await _dao.setExercises(
        normalized.workout.id,
        normalized.exercises.map(_workoutExerciseToCompanion).toList(),
      );
      await _syncWorkoutTables();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update workout: $e'));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _dao.deleteById(id);
      await _syncWorkoutTables();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> archive(String id) async {
    try {
      await _dao.archive(id);
      await _syncWorkoutTables();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to archive workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> unarchive(String id) async {
    try {
      await _dao.unarchive(id);
      await _syncWorkoutTables();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to unarchive workout $id: $e'));
    }
  }

  @override
  Future<Result<String>> duplicate(
    String id, {
    required String nameSuffix,
  }) async {
    try {
      final newId = await _dao.duplicate(
        id,
        newId: generateUuidV4(),
        userId: _userId,
        nameSuffix: nameSuffix,
        generateId: generateUuidV4,
      );
      if (newId == null) {
        return Failure(NotFoundException('Workout $id not found'));
      }
      await _syncWorkoutTables();
      return Success(newId);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to duplicate workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> reorder(List<String> orderedIds) async {
    try {
      await _dao.reorder(orderedIds);
      await _syncWorkoutTables();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to reorder workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.WorkoutExercise>>> getExercises(
    String workoutId,
  ) async {
    try {
      final rows = await _dao.getExercises(workoutId);
      return Success(rows.map(_workoutExerciseToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load workout exercises: $e'));
    }
  }

  domain.Workout _toDomain(Workout row) => domain.Workout(
    id: row.id,
    name: row.name,
    description: row.description,
    sortOrder: row.sortOrder,
    isArchived: row.isArchived,
    createdAt: row.createdAt,
  );

  domain.WorkoutExercise _workoutExerciseToDomain(WorkoutExercise row) =>
      domain.WorkoutExercise(
        id: row.id,
        workoutId: row.workoutId,
        exerciseId: row.exerciseId,
        sortOrder: row.sortOrder,
        sets: row.sets,
        minReps: row.minReps,
        maxReps: row.maxReps,
        isAmrap: row.isAmrap,
        restSeconds: row.restSeconds,
        durationSeconds: row.durationSeconds,
        groupId: row.groupId,
        isUnilateral: row.isUnilateral,
        loadModeOverride: row.loadModeOverride,
        notes: row.notes,
      );

  WorkoutExercisesCompanion _workoutExerciseToCompanion(
    domain.WorkoutExercise e,
  ) => WorkoutExercisesCompanion.insert(
    id: e.id,
    userId: _userId,
    workoutId: e.workoutId,
    exerciseId: e.exerciseId,
    sortOrder: e.sortOrder,
    sets: Value(e.sets),
    minReps: Value(e.minReps),
    maxReps: Value(e.maxReps),
    isAmrap: Value(e.isAmrap),
    restSeconds: Value(e.restSeconds),
    durationSeconds: Value(e.durationSeconds),
    groupId: Value(e.groupId),
    isUnilateral: Value(e.isUnilateral),
    loadModeOverride: Value(e.loadModeOverride),
    notes: Value(e.notes),
  );
}
