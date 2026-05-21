import 'package:drift/drift.dart';

import 'exercises_table.dart';
import 'programs_table.dart';

class ProgressionRules extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get programId => text().references(Programs, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get frequency => text()();
  TextColumn get condition => text().nullable()();
  RealColumn get conditionValue => real().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
