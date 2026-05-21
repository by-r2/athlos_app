import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/programs_table.dart';
import '../tables/workout_executions_table.dart';

part 'program_dao.g.dart';

@DriftAccessor(tables: [Programs, WorkoutExecutions])
class ProgramDao extends DatabaseAccessor<AppDatabase> with _$ProgramDaoMixin {
  ProgramDao(super.db);

  Future<void> _markDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<Program>> getAll(String userId) =>
      (select(programs)
            ..where((p) => p.userId.equals(userId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .get();

  Future<Program?> getById(String id) =>
      (select(programs)
            ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<Program?> getActive(String userId) =>
      (select(programs)
            ..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.isActive.equals(true) &
                  p.deletedAt.isNull(),
            ))
          .getSingleOrNull();

  Future<void> create(ProgramsCompanion entry) async {
    await into(programs).insert(entry);
    await _markDirty(entry.id.value);
  }

  Future<void> updateProgram(String id, ProgramsCompanion entry) async {
    await (update(programs)..where((p) => p.id.equals(id))).write(entry);
    await _markDirty(id);
  }

  /// Deactivates all active programs for [userId].
  Future<void> deactivateAll(String userId) async {
    final activePrograms =
        await (select(programs)
              ..where(
                (p) =>
                    p.userId.equals(userId) &
                    p.isActive.equals(true) &
                    p.deletedAt.isNull(),
              ))
            .get();

    final now = DateTime.now();
    final nowUtc = now.toUtc();
    for (final p in activePrograms) {
      await (update(programs)..where((r) => r.id.equals(p.id))).write(
        ProgramsCompanion(
          isActive: const Value(false),
          archivedAt: Value(now),
          isDirty: const Value(true),
          updatedAt: Value(nowUtc),
        ),
      );
    }
  }

  Future<void> activate(String id, String userId) async {
    await deactivateAll(userId);
    await (update(programs)..where((p) => p.id.equals(id))).write(
      const ProgramsCompanion(isActive: Value(true), archivedAt: Value(null)),
    );
    await _markDirty(id);
  }

  Future<void> archive(String id) async {
    await (update(programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(
        isActive: const Value(false),
        archivedAt: Value(DateTime.now()),
      ),
    );
    await _markDirty(id);
  }

  Future<void> setDeloadActive(String id, {required bool active}) async {
    await (update(programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(isInDeload: Value(active)),
    );
    await _markDirty(id);
  }

  Future<void> deleteProgram(String id) {
    final now = DateTime.now().toUtc();
    return (update(programs)..where((p) => p.id.equals(id))).write(
      ProgramsCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  /// Count finished executions belonging to a given program.
  Future<int> getSessionCount(String programId) async {
    final count = countAll(
      filter:
          workoutExecutions.programId.equals(programId) &
          workoutExecutions.finishedAt.isNotNull() &
          workoutExecutions.deletedAt.isNull(),
    );
    final query = selectOnly(workoutExecutions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
