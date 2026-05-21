import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/duration_mode.dart';
import '../../domain/enums/program_focus.dart';
import '../../domain/repositories/program_repository.dart';
import '../datasources/daos/program_dao.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  ProgramRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final ProgramDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  Future<void> _syncPrograms() async {
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.programs);
  }

  @override
  Future<Result<List<TrainingProgram>>> getAll() async {
    try {
      final rows = await _dao.getAll(_userId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load programs: $e'));
    }
  }

  @override
  Future<Result<TrainingProgram?>> getById(String id) async {
    try {
      final row = await _dao.getById(id);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load program $id: $e'));
    }
  }

  @override
  Future<Result<TrainingProgram?>> getActive() async {
    try {
      final row = await _dao.getActive(_userId);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load active program: $e'));
    }
  }

  @override
  Future<Result<String>> create(TrainingProgram program) async {
    try {
      final dc = program.deloadConfig;
      await _dao.create(
        ProgramsCompanion.insert(
          id: program.id,
          userId: _userId,
          name: program.name,
          focus: program.focus.name,
          durationMode: program.durationMode.name,
          durationValue: program.durationValue,
          defaultRestSeconds: Value(program.defaultRestSeconds),
          isActive: Value(program.isActive),
          deloadFrequency: Value(dc?.frequency),
          deloadStrategy: Value(dc?.strategy.name),
          deloadVolumeMultiplier: Value(dc?.volumeMultiplier),
          deloadIntensityMultiplier: Value(dc?.intensityMultiplier),
        ),
      );
      await _syncPrograms();
      return Success(program.id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create program: $e'));
    }
  }

  @override
  Future<Result<void>> update(TrainingProgram program) async {
    try {
      final dc = program.deloadConfig;
      await _dao.updateProgram(
        program.id,
        ProgramsCompanion(
          name: Value(program.name),
          focus: Value(program.focus.name),
          durationMode: Value(program.durationMode.name),
          durationValue: Value(program.durationValue),
          defaultRestSeconds: Value(program.defaultRestSeconds),
          deloadFrequency: Value(dc?.frequency),
          deloadStrategy: Value(dc?.strategy.name),
          deloadVolumeMultiplier: Value(dc?.volumeMultiplier),
          deloadIntensityMultiplier: Value(dc?.intensityMultiplier),
        ),
      );
      await _syncPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update program: $e'));
    }
  }

  @override
  Future<Result<void>> activate(String programId) async {
    try {
      await _dao.activate(programId, _userId);
      await _syncPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to activate program: $e'));
    }
  }

  @override
  Future<Result<void>> archive(String programId) async {
    try {
      await _dao.archive(programId);
      await _syncPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to archive program: $e'));
    }
  }

  @override
  Future<Result<void>> delete(String programId) async {
    try {
      await _dao.deleteProgram(programId);
      await _syncPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete program: $e'));
    }
  }

  @override
  Future<Result<void>> setDeloadActive(
    String programId, {
    required bool active,
  }) async {
    try {
      await _dao.setDeloadActive(programId, active: active);
      await _syncPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to set deload status: $e'));
    }
  }

  @override
  Future<Result<int>> getSessionCount(String programId) async {
    try {
      final count = await _dao.getSessionCount(programId);
      return Success(count);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to count program sessions: $e'));
    }
  }

  TrainingProgram _toDomain(Program row) => TrainingProgram(
    id: row.id,
    name: row.name,
    focus: ProgramFocus.values.byName(row.focus),
    durationMode: DurationMode.values.byName(row.durationMode),
    durationValue: row.durationValue,
    defaultRestSeconds: row.defaultRestSeconds,
    isActive: row.isActive,
    isInDeload: row.isInDeload,
    deloadConfig: _deloadFromRow(row),
    createdAt: row.createdAt,
    archivedAt: row.archivedAt,
  );

  DeloadConfig? _deloadFromRow(Program row) {
    final strategy = row.deloadStrategy;
    if (strategy == null) return null;
    return DeloadConfig(
      frequency: row.deloadFrequency,
      strategy: DeloadStrategy.values.byName(strategy),
      volumeMultiplier: row.deloadVolumeMultiplier ?? 0.6,
      intensityMultiplier: row.deloadIntensityMultiplier ?? 0.5,
    );
  }
}
