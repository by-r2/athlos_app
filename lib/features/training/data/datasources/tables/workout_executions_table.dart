import 'package:drift/drift.dart';

import 'programs_table.dart';
import 'workouts_table.dart';

class WorkoutExecutions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get programId => integer().references(Programs, #id)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// JSON snapshot of the workout exercise configuration at execution start.
  /// Preserves the template state so history remains accurate even if the
  /// workout is edited later.
  TextColumn get exerciseConfigSnapshot => text().nullable()();

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
}
