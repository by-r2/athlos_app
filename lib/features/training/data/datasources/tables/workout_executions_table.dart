import 'package:drift/drift.dart';

import '../converters/execution_context_fallback_converter.dart';
import 'programs_table.dart';
import 'workouts_table.dart';

class WorkoutExecutions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get programId => text().references(Programs, #id)();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get workoutNameSnapshot => text().nullable()();
  TextColumn get programNameSnapshot => text().nullable()();
  TextColumn get contextFallback =>
      text().map(const ExecutionContextFallbackConverter()).nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
