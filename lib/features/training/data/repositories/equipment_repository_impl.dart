import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/equipment.dart' as domain;
import '../../domain/repositories/equipment_repository.dart';
import '../datasources/daos/equipment_dao.dart';

class EquipmentRepositoryImpl implements EquipmentRepository {
  final EquipmentDao _dao;

  EquipmentRepositoryImpl(this._dao);

  @override
  Future<Result<List<domain.Equipment>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load equipment: $e'));
    }
  }

  @override
  Future<Result<domain.Equipment?>> getById(int id) async {
    try {
      final row = await _dao.getById(id);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load equipment $id: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.Equipment equipment) async {
    try {
      final id = await _dao.create(
        EquipmentsCompanion.insert(
          name: equipment.name,
          description: Value(equipment.description),
          category: equipment.category,
          isVerified: Value(equipment.isVerified),
        ),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create equipment: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.Equipment equipment) async {
    try {
      await _dao.updateById(
        equipment.id,
        EquipmentsCompanion(
          name: Value(equipment.name),
          description: Value(equipment.description),
          category: Value(equipment.category),
          isVerified: Value(equipment.isVerified),
        ),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update equipment: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int id) async {
    try {
      await _dao.deleteById(id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete equipment $id: $e'));
    }
  }

  @override
  Future<Result<List<domain.Equipment>>> getByUser() async {
    try {
      final rows = await _dao.getByUser();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to load user equipment: $e'));
    }
  }

  @override
  Future<Result<void>> toggleUserEquipment(
    int equipmentId, {
    required bool owns,
  }) async {
    try {
      if (owns) {
        await _dao.addUserEquipment(equipmentId);
      } else {
        await _dao.removeUserEquipment(equipmentId);
      }
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to toggle equipment $equipmentId: $e'));
    }
  }

  domain.Equipment _toDomain(Equipment row) => domain.Equipment(
        id: row.id,
        name: row.name,
        description: row.description,
        category: row.category,
        isVerified: row.isVerified,
      );
}
