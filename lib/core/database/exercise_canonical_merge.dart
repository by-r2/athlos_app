import 'package:drift/drift.dart';

import 'exercise_migration_maps.dart';

/// Merge pairs live in [kExerciseMergeLosersIntoKeeper] (declared next to rename maps).

Future<int?> _exerciseIdByName(GeneratedDatabase db, String name) async {
  final rows = await db.customSelect(
    'SELECT id FROM exercises WHERE name = ? LIMIT 1',
    variables: [Variable<String>(name)],
  ).get();
  if (rows.isEmpty) return null;
  return rows.first.data['id'] as int?;
}

Future<void> _mergeOneExerciseIntoAnother(
  GeneratedDatabase db, {
  required int winnerId,
  required int loserId,
}) async {
  if (winnerId == loserId) return;

  await db.customStatement(
    'DELETE FROM workout_exercises WHERE exercise_id = $loserId '
    'AND EXISTS (SELECT 1 FROM workout_exercises we2 '
    'WHERE we2.workout_id = workout_exercises.workout_id '
    'AND we2.exercise_id = $winnerId)',
  );
  await db.customStatement(
    'UPDATE workout_exercises SET exercise_id = $winnerId WHERE exercise_id = $loserId',
  );

  await db.customStatement(
    'UPDATE execution_sets SET exercise_id = $winnerId WHERE exercise_id = $loserId',
  );

  await db.customStatement(
    'DELETE FROM exercise_variations WHERE exercise_id = $loserId '
    'AND EXISTS (SELECT 1 FROM exercise_variations ev2 '
    'WHERE ev2.exercise_id = $winnerId AND ev2.variation_id = exercise_variations.variation_id)',
  );
  await db.customStatement(
    'UPDATE exercise_variations SET exercise_id = $winnerId WHERE exercise_id = $loserId',
  );

  await db.customStatement(
    'DELETE FROM exercise_variations WHERE variation_id = $loserId '
    'AND EXISTS (SELECT 1 FROM exercise_variations ev2 '
    'WHERE ev2.exercise_id = exercise_variations.exercise_id '
    'AND ev2.variation_id = $winnerId)',
  );
  await db.customStatement(
    'UPDATE exercise_variations SET variation_id = $winnerId WHERE variation_id = $loserId',
  );

  // PK is (exercise_id, target_muscle). Drop loser rows that would duplicate
  // the keeper's row on UPDATE; keep the keeper's meta (region/role).
  await db.customStatement(
    'DELETE FROM exercise_target_muscles WHERE exercise_id = $loserId '
    'AND EXISTS (SELECT 1 FROM exercise_target_muscles k '
    'WHERE k.exercise_id = $winnerId '
    'AND k.target_muscle = exercise_target_muscles.target_muscle)',
  );
  await db.customStatement(
    'UPDATE exercise_target_muscles SET exercise_id = $winnerId WHERE exercise_id = $loserId',
  );

  await db.customStatement(
    'DELETE FROM progression_rules WHERE exercise_id = $loserId AND EXISTS '
    '(SELECT 1 FROM progression_rules pr2 '
    'WHERE pr2.program_id = progression_rules.program_id '
    'AND pr2.exercise_id = $winnerId)',
  );
  await db.customStatement(
    'UPDATE progression_rules SET exercise_id = $winnerId WHERE exercise_id = $loserId',
  );

  await db.customStatement('DELETE FROM exercises WHERE id = $loserId');
}

/// Runs merges and global dedupe for rows that collide after FK updates.
Future<void> applyExerciseCanonicalMerges(GeneratedDatabase db) async {
  for (final entry in kExerciseMergeLosersIntoKeeper.entries) {
    final loser = entry.key;
    final keeper = entry.value;
    final loserId = await _exerciseIdByName(db, loser);
    final keeperId = await _exerciseIdByName(db, keeper);
    if (loserId == null || keeperId == null) continue;
    await _mergeOneExerciseIntoAnother(db, winnerId: keeperId, loserId: loserId);
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
