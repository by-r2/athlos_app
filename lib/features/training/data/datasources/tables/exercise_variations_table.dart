import 'package:drift/drift.dart';

import 'exercises_table.dart';

class ExerciseVariations extends Table {
  @ReferenceName('variationsByExercise')
  TextColumn get exerciseId => text().references(Exercises, #id)();

  @ReferenceName('variationsByVariation')
  TextColumn get variationId => text().references(Exercises, #id)();

  @override
  Set<Column> get primaryKey => {exerciseId, variationId};
}
