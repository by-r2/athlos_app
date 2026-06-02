import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../../../../core/utils/uuid.dart';
import '../sync/training_remote_client.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/cycle_step.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../datasources/daos/cycle_step_dao.dart';

class CycleRepositoryImpl implements CycleRepository {
  CycleRepositoryImpl(
    this._dao,
    this._syncRunner,
    this._remote,
    this._userId,
  );

  final CycleStepDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final TrainingRemoteClient _remote;
  final String _userId;

  Future<void> _syncCycleSteps() async {
    await _syncRunner.synchronizeTable(TrainingSyncTableNames.cycleSteps);
  }

  /// Keeps the first occurrence of each [workoutId] in cycle order.
  List<CycleStep> _dedupeOrderedSteps(List<CycleStep> rows) {
    final seen = <String>{};
    final kept = <CycleStep>[];
    for (final row in rows) {
      if (seen.add(row.workoutId)) kept.add(row);
    }
    return kept;
  }

  List<CycleStepsCompanion> _toCompanions(
    List<CycleStep> rows,
    String programId,
  ) =>
      rows.asMap().entries.map((entry) {
        final row = entry.value;
        return CycleStepsCompanion.insert(
          id: row.id,
          userId: _userId,
          programId: programId,
          orderIndex: entry.key,
          workoutId: row.workoutId,
        );
      }).toList();

  Future<List<CycleStep>> _compactDuplicatesIfNeeded(
    List<CycleStep> rows,
    String programId,
  ) async {
    final deduped = _dedupeOrderedSteps(rows);
    if (deduped.length == rows.length) return rows;

    await _dao.replaceAll(_toCompanions(deduped, programId), programId, _userId);
    await _remote.deleteByFilter(
      table: TrainingSyncTableNames.cycleSteps,
      userId: _userId,
      filters: {'program_id': programId},
    );
    await _syncCycleSteps();
    return deduped;
  }

  Future<void> _replaceProgramCycleOnRemote(String programId) async {
    await _remote.deleteByFilter(
      table: TrainingSyncTableNames.cycleSteps,
      userId: _userId,
      filters: {'program_id': programId},
    );
  }

  @override
  Future<Result<List<TrainingCycleStep>>> getSteps(String programId) async {
    try {
      final rows = await _dao.getAllOrdered(programId, _userId);
      final compact = await _compactDuplicatesIfNeeded(rows, programId);
      return Success(compact.map(_rowToDomain).toList());
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
      final existing = await _dao.getAllOrdered(programId, _userId);
      final existingByWorkoutId = {
        for (final step in _dedupeOrderedSteps(existing)) step.workoutId: step,
      };

      final companions = steps.asMap().entries.map((e) {
        final workoutId = e.value.workoutId;
        final stepId = e.value.id.isNotEmpty
            ? e.value.id
            : existingByWorkoutId[workoutId]?.id ?? generateUuidV4();
        return CycleStepsCompanion.insert(
          id: stepId,
          userId: _userId,
          programId: programId,
          orderIndex: e.key,
          workoutId: workoutId,
        );
      }).toList();

      await _dao.replaceAll(companions, programId, _userId);
      await _replaceProgramCycleOnRemote(programId);
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
      final reindexed = _dedupeOrderedSteps(remaining);
      await _dao.replaceAll(_toCompanions(reindexed, programId), programId, _userId);
      await _replaceProgramCycleOnRemote(programId);
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
      final deduped = _dedupeOrderedSteps(steps);
      if (deduped.any((s) => s.workoutId == workoutId)) {
        return const Success(null);
      }

      final companions = _toCompanions(deduped, programId)
        ..add(
          CycleStepsCompanion.insert(
            id: generateUuidV4(),
            userId: _userId,
            programId: programId,
            orderIndex: deduped.length,
            workoutId: workoutId,
          ),
        );

      await _dao.replaceAll(companions, programId, _userId);
      await _replaceProgramCycleOnRemote(programId);
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
