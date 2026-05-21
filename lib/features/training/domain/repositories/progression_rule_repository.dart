import '../../../../core/errors/result.dart';
import '../entities/progression_rule.dart';

/// Contract for progression rule persistence.
abstract interface class ProgressionRuleRepository {
  /// All rules for a given program.
  Future<Result<List<ProgressionRule>>> getByProgram(String programId);

  /// Single rule for a program + exercise pair, or null.
  Future<Result<ProgressionRule?>> getByProgramAndExercise(
    String programId,
    String exerciseId,
  );

  Future<Result<String>> create(ProgressionRule rule);
  Future<Result<void>> update(ProgressionRule rule);
  Future<Result<void>> delete(String ruleId);

  /// Replace all rules for a program atomically.
  Future<Result<void>> replaceAllForProgram(
    String programId,
    List<ProgressionRule> rules,
  );
}
