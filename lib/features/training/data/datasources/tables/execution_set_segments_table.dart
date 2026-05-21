import 'package:drift/drift.dart';

import 'execution_sets_table.dart';

class ExecutionSetSegments extends Table {
  TextColumn get id => text()();
  TextColumn get executionSetId => text().references(ExecutionSets, #id)();
  IntColumn get segmentOrder => integer()();
  IntColumn get reps => integer()();
  RealColumn get weight => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
