import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/cycle_steps_table.dart';

part 'cycle_step_dao.g.dart';

@DriftAccessor(tables: [CycleSteps])
class CycleStepDao extends DatabaseAccessor<AppDatabase>
    with _$CycleStepDaoMixin {
  CycleStepDao(super.db);

  /// Returns steps for the given [programId], ordered by orderIndex.
  Future<List<CycleStep>> getAllOrdered(int programId) {
    final query = select(cycleSteps)
      ..where((s) => s.programId.equals(programId))
      ..orderBy([(s) => OrderingTerm.asc(s.orderIndex)]);
    return query.get();
  }

  /// Replaces all steps for the given [programId].
  Future<void> replaceAll(
    List<CycleStepsCompanion> entries,
    int programId,
  ) async {
    final deleteQuery = delete(cycleSteps)
      ..where((s) => s.programId.equals(programId));
    await deleteQuery.go();
    if (entries.isNotEmpty) {
      await batch((batch) => batch.insertAll(cycleSteps, entries));
    }
  }

  /// Removes all cycle steps that reference [workoutId] in the given program.
  Future<void> removeWorkout(int workoutId, int programId) async {
    await (delete(cycleSteps)..where(
          (s) => s.workoutId.equals(workoutId) & s.programId.equals(programId),
        ))
        .go();
  }

  /// Removes all cycle steps that reference [workoutId] across ALL programs.
  Future<void> removeWorkoutFromAll(int workoutId) async {
    await (delete(
      cycleSteps,
    )..where((s) => s.workoutId.equals(workoutId))).go();
  }

  Future<int> insertStep(CycleStepsCompanion entry) =>
      into(cycleSteps).insert(entry);

  Future<List<CycleStep>> getAll() => select(cycleSteps).get();

  Future<void> markSynced({
    required int id,
    required String remoteId,
    required DateTime syncedAt,
  }) =>
      (update(cycleSteps)..where((s) => s.id.equals(id))).write(
        CycleStepsCompanion(
          remoteId: Value(remoteId),
          lastSyncedAt: Value(syncedAt),
        ),
      );

  Future<void> markLocalDirty(int id) {
    final now = DateTime.now().toUtc();
    return (update(cycleSteps)..where((s) => s.id.equals(id))).write(
      CycleStepsCompanion(localUpdatedAt: Value(now)),
    );
  }

  Future<CycleStep?> getByRemoteId(String remoteId) =>
      (select(cycleSteps)..where((s) => s.remoteId.equals(remoteId)))
          .getSingleOrNull();
}
