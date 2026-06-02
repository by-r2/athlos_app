import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/cycle_steps_table.dart';

part 'cycle_step_dao.g.dart';

@DriftAccessor(tables: [CycleSteps])
class CycleStepDao extends DatabaseAccessor<AppDatabase>
    with _$CycleStepDaoMixin {
  CycleStepDao(super.db);

  Future<void> _markDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(cycleSteps)..where((s) => s.id.equals(id))).write(
      CycleStepsCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Returns steps for the given [programId], ordered by orderIndex.
  Future<List<CycleStep>> getAllOrdered(String programId, String userId) =>
      (select(cycleSteps)
            ..where(
              (s) =>
                  s.userId.equals(userId) &
                  s.programId.equals(programId) &
                  s.deletedAt.isNull(),
            )
            ..orderBy([(s) => OrderingTerm.asc(s.orderIndex)]))
          .get();

  /// Replaces all active steps for [programId] and [userId] (hard delete + insert).
  Future<void> replaceAll(
    List<CycleStepsCompanion> entries,
    String programId,
    String userId,
  ) async {
    await transaction(() async {
      await (delete(cycleSteps)
            ..where(
              (s) =>
                  s.programId.equals(programId) & s.userId.equals(userId),
            ))
          .go();
      for (final entry in entries) {
        await into(cycleSteps).insert(entry);
        await _markDirty(entry.id.value);
      }
    });
  }

  /// Soft-deletes cycle steps that reference [workoutId] in the given program.
  Future<void> removeWorkout(String workoutId, String programId) {
    final now = DateTime.now().toUtc();
    return (update(cycleSteps)
          ..where(
            (s) =>
                s.workoutId.equals(workoutId) &
                s.programId.equals(programId),
          ))
        .write(
      CycleStepsCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Permanently removes all cycle steps that reference [workoutId].
  Future<void> hardDeleteForWorkout(String workoutId) =>
      (delete(cycleSteps)..where((s) => s.workoutId.equals(workoutId))).go();

  /// Soft-deletes cycle steps that reference [workoutId] across ALL programs.
  Future<void> removeWorkoutFromAll(String workoutId) {
    final now = DateTime.now().toUtc();
    return (update(cycleSteps)
          ..where((s) => s.workoutId.equals(workoutId)))
        .write(
      CycleStepsCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> insertStep(CycleStepsCompanion entry) async {
    await into(cycleSteps).insert(entry);
    await _markDirty(entry.id.value);
  }

  Future<void> updateStep(String id, CycleStepsCompanion entry) async {
    await (update(cycleSteps)..where((s) => s.id.equals(id))).write(entry);
    await _markDirty(id);
  }

  Future<List<CycleStep>> getAll(String userId) =>
      (select(cycleSteps)
            ..where((s) => s.userId.equals(userId) & s.deletedAt.isNull()))
          .get();
}
