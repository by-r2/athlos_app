import 'package:drift/drift.dart';

import '../../../domain/enums/exercise_type.dart';
import '../../../domain/enums/load_mode.dart';
import '../../../domain/enums/movement_pattern.dart';
import '../../../domain/enums/muscle_group.dart';

class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get createdBy => text().nullable()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get type => textEnum<ExerciseType>().withDefault(
    Constant(ExerciseType.strength.name),
  )();
  TextColumn get movementPattern => textEnum<MovementPattern>().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get defaultLoadMode =>
      textEnum<LoadMode>().withDefault(Constant(LoadMode.weighted.name))();
  RealColumn get bodyweightLoadFactor => real().nullable()();
  BoolColumn get isIsometric => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
