import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/exercise.dart' as domain;
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart' as domain_region;
import '../../domain/enums/muscle_role.dart' as domain_role;
import '../../domain/enums/target_muscle.dart' as domain_muscle;
import '../../domain/repositories/exercise_repository.dart';
import '../datasources/daos/exercise_dao.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseDao _dao;

  ExerciseRepositoryImpl(this._dao);

  @override
  Future<Result<List<domain.Exercise>>> getAll() async {
    try {
      final rows = await _dao.getAll();
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
  Future<Result<domain.Exercise?>> getById(int id) async {
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
      return Failure(
          DatabaseException('Failed to find exercise by name: $e'));
    }
  }

  @override
  Future<Result<List<domain.Exercise>>> getByMuscleGroup(
      MuscleGroup group) async {
    try {
      final rows = await _dao.getByMuscleGroup(group);
      final results = <domain.Exercise>[];
      for (final row in rows) {
        final muscles = await _loadMuscleFoci(row.id);
        results.add(_toDomain(row, muscles));
      }
      return Success(results);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load exercises by muscle group: $e'));
    }
  }

  @override
  Future<Result<List<domain.Exercise>>> getVariations(int exerciseId) async {
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
  Future<Result<List<int>>> getEquipmentIds(int exerciseId) async {
    try {
      final ids = await _dao.getEquipmentIds(exerciseId);
      return Success(ids);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load equipment ids: $e'));
    }
  }

  @override
  Future<Result<Map<int, List<int>>>> getEquipmentMap() async {
    try {
      final map = await _dao.getAllEquipmentMappings();
      return Success(map);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load equipment mappings: $e'));
    }
  }

  @override
  Future<Result<List<domain.ExerciseMuscleFocus>>> getMuscleFoci(
      int exerciseId) async {
    try {
      return Success(await _loadMuscleFoci(exerciseId));
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load muscle foci: $e'));
    }
  }

  @override
  Future<Result<int>> create(
    domain.Exercise exercise, {
    List<int> equipmentIds = const [],
    List<({domain_muscle.TargetMuscle muscle, domain_region.MuscleRegion? region, domain_role.MuscleRole role})>
        muscles = const [],
  }) async {
    try {
      final id = await _dao.create(
        ExercisesCompanion.insert(
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          type: Value(exercise.type),
          movementPattern: Value(exercise.movementPattern),
          description: Value(exercise.description),
          isVerified: Value(exercise.isVerified),
        ),
      );
      if (equipmentIds.isNotEmpty) {
        await _dao.setEquipments(id, equipmentIds);
      }
      if (muscles.isNotEmpty) {
        await _dao.setMuscleFoci(id, muscles);
      }
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create exercise: $e'));
    }
  }

  @override
  Future<Result<void>> update(
    domain.Exercise exercise, {
    List<int>? equipmentIds,
    List<({domain_muscle.TargetMuscle muscle, domain_region.MuscleRegion? region, domain_role.MuscleRole role})>?
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
        ),
      );
      if (equipmentIds != null) {
        await _dao.setEquipments(exercise.id, equipmentIds);
      }
      if (muscles != null) {
        await _dao.setMuscleFoci(exercise.id, muscles);
      }
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update exercise: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _dao.deleteById(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete exercise $id: $e'));
    }
  }

  @override
  Future<Result<void>> addVariation(int exerciseId, int variationId) async {
    try {
      await _dao.addVariation(exerciseId, variationId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to add variation: $e'));
    }
  }

  @override
  Future<Result<void>> removeVariation(int exerciseId, int variationId) async {
    try {
      await _dao.removeVariation(exerciseId, variationId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to remove variation: $e'));
    }
  }

  Future<List<domain.ExerciseMuscleFocus>> _loadMuscleFoci(
      int exerciseId) async {
    final rows = await _dao.getMuscleFoci(exerciseId);
    return rows
        .map((r) =>
            domain.ExerciseMuscleFocus(r.targetMuscle, r.muscleRegion, r.role))
        .toList();
  }

  domain.Exercise _toDomain(
    dynamic row,
    List<domain.ExerciseMuscleFocus> muscles,
  ) =>
      domain.Exercise(
        id: row.id as int,
        name: row.name as String,
        muscleGroup: row.muscleGroup as MuscleGroup,
        type: row.type as ExerciseType,
        movementPattern: row.movementPattern as MovementPattern?,
        description: row.description as String?,
        isVerified: row.isVerified as bool,
        muscles: muscles,
      );
}
