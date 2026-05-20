import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/sync_record_store.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../../../core/utils/sync_id.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/duration_mode.dart';
import '../../domain/enums/program_focus.dart';
import '../../domain/repositories/program_repository.dart';
import '../datasources/daos/program_dao.dart';

class ProgramRepositoryImpl implements ProgramRepository {
  ProgramRepositoryImpl(
    this._dao,
    this._syncRunner,
    this._syncStore,
  );

  final ProgramDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final SyncRecordStore _syncStore;

  Future<void> _syncProgram(int programId) async {
    await _dao.markLocalDirty(programId);
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.userPrograms);
  }

  Future<void> _syncAllPrograms() async {
    final rows = await _dao.getAll();
    for (final row in rows) {
      await _dao.markLocalDirty(row.id);
    }
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.userPrograms);
  }

  @override
  Future<Result<List<TrainingProgram>>> getAll() async {
    try {
      final rows = await _dao.getAll();
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load programs: $e'));
    }
  }

  @override
  Future<Result<TrainingProgram?>> getById(int id) async {
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
      final row = await _dao.getActive();
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load active program: $e'));
    }
  }

  @override
  Future<Result<int>> create(TrainingProgram program) async {
    try {
      final dc = program.deloadConfig;
      final id = await _dao.create(
        ProgramsCompanion.insert(
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
      await _syncProgram(id);
      return Success(id);
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
      await _syncProgram(program.id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update program: $e'));
    }
  }

  @override
  Future<Result<void>> activate(int programId) async {
    try {
      await _dao.activate(programId);
      await _syncAllPrograms();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to activate program: $e'));
    }
  }

  @override
  Future<Result<void>> archive(int programId) async {
    try {
      await _dao.archive(programId);
      await _syncProgram(programId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to archive program: $e'));
    }
  }

  @override
  Future<Result<void>> delete(int programId) async {
    try {
      final row = await _dao.getById(programId);
      final record = await _syncStore.getByLocalId(
        tableName: TrainingSyncTableNames.userPrograms,
        localId: programId,
      );
      final remoteId = record?.remoteId ?? row?.remoteId;
      final syncId = record?.syncId ?? remoteId ?? generateSyncUuid();
      if (remoteId != null || record != null) {
        await _syncStore.markTombstone(
          tableName: TrainingSyncTableNames.userPrograms,
          localId: programId,
          syncId: syncId,
          remoteId: remoteId,
          remoteUserId: record?.remoteUserId,
        );
      }
      await _dao.deleteProgram(programId);
      await _syncRunner.synchronizeTable(TrainingSyncTableNames.userPrograms);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to delete program: $e'));
    }
  }

  @override
  Future<Result<void>> setDeloadActive(
    int programId, {
    required bool active,
  }) async {
    try {
      await _dao.setDeloadActive(programId, active: active);
      await _syncProgram(programId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to set deload status: $e'));
    }
  }

  @override
  Future<Result<int>> getSessionCount(int programId) async {
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
