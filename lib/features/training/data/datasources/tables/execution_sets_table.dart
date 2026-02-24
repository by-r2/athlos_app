import 'package:drift/drift.dart';

import 'exercises_table.dart';
import 'workout_executions_table.dart';

/// Individual set performed during a workout execution.
class ExecutionSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get executionId => integer().references(WorkoutExecutions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get setNumber => integer()();

  /// Snapshot of the template reps at the time of execution.
  IntColumn get plannedReps => integer()();

  /// Target weight (from last session or user input). Null if not set.
  RealColumn get plannedWeight => real().nullable()();

  /// Actual reps performed (primary segment for drop sets).
  IntColumn get reps => integer()();

  /// Actual weight used in kg (primary segment for drop sets).
  RealColumn get weight => real().nullable()();

  BoolColumn get isCompleted =>
      boolean().withDefault(const Constant(false))();

  /// Per-set user notes (e.g. "felt easy", "pain in shoulder").
  TextColumn get notes => text().nullable()();
}
