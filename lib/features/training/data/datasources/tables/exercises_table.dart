import 'package:drift/drift.dart';

import '../../../domain/enums/exercise_type.dart';
import '../../../domain/enums/movement_pattern.dart';
import '../../../domain/enums/muscle_group.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get type =>
      textEnum<ExerciseType>().withDefault(Constant(ExerciseType.strength.name))();
  TextColumn get movementPattern => textEnum<MovementPattern>().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
}
