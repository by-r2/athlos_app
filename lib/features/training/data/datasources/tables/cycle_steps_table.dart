import 'package:drift/drift.dart';

import 'programs_table.dart';
import 'workouts_table.dart';

/// A single step in the training cycle (ordered workout reference).
/// Every step belongs to a program — there is no free cycle.
class CycleSteps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get programId => integer().references(Programs, #id)();
  IntColumn get orderIndex => integer()();
  IntColumn get workoutId => integer().references(Workouts, #id)();

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
}
