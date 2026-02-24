import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/workout.dart' as domain;
import '../../domain/entities/workout_exercise.dart' as domain;
import '../../domain/repositories/workout_repository.dart';
import '../datasources/daos/workout_dao.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutDao _dao;

  WorkoutRepositoryImpl(this._dao);

  @override
  Future<Result<List<domain.Workout>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.Workout>>> getActive() async {
    try {
      final rows = await _dao.getActive();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load active workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.Workout>>> getArchived() async {
    try {
      final rows = await _dao.getArchived();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load archived workouts: $e'));
    }
  }

  @override
  Future<Result<domain.Workout?>> getById(int id) async {
    try {
      final row = await _dao.getById(id);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load workout $id: $e'));
    }
  }

  @override
  Future<Result<int>> create(
    domain.Workout workout,
    List<domain.WorkoutExercise> exercises,
  ) async {
    try {
      final id = await _dao.create(
        WorkoutsCompanion.insert(
          name: workout.name,
          description: Value(workout.description),
        ),
      );
      await _dao.setExercises(
        id,
        exercises
            .map((e) => WorkoutExercisesCompanion.insert(
                  workoutId: id,
                  exerciseId: e.exerciseId,
                  order: e.order,
                  sets: e.sets,
                  reps: e.reps,
                  restSeconds: Value(e.restSeconds),
                  groupId: Value(e.groupId),
                ))
            .toList(),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create workout: $e'));
    }
  }

  @override
  Future<Result<void>> update(
    domain.Workout workout,
    List<domain.WorkoutExercise> exercises,
  ) async {
    try {
      await _dao.updateById(
        workout.id,
        WorkoutsCompanion(
          name: Value(workout.name),
          description: Value(workout.description),
        ),
      );
      await _dao.setExercises(
        workout.id,
        exercises
            .map((e) => WorkoutExercisesCompanion.insert(
                  workoutId: workout.id,
                  exerciseId: e.exerciseId,
                  order: e.order,
                  sets: e.sets,
                  reps: e.reps,
                  restSeconds: Value(e.restSeconds),
                  groupId: Value(e.groupId),
                ))
            .toList(),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update workout: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _dao.deleteById(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> archive(int id) async {
    try {
      await _dao.archive(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to archive workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> unarchive(int id) async {
    try {
      await _dao.unarchive(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to unarchive workout $id: $e'));
    }
  }

  @override
  Future<Result<int>> duplicate(int id, {required String nameSuffix}) async {
    try {
      final newId = await _dao.duplicate(id, nameSuffix: nameSuffix);
      if (newId == null) {
        return Failure(NotFoundException('Workout $id not found'));
      }
      return Success(newId);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to duplicate workout $id: $e'));
    }
  }

  @override
  Future<Result<void>> reorder(List<int> orderedIds) async {
    try {
      await _dao.reorder(orderedIds);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to reorder workouts: $e'));
    }
  }

  @override
  Future<Result<List<domain.WorkoutExercise>>> getExercises(
      int workoutId) async {
    try {
      final rows = await _dao.getExercises(workoutId);
      return Success(
        rows
            .map((row) => domain.WorkoutExercise(
                  workoutId: row.workoutId,
                  exerciseId: row.exerciseId,
                  order: row.order,
                  sets: row.sets,
                  reps: row.reps,
                  restSeconds: row.restSeconds,
                  groupId: row.groupId,
                ))
            .toList(),
      );
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load workout exercises: $e'));
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
}
