import 'package:drift/drift.dart';

import '../../../domain/enums/exercise_type.dart';
import '../../../domain/enums/load_mode.dart';
import '../../../domain/enums/movement_pattern.dart';
import '../../../domain/enums/muscle_group.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get catalogRemoteId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get type => textEnum<ExerciseType>().withDefault(
    Constant(ExerciseType.strength.name),
  )();
  TextColumn get movementPattern => textEnum<MovementPattern>().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  /// Default load mode suggested by the catalog. The user may override it at
  /// the workout (`WorkoutExercises.loadModeOverride`) or set level
  /// (`ExecutionSets.loadModeOverride`) without duplicating catalog rows.
  ///
  /// Replaces the legacy `isBodyweight` boolean column (migration v34).
  TextColumn get defaultLoadMode =>
      textEnum<LoadMode>().withDefault(Constant(LoadMode.weighted.name))();

  /// Fraction of body weight applied as load when the exercise is performed
  /// in `bodyweight` or `assisted` modes. `null` means the exercise never
  /// uses body weight as part of the load. Sources: Ebben et al. (2011) JSCR;
  /// ExRx via de Leva segmental data.
  RealColumn get bodyweightLoadFactor => real().nullable()();

  /// True for isometric exercises measured in duration rather than reps
  /// (plank, wall sit, dead hang, L-sit, etc.).
  BoolColumn get isIsometric => boolean().withDefault(const Constant(false))();

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
}
