import 'package:drift/drift.dart';

import '../../../domain/enums/muscle_region.dart';
import '../../../domain/enums/muscle_role.dart';
import '../../../domain/enums/target_muscle.dart';
import 'exercises_table.dart';

class ExerciseTargetMuscles extends Table {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get targetMuscle => textEnum<TargetMuscle>()();
  TextColumn get muscleRegion => textEnum<MuscleRegion>().nullable()();
  TextColumn get role =>
      textEnum<MuscleRole>().withDefault(Constant(MuscleRole.primary.name))();

  @override
  Set<Column> get primaryKey => {exerciseId, targetMuscle};
}
