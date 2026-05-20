import 'package:drift/drift.dart';

import 'exercises_table.dart';
import 'programs_table.dart';

/// Per-exercise progression rules within a training program.
class ProgressionRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get frequency => text()();
  TextColumn get condition => text().nullable()();
  RealColumn get conditionValue => real().nullable()();

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
}
