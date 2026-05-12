import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/progression_rule.dart' as domain;
import '../../domain/enums/progression_condition.dart';
import '../../domain/enums/progression_frequency.dart';
import '../../domain/enums/progression_type.dart';
import '../../domain/repositories/progression_rule_repository.dart';
import '../datasources/daos/progression_rule_dao.dart';

class ProgressionRuleRepositoryImpl implements ProgressionRuleRepository {
  ProgressionRuleRepositoryImpl(this._dao);

  final ProgressionRuleDao _dao;

  @override
  Future<Result<List<domain.ProgressionRule>>> getByProgram(
    int programId,
  ) async {
    try {
      final rows = await _dao.getByProgram(programId);
      return Success(rows.map(_toDomain).toList());
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load progression rules: $e'));
    }
  }

  @override
  Future<Result<domain.ProgressionRule?>> getByProgramAndExercise(
    int programId,
    int exerciseId,
  ) async {
    try {
      final row = await _dao.getByProgramAndExercise(programId, exerciseId);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load progression rule: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.ProgressionRule rule) async {
    try {
      final id = await _dao.create(_toCompanion(rule));
      return Success(id);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to create progression rule: $e'),
      );
    }
  }

  @override
  Future<Result<void>> update(domain.ProgressionRule rule) async {
    try {
      await _dao.updateRule(rule.id, _toUpdateCompanion(rule));
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to update progression rule: $e'),
      );
    }
  }

  @override
  Future<Result<void>> delete(int ruleId) async {
    try {
      await _dao.deleteRule(ruleId);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to delete progression rule: $e'),
      );
    }
  }

  @override
  Future<Result<void>> replaceAllForProgram(
    int programId,
    List<domain.ProgressionRule> rules,
  ) async {
    try {
      final companions = rules
          .map(
            (r) => ProgressionRulesCompanion.insert(
              programId: programId,
              exerciseId: r.exerciseId,
              type: r.type.name,
              value: r.value,
              frequency: r.frequency.name,
              condition: Value(r.condition?.name),
              conditionValue: Value(r.conditionValue),
            ),
          )
          .toList();
      await _dao.replaceAllForProgram(programId, companions);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to replace progression rules: $e'),
      );
    }
  }

  domain.ProgressionRule _toDomain(ProgressionRule row) =>
      domain.ProgressionRule(
        id: row.id,
        programId: row.programId,
        exerciseId: row.exerciseId,
        type: ProgressionType.values.byName(row.type),
        value: row.value,
        frequency: ProgressionFrequency.values.byName(row.frequency),
        condition: row.condition != null
            ? ProgressionCondition.values.byName(row.condition!)
            : null,
        conditionValue: row.conditionValue,
      );

  ProgressionRulesCompanion _toCompanion(domain.ProgressionRule rule) =>
      ProgressionRulesCompanion.insert(
        programId: rule.programId,
        exerciseId: rule.exerciseId,
        type: rule.type.name,
        value: rule.value,
        frequency: rule.frequency.name,
        condition: Value(rule.condition?.name),
        conditionValue: Value(rule.conditionValue),
      );

  ProgressionRulesCompanion _toUpdateCompanion(domain.ProgressionRule rule) =>
      ProgressionRulesCompanion(
        type: Value(rule.type.name),
        value: Value(rule.value),
        frequency: Value(rule.frequency.name),
        condition: Value(rule.condition?.name),
        conditionValue: Value(rule.conditionValue),
      );
}
