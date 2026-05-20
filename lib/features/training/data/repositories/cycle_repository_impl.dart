import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/cycle_step.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../datasources/daos/cycle_step_dao.dart';

class CycleRepositoryImpl implements CycleRepository {
  CycleRepositoryImpl(this._dao, this._syncRunner);

  final CycleStepDao _dao;
  final UserOwnedSyncRunner _syncRunner;

  Future<void> _syncCycleSteps(int programId) async {
    final steps = await _dao.getAllOrdered(programId);
    for (final step in steps) {
      await _dao.markLocalDirty(step.id);
    }
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.userCycleSteps);
  }

  @override
  Future<Result<List<TrainingCycleStep>>> getSteps(int programId) async {
    try {
      final rows = await _dao.getAllOrdered(programId);
      return Success(rows.map(_rowToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load cycle steps: $e'));
    }
  }

  @override
  Future<Result<void>> setSteps(
    List<TrainingCycleStep> steps,
    int programId,
  ) async {
    try {
      final companions = steps.asMap().entries.map((e) {
        return CycleStepsCompanion.insert(
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      await _dao.replaceAll(companions, programId);
      await _syncCycleSteps(programId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to save cycle steps: $e'));
    }
  }

  @override
  Future<Result<void>> removeWorkoutFromCycle(
    int workoutId,
    int programId,
  ) async {
    try {
      await _dao.removeWorkout(workoutId, programId);
      final remaining = await _dao.getAllOrdered(programId);
      final reindexed = remaining.asMap().entries.map((e) {
        return CycleStepsCompanion.insert(
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      await _dao.replaceAll(reindexed, programId);
      await _syncCycleSteps(programId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to remove workout from cycle: $e'),
      );
    }
  }

  @override
  Future<Result<void>> removeWorkoutFromAllCycles(int workoutId) async {
    try {
      await _dao.removeWorkoutFromAll(workoutId);
      await _syncRunner.synchronizeTable(TrainingSyncTableNames.userCycleSteps);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to remove workout from cycles: $e'),
      );
    }
  }

  @override
  Future<Result<void>> appendWorkoutToCycle(
    int workoutId,
    int programId,
  ) async {
    try {
      final steps = await _dao.getAllOrdered(programId);
      final companions = steps.asMap().entries.map((e) {
        return CycleStepsCompanion.insert(
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      companions.add(
        CycleStepsCompanion.insert(
          programId: programId,
          orderIndex: steps.length,
          workoutId: workoutId,
        ),
      );
      await _dao.replaceAll(companions, programId);
      await _syncCycleSteps(programId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to append workout to cycle: $e'),
      );
    }
  }

  TrainingCycleStep _rowToDomain(CycleStep row) => TrainingCycleStep(
    id: row.id,
    orderIndex: row.orderIndex,
    workoutId: row.workoutId,
  );
}
