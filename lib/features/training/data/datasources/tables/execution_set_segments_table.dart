import 'package:drift/drift.dart';

import 'execution_sets_table.dart';

/// Individual segment within a set (for drop sets).
///
/// Normal sets have no rows here. Drop sets store every segment
/// (including the first) so the full breakdown is available.
class ExecutionSetSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get executionSetId => integer().references(ExecutionSets, #id)();

  /// Order within the set: 1 = primary, 2+ = drops.
  IntColumn get segmentOrder => integer()();

  IntColumn get reps => integer()();

  /// Weight in kg. Null for bodyweight exercises.
  RealColumn get weight => real().nullable()();
}
