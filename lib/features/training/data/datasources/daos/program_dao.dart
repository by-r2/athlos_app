import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/programs_table.dart';
import '../tables/workout_executions_table.dart';

part 'program_dao.g.dart';

@DriftAccessor(tables: [Programs, WorkoutExecutions])
class ProgramDao extends DatabaseAccessor<AppDatabase> with _$ProgramDaoMixin {
  ProgramDao(super.db);

  Future<List<Program>> getAll() => (select(
    programs,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  Future<Program?> getById(int id) =>
      (select(programs)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Program?> getActive() => (select(
    programs,
  )..where((p) => p.isActive.equals(true))).getSingleOrNull();

  Future<int> create(ProgramsCompanion entry) => into(programs).insert(entry);

  Future<void> updateProgram(int id, ProgramsCompanion entry) =>
      (update(programs)..where((p) => p.id.equals(id))).write(entry);

  /// Deactivates all programs (sets isActive = false, archivedAt = now).
  Future<void> deactivateAll() =>
      (update(programs)..where((p) => p.isActive.equals(true))).write(
        ProgramsCompanion(
          isActive: const Value(false),
          archivedAt: Value(DateTime.now()),
        ),
      );

  Future<void> activate(int id) async {
    await deactivateAll();
    await (update(programs)..where((p) => p.id.equals(id))).write(
      const ProgramsCompanion(isActive: Value(true), archivedAt: Value(null)),
    );
  }

  Future<void> archive(int id) =>
      (update(programs)..where((p) => p.id.equals(id))).write(
        ProgramsCompanion(
          isActive: const Value(false),
          archivedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setDeloadActive(int id, {required bool active}) =>
      (update(programs)..where((p) => p.id.equals(id))).write(
        ProgramsCompanion(isInDeload: Value(active)),
      );

  Future<void> deleteProgram(int id) async {
    await (delete(programs)..where((p) => p.id.equals(id))).go();
  }

  /// Count finished executions belonging to a given program.
  Future<int> getSessionCount(int programId) async {
    final count = countAll(
      filter:
          workoutExecutions.programId.equals(programId) &
          workoutExecutions.finishedAt.isNotNull(),
    );
    final query = selectOnly(workoutExecutions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
