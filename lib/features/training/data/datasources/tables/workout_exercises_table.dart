import 'package:drift/drift.dart';

import '../../../domain/enums/load_mode.dart';
import 'exercises_table.dart';
import 'workouts_table.dart';

class WorkoutExercises extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get sets => integer().withDefault(const Constant(1))();
  IntColumn get minReps => integer().nullable()();
  IntColumn get maxReps => integer().nullable()();
  BoolColumn get isAmrap => boolean().withDefault(const Constant(false))();
  IntColumn get restSeconds => integer().withDefault(const Constant(60))();
  IntColumn get durationSeconds => integer().nullable()();
  IntColumn get groupId => integer().nullable()();
  BoolColumn get isUnilateral => boolean().withDefault(const Constant(false))();
  TextColumn get loadModeOverride => textEnum<LoadMode>().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
