import '../enums/progression_condition.dart';
import '../enums/progression_frequency.dart';
import '../enums/progression_type.dart';

/// A per-exercise progression rule within a training program.
/// Defines how and when to increase load/volume for an exercise.
class ProgressionRule {
  final String id;
  final String programId;
  final String exerciseId;
  final ProgressionType type;

  /// Increment value: kg for weight, reps count, or sets count.
  final double value;

  final ProgressionFrequency frequency;

  /// Optional condition that must be met. Null = always progress.
  final ProgressionCondition? condition;

  /// Threshold for condition (e.g. RPE threshold for [rpeBelow]).
  final double? conditionValue;

  const ProgressionRule({
    required this.id,
    required this.programId,
    required this.exerciseId,
    required this.type,
    required this.value,
    required this.frequency,
    this.condition,
    this.conditionValue,
  });
}
