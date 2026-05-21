import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/progression_rules_table.dart';

part 'progression_rule_dao.g.dart';

@DriftAccessor(tables: [ProgressionRules])
class ProgressionRuleDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressionRuleDaoMixin {
  ProgressionRuleDao(super.db);

  Future<void> _markDirty(String id) {
    final now = DateTime.now().toUtc();
    return (update(progressionRules)..where((r) => r.id.equals(id))).write(
      ProgressionRulesCompanion(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<ProgressionRule>> getByProgram(String programId) =>
      (select(progressionRules)
            ..where(
              (r) =>
                  r.programId.equals(programId) & r.deletedAt.isNull(),
            ))
          .get();

  Future<ProgressionRule?> getByProgramAndExercise(
    String programId,
    String exerciseId,
  ) =>
      (select(progressionRules)
            ..where(
              (r) =>
                  r.programId.equals(programId) &
                  r.exerciseId.equals(exerciseId) &
                  r.deletedAt.isNull(),
            ))
          .getSingleOrNull();

  Future<void> create(ProgressionRulesCompanion entry) async {
    await into(progressionRules).insert(entry);
    await _markDirty(entry.id.value);
  }

  Future<void> updateRule(String id, ProgressionRulesCompanion entry) async {
    await (update(progressionRules)..where((r) => r.id.equals(id)))
        .write(entry);
    await _markDirty(id);
  }

  Future<void> deleteRule(String id) {
    final now = DateTime.now().toUtc();
    return (update(progressionRules)..where((r) => r.id.equals(id))).write(
      ProgressionRulesCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> replaceAllForProgram(
    String programId,
    List<ProgressionRulesCompanion> entries,
  ) async {
    final now = DateTime.now().toUtc();
    await (update(progressionRules)
          ..where((r) => r.programId.equals(programId)))
        .write(
      ProgressionRulesCompanion(
        deletedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
    for (final entry in entries) {
      await into(progressionRules).insert(entry);
      await _markDirty(entry.id.value);
    }
  }

  Future<List<ProgressionRule>> getAll() =>
      (select(progressionRules)..where((r) => r.deletedAt.isNull())).get();
}
