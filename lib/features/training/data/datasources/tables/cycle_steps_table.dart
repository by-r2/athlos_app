import 'package:drift/drift.dart';

import 'programs_table.dart';
import 'workouts_table.dart';

class CycleSteps extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get programId => text().references(Programs, #id)();
  IntColumn get orderIndex => integer()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
