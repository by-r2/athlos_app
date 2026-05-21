import 'package:drift/drift.dart';

import 'exercise_migration_maps.dart';

Future<String?> _exerciseIdByName(GeneratedDatabase db, String name) async {
  final rows = await db
      .customSelect(
        'SELECT id FROM exercises WHERE name = ? LIMIT 1',
        variables: [Variable<String>(name)],
      )
      .get();
  if (rows.isEmpty) return null;
  return rows.first.data['id'] as String?;
}

/// Reassigns FKs from [loserId] to [winnerId], then deletes the loser exercise.
Future<void> mergeExerciseLoserIntoWinner(
  GeneratedDatabase db, {
  required String winnerId,
  required String loserId,
}) async {
  if (winnerId == loserId) return;

  await db.customUpdate(
    "DELETE FROM workout_exercises WHERE exercise_id = ? "
    "AND EXISTS (SELECT 1 FROM workout_exercises we2 "
    "WHERE we2.workout_id = workout_exercises.workout_id "
    "AND we2.exercise_id = ?)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
  await db.customUpdate(
    'UPDATE workout_exercises SET exercise_id = ? WHERE exercise_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    'UPDATE execution_sets SET exercise_id = ? WHERE exercise_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    "DELETE FROM exercise_variations WHERE exercise_id = ? "
    "AND EXISTS (SELECT 1 FROM exercise_variations ev2 "
    "WHERE ev2.exercise_id = ? AND ev2.variation_id = exercise_variations.variation_id)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
  await db.customUpdate(
    'UPDATE exercise_variations SET exercise_id = ? WHERE exercise_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    "DELETE FROM exercise_variations WHERE variation_id = ? "
    "AND EXISTS (SELECT 1 FROM exercise_variations ev2 "
    "WHERE ev2.exercise_id = exercise_variations.exercise_id "
    "AND ev2.variation_id = ?)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
  await db.customUpdate(
    'UPDATE exercise_variations SET variation_id = ? WHERE variation_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    "DELETE FROM exercise_target_muscles WHERE exercise_id = ? "
    "AND EXISTS (SELECT 1 FROM exercise_target_muscles k "
    "WHERE k.exercise_id = ? "
    "AND k.target_muscle = exercise_target_muscles.target_muscle)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
  await db.customUpdate(
    'UPDATE exercise_target_muscles SET exercise_id = ? WHERE exercise_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    "DELETE FROM progression_rules WHERE exercise_id = ? AND EXISTS "
    "(SELECT 1 FROM progression_rules pr2 "
    "WHERE pr2.program_id = progression_rules.program_id "
    "AND pr2.exercise_id = ?)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
  await db.customUpdate(
    'UPDATE progression_rules SET exercise_id = ? WHERE exercise_id = ?',
    variables: [Variable<String>(winnerId), Variable<String>(loserId)],
  );

  await db.customUpdate(
    'DELETE FROM exercises WHERE id = ?',
    variables: [Variable<String>(loserId)],
  );
}

/// Runs merges and global dedupe for rows that collide after FK updates.
Future<void> applyExerciseCanonicalMerges(GeneratedDatabase db) async {
  for (final entry in kExerciseMergeLosersIntoKeeper.entries) {
    final loser = entry.key;
    final keeper = entry.value;
    final loserId = await _exerciseIdByName(db, loser);
    final keeperId = await _exerciseIdByName(db, keeper);
    if (loserId == null || keeperId == null) continue;
    await mergeExerciseLoserIntoWinner(
      db,
      winnerId: keeperId,
      loserId: loserId,
    );
  }

  await db.customStatement('''
DELETE FROM execution_sets WHERE id NOT IN (
  SELECT MIN(id) FROM execution_sets GROUP BY execution_id, exercise_id, set_number
)''');

  await db.customStatement(
    'DELETE FROM exercise_variations WHERE exercise_id = variation_id',
  );

  await db.customStatement('''
DELETE FROM exercise_variations WHERE rowid NOT IN (
  SELECT MIN(rowid) FROM exercise_variations GROUP BY exercise_id, variation_id
)''');

  await db.customStatement('''
DELETE FROM exercise_target_muscles WHERE rowid NOT IN (
  SELECT MIN(rowid) FROM exercise_target_muscles GROUP BY exercise_id, target_muscle
)''');
}
