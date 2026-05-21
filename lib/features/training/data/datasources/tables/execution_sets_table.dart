import 'package:drift/drift.dart';

import '../../../domain/enums/load_mode.dart';
import 'exercises_table.dart';
import 'workout_executions_table.dart';

class ExecutionSets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get executionId => text().references(WorkoutExecutions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get setNumber => integer()();
  IntColumn get plannedReps => integer().nullable()();
  RealColumn get plannedWeight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  IntColumn get rpe => integer().nullable()();
  RealColumn get bodyWeightSnapshot => real().nullable()();
  TextColumn get loadModeOverride => textEnum<LoadMode>().nullable()();
  IntColumn get leftReps => integer().nullable()();
  RealColumn get leftWeight => real().nullable()();
  IntColumn get rightReps => integer().nullable()();
  RealColumn get rightWeight => real().nullable()();
  BoolColumn get isUnilateral => boolean().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
