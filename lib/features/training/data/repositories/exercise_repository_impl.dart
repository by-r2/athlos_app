import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../../../core/utils/uuid.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/exercise.dart' as domain;
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart' as domain_region;
import '../../domain/enums/muscle_role.dart' as domain_role;
import '../../domain/enums/target_muscle.dart' as domain_muscle;
import '../../domain/repositories/exercise_repository.dart';
import '../datasources/daos/exercise_dao.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  ExerciseRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final ExerciseDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  @override
  Future<Result<List<domain.Exercise>>> getAll() async {
    try {
      final rows = await _dao.getVisible(_userId);
      final results = <domain.Exercise>[];
      for (final row in rows) {
        final muscles = await _loadMuscleFoci(row.id);
        results.add(_toDomain(row, muscles));
      }
      return Success(results);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load exercises: $e'));
    }
  }

  @override
  Future<Result<domain.Exercise?>> getById(String id) async {
    try {
      final row = await _dao.getById(id);
      if (row == null) return const Success(null);
      final muscles = await _loadMuscleFoci(row.id);
      return Success(_toDomain(row, muscles));
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load exercise $id: $e'));
    }
  }

  @override
  Future<Result<domain.Exercise?>> findByName(String name) async {
    try {
      final id = await _dao.findIdByName(name);
      if (id == null) return const Success(null);
      return getById(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to find exercise by name: $e'));
    }
  }

  @override
  Future<Result<domain.Exercise?>> findByNameFuzzy(String name) async {
    try {
      final id = await _dao.findIdByNameFuzzy(name);
      if (id == null) return const Success(null);
      return getById(id);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to find exercise by name (fuzzy): $e'),
      );
    }
  }

  @override
  Future<Result<List<domain.Exercise>>> getByMuscleGroup(
    MuscleGroup group,
  ) async {
    try {
      final rows = await _dao.getByMuscleGroup(group, userId: _userId);
      final results = <domain.Exercise>[];
      for (final row in rows) {
        final muscles = await _loadMuscleFoci(row.id);
        results.add(_toDomain(row, muscles));
      }
      return Success(results);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to load exercises by muscle group: $e'),
      );
    }
  }

  @override
  Future<Result<List<domain.Exercise>>> getVariations(String exerciseId) async {
    try {
      final rows = await _dao.getVariations(exerciseId);
      final results = <domain.Exercise>[];
      for (final row in rows) {
        final muscles = await _loadMuscleFoci(row.id);
        results.add(_toDomain(row, muscles));
      }
      return Success(results);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load variations: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExerciseMuscleFocus>>> getMuscleFoci(
    String exerciseId,
  ) async {
    try {
      return Success(await _loadMuscleFoci(exerciseId));
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load muscle foci: $e'));
    }
  }

  @override
  Future<Result<String>> create(
    domain.Exercise exercise, {
    List<
          ({
            domain_muscle.TargetMuscle muscle,
            domain_region.MuscleRegion? region,
            domain_role.MuscleRole role,
          })
        >
        muscles =
        const [],
  }) async {
    try {
      final conflictId = await _dao.findIdByConflictingName(exercise.name);
      if (conflictId != null) {
        return Failure(
          ConflictException('Exercise name already exists in catalog'),
        );
      }

      final idToUse =
          exercise.id.trim().isEmpty ? generateUuidV4() : exercise.id;

      await _dao.create(
        ExercisesCompanion.insert(
          id: idToUse,
          createdBy: exercise.isVerified
              ? const Value.absent()
              : Value(_userId),
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          type: Value(exercise.type),
          movementPattern: Value(exercise.movementPattern),
          description: Value(exercise.description),
          isVerified: Value(exercise.isVerified),
          defaultLoadMode: Value(exercise.defaultLoadMode),
          bodyweightLoadFactor: Value(exercise.bodyweightLoadFactor),
          isIsometric: Value(exercise.isIsometric),
        ),
      );
      if (muscles.isNotEmpty) {
        await _dao.setMuscleFoci(idToUse, muscles);
      }
      if (!exercise.isVerified) {
        await _syncRunner.synchronizeTable(TrainingSyncTableNames.exercises);
      }
      return Success(idToUse);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create exercise: $e'));
    }
  }

  @override
  Future<Result<void>> update(
    domain.Exercise exercise, {
    List<
      ({
        domain_muscle.TargetMuscle muscle,
        domain_region.MuscleRegion? region,
        domain_role.MuscleRole role,
      })
    >?
    muscles,
  }) async {
    try {
      await _dao.updateById(
        exercise.id,
        ExercisesCompanion(
          name: Value(exercise.name),
          muscleGroup: Value(exercise.muscleGroup),
          type: Value(exercise.type),
          movementPattern: Value(exercise.movementPattern),
          description: Value(exercise.description),
          isVerified: Value(exercise.isVerified),
          defaultLoadMode: Value(exercise.defaultLoadMode),
          bodyweightLoadFactor: Value(exercise.bodyweightLoadFactor),
          isIsometric: Value(exercise.isIsometric),
        ),
      );
      if (muscles != null) {
        await _dao.setMuscleFoci(exercise.id, muscles);
      }
      if (!exercise.isVerified) {
        await _syncRunner.synchronizeTable(TrainingSyncTableNames.exercises);
      }
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update exercise: $e'));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final row = await _dao.getById(id);
      if (row != null && row.isVerified) {
        return Failure(
          ValidationException('Cannot delete a verified catalog exercise'),
        );
      }
      await _dao.deleteById(id);
      await _syncRunner.synchronizeTable(TrainingSyncTableNames.exercises);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete exercise $id: $e'));
    }
  }

  @override
  Future<Result<void>> addVariation(
    String exerciseId,
    String variationId,
  ) async {
    try {
      await _dao.addVariation(exerciseId, variationId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to add variation: $e'));
    }
  }

  @override
  Future<Result<void>> removeVariation(
    String exerciseId,
    String variationId,
  ) async {
    try {
      await _dao.removeVariation(exerciseId, variationId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to remove variation: $e'));
    }
  }

  Future<List<domain.ExerciseMuscleFocus>> _loadMuscleFoci(
    String exerciseId,
  ) async {
    final rows = await _dao.getMuscleFoci(exerciseId);
    return rows
        .map(
          (r) => domain.ExerciseMuscleFocus(
            r.targetMuscle,
            r.muscleRegion,
            r.role,
          ),
        )
        .toList();
  }

  domain.Exercise _toDomain(
    Exercise row,
    List<domain.ExerciseMuscleFocus> muscles,
  ) => domain.Exercise(
    id: row.id,
    name: row.name,
    muscleGroup: row.muscleGroup,
    type: row.type,
    movementPattern: row.movementPattern,
    description: row.description,
    isVerified: row.isVerified,
    defaultLoadMode: row.defaultLoadMode,
    bodyweightLoadFactor: row.bodyweightLoadFactor,
    isIsometric: row.isIsometric,
    muscles: muscles,
  );
}
