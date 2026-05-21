import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../../../core/utils/uuid.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/cycle_step.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../datasources/daos/cycle_step_dao.dart';

class CycleRepositoryImpl implements CycleRepository {
  CycleRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final CycleStepDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  Future<void> _syncCycleSteps() async {
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.cycleSteps);
  }

  @override
  Future<Result<List<TrainingCycleStep>>> getSteps(String programId) async {
    try {
      final rows = await _dao.getAllOrdered(programId, _userId);
      return Success(rows.map(_rowToDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load cycle steps: $e'));
    }
  }

  @override
  Future<Result<void>> setSteps(
    List<TrainingCycleStep> steps,
    String programId,
  ) async {
    try {
      final companions = steps.asMap().entries.map((e) {
        final stepId = e.value.id.isEmpty ? generateUuidV4() : e.value.id;
        return CycleStepsCompanion.insert(
          id: stepId,
          userId: _userId,
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      await _dao.replaceAll(companions, programId);
      await _syncCycleSteps();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to save cycle steps: $e'));
    }
  }

  @override
  Future<Result<void>> removeWorkoutFromCycle(
    String workoutId,
    String programId,
  ) async {
    try {
      await _dao.removeWorkout(workoutId, programId);
      final remaining = await _dao.getAllOrdered(programId, _userId);
      final reindexed = remaining.asMap().entries.map((e) {
        return CycleStepsCompanion.insert(
          id: e.value.id,
          userId: _userId,
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      await _dao.replaceAll(reindexed, programId);
      await _syncCycleSteps();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to remove workout from cycle: $e'),
      );
    }
  }

  @override
  Future<Result<void>> removeWorkoutFromAllCycles(String workoutId) async {
    try {
      await _dao.removeWorkoutFromAll(workoutId);
      await _syncCycleSteps();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to remove workout from cycles: $e'),
      );
    }
  }

  @override
  Future<Result<void>> appendWorkoutToCycle(
    String workoutId,
    String programId,
  ) async {
    try {
      final steps = await _dao.getAllOrdered(programId, _userId);
      final companions = steps.asMap().entries.map((e) {
        return CycleStepsCompanion.insert(
          id: e.value.id,
          userId: _userId,
          programId: programId,
          orderIndex: e.key,
          workoutId: e.value.workoutId,
        );
      }).toList();
      companions.add(
        CycleStepsCompanion.insert(
          id: generateUuidV4(),
          userId: _userId,
          programId: programId,
          orderIndex: steps.length,
          workoutId: workoutId,
        ),
      );
      await _dao.replaceAll(companions, programId);
      await _syncCycleSteps();
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
