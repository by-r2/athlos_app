import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/progression_rules_table.dart';

part 'progression_rule_dao.g.dart';

@DriftAccessor(tables: [ProgressionRules])
class ProgressionRuleDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressionRuleDaoMixin {
  ProgressionRuleDao(super.db);

  Future<List<ProgressionRule>> getByProgram(int programId) => (select(
    progressionRules,
  )..where((r) => r.programId.equals(programId))).get();

  Future<ProgressionRule?> getByProgramAndExercise(
    int programId,
    int exerciseId,
  ) =>
      (select(progressionRules)..where(
            (r) =>
                r.programId.equals(programId) & r.exerciseId.equals(exerciseId),
          ))
          .getSingleOrNull();

  Future<int> create(ProgressionRulesCompanion entry) =>
      into(progressionRules).insert(entry);

  Future<void> updateRule(int id, ProgressionRulesCompanion entry) =>
      (update(progressionRules)..where((r) => r.id.equals(id))).write(entry);

  Future<void> deleteRule(int id) =>
      (delete(progressionRules)..where((r) => r.id.equals(id))).go();

  Future<void> replaceAllForProgram(
    int programId,
    List<ProgressionRulesCompanion> entries,
  ) async {
    await (delete(
      progressionRules,
    )..where((r) => r.programId.equals(programId))).go();
    if (entries.isNotEmpty) {
      await batch((b) => b.insertAll(progressionRules, entries));
    }
  }
}
