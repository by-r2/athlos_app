import 'package:drift/drift.dart';

import '../../../domain/enums/load_mode.dart';
import 'exercises_table.dart';
import 'workouts_table.dart';

/// Junction table: Workout ↔ Exercise (many-to-many with config).
class WorkoutExercises extends Table {
  IntColumn get workoutId => integer().references(Workouts, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get order => integer()();
  IntColumn get sets => integer()();

  /// Minimum target reps per set. Null for cardio exercises.
  IntColumn get minReps => integer().nullable()();

  /// Maximum target reps per set. Null for cardio exercises.
  /// Equal to minReps for fixed targets.
  IntColumn get maxReps => integer().nullable()();

  /// Whether this exercise uses AMRAP (As Many Reps As Possible).
  BoolColumn get isAmrap => boolean().withDefault(const Constant(false))();

  /// Rest time between sets in seconds.
  IntColumn get rest => integer().withDefault(const Constant(60))();

  /// Planned duration per set in seconds. Used for cardio exercises.
  IntColumn get duration => integer().nullable()();

  /// Superset group ID within the workout. Exercises sharing the same
  /// non-null groupId are executed back-to-back before rest.
  IntColumn get groupId => integer().nullable()();

  /// Whether this exercise is performed unilaterally (one side at a time).
  BoolColumn get isUnilateral => boolean().withDefault(const Constant(false))();

  /// User-chosen load mode override for this exercise within this workout.
  /// `null` means "use the catalog's `Exercise.defaultLoadMode`". Only
  /// meaningful when the catalog row exposes `bodyweightLoadFactor`.
  TextColumn get loadModeOverride => textEnum<LoadMode>().nullable()();

  /// Free-text execution notes for this exercise within the workout.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {workoutId, exerciseId};
}
