import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../sync/training_sync_table_names.dart';
import '../../domain/entities/progression_rule.dart' as domain;
import '../../domain/enums/progression_condition.dart';
import '../../domain/enums/progression_frequency.dart';
import '../../domain/enums/progression_type.dart';
import '../../domain/repositories/progression_rule_repository.dart';
import '../datasources/daos/progression_rule_dao.dart';

class ProgressionRuleRepositoryImpl implements ProgressionRuleRepository {
  ProgressionRuleRepositoryImpl(this._dao, this._syncRunner, this._userId);

  final ProgressionRuleDao _dao;
  final UserOwnedSyncRunner _syncRunner;
  final String _userId;

  Future<void> _syncRules() async {
    await _syncRunner.synchronizeTable(
      TrainingSyncTableNames.progressionRules,
    );
  }

  @override
  Future<Result<List<domain.ProgressionRule>>> getByProgram(
    String programId,
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
    String programId,
    String exerciseId,
  ) async {
    try {
      final row = await _dao.getByProgramAndExercise(programId, exerciseId);
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load progression rule: $e'));
    }
  }

  @override
  Future<Result<String>> create(domain.ProgressionRule rule) async {
    try {
      await _dao.create(_toCompanion(rule));
      await _syncRules();
      return Success(rule.id);
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
      await _syncRules();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to update progression rule: $e'),
      );
    }
  }

  @override
  Future<Result<void>> delete(String ruleId) async {
    try {
      await _dao.deleteRule(ruleId);
      await _syncRules();
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
        DatabaseException('Failed to delete progression rule: $e'),
      );
    }
  }

  @override
  Future<Result<void>> replaceAllForProgram(
    String programId,
    List<domain.ProgressionRule> rules,
  ) async {
    try {
      final companions = rules.map(_toCompanion).toList();
      await _dao.replaceAllForProgram(programId, companions);
      await _syncRules();
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
        id: rule.id,
        userId: _userId,
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
