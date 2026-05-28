import 'package:drift/drift.dart';

import '../utils/uuid.dart';

/// Assigns a UUID to user exercises persisted with an empty [Exercises.id].
///
/// Caused by a bug in [ExerciseRepositoryImpl.create] before UUID generation
/// was added. Repairs FKs so detail routes and delete work again.
Future<void> repairExercisesWithEmptyIds(GeneratedDatabase db) async {
  const emptyId = '';

  final broken = await db
      .customSelect(
        "SELECT id FROM exercises WHERE trim(id) = '' LIMIT 1",
      )
      .get();
  if (broken.isEmpty) return;

  final newId = generateUuidV4();

  await db.transaction(() async {
    for (final table in [
      'exercise_target_muscles',
      'workout_exercises',
      'execution_sets',
      'progression_rules',
    ]) {
      await db.customUpdate(
        'UPDATE $table SET exercise_id = ? WHERE trim(exercise_id) = ?',
        variables: [
          Variable<String>(newId),
          const Variable<String>(emptyId),
        ],
      );
    }

    await db.customUpdate(
      'UPDATE exercise_variations SET exercise_id = ? WHERE trim(exercise_id) = ?',
      variables: [
        Variable<String>(newId),
        const Variable<String>(emptyId),
      ],
    );
    await db.customUpdate(
      'UPDATE exercise_variations SET variation_id = ? WHERE trim(variation_id) = ?',
      variables: [
        Variable<String>(newId),
        const Variable<String>(emptyId),
      ],
    );

    await db.customUpdate(
      'UPDATE exercises SET id = ?, is_dirty = 1 WHERE trim(id) = ?',
      variables: [
        Variable<String>(newId),
        const Variable<String>(emptyId),
      ],
    );
  });
}
