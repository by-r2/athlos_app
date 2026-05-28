import 'package:drift/drift.dart';

import '../domain/entities/local_backup_models.dart';
import '../errors/app_exception.dart';
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

/// Reassigns FKs from [loserId] to [winnerId], then hard-deletes the loser.
///
/// **Catalog safety:** only non-verified (`is_verified = 0`) rows may be removed.
/// Verified catalog entries are never deleted here; callers must reject verified
/// losers before invoking this function.
///
/// When [syncAware] is true, remapped rows are marked [is_dirty] for sync and
/// removed row ids are returned so the caller can hard-delete them on Supabase.
Future<RuntimeDuplicateMergeSyncPayload?> mergeExerciseLoserIntoWinner(
  GeneratedDatabase db, {
  required String winnerId,
  required String loserId,
  bool syncAware = false,
}) async {
  if (winnerId == loserId) return null;

  await _assertExerciseMayBeRemovedAsMergeLoser(db, loserId);

  final now = DateTime.now().toUtc();
  final nowVar = Variable<DateTime>(now);

  List<String> removedWorkoutExerciseIds = const [];
  List<String> removedProgressionRuleIds = const [];

  if (syncAware) {
    removedWorkoutExerciseIds = await _collectDuplicateWorkoutExerciseIds(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await _hardDeleteDuplicateWorkoutExercises(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await db.customUpdate(
      '''
      UPDATE workout_exercises
      SET exercise_id = ?1, is_dirty = 1, updated_at = ?3
      WHERE exercise_id = ?2 AND deleted_at IS NULL
      ''',
      variables: [
        Variable<String>(winnerId),
        Variable<String>(loserId),
        nowVar,
      ],
    );

    await db.customUpdate(
      '''
      UPDATE execution_sets
      SET exercise_id = ?1, is_dirty = 1, updated_at = ?3
      WHERE exercise_id = ?2 AND deleted_at IS NULL
      ''',
      variables: [
        Variable<String>(winnerId),
        Variable<String>(loserId),
        nowVar,
      ],
    );
  } else {
    await _hardDeleteDuplicateWorkoutExercises(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await db.customUpdate(
      'UPDATE workout_exercises SET exercise_id = ? WHERE exercise_id = ?',
      variables: [Variable<String>(winnerId), Variable<String>(loserId)],
    );

    await db.customUpdate(
      'UPDATE execution_sets SET exercise_id = ? WHERE exercise_id = ?',
      variables: [Variable<String>(winnerId), Variable<String>(loserId)],
    );
  }

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

  if (syncAware) {
    removedProgressionRuleIds = await _collectDuplicateProgressionRuleIds(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await _hardDeleteDuplicateProgressionRules(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await db.customUpdate(
      '''
      UPDATE progression_rules
      SET exercise_id = ?1, is_dirty = 1, updated_at = ?3
      WHERE exercise_id = ?2 AND deleted_at IS NULL
      ''',
      variables: [
        Variable<String>(winnerId),
        Variable<String>(loserId),
        nowVar,
      ],
    );
  } else {
    await _hardDeleteDuplicateProgressionRules(
      db,
      loserId: loserId,
      winnerId: winnerId,
    );
    await db.customUpdate(
      'UPDATE progression_rules SET exercise_id = ? WHERE exercise_id = ?',
      variables: [Variable<String>(winnerId), Variable<String>(loserId)],
    );
  }

  await _hardDeleteNonVerifiedExerciseOnly(db, loserId);

  if (!syncAware) return null;

  return RuntimeDuplicateMergeSyncPayload(
    removedExerciseId: loserId,
    removedWorkoutExerciseIds: removedWorkoutExerciseIds,
    removedProgressionRuleIds: removedProgressionRuleIds,
  );
}

Future<void> _assertExerciseMayBeRemovedAsMergeLoser(
  GeneratedDatabase db,
  String exerciseId,
) async {
  final row = await db
      .customSelect(
        'SELECT is_verified FROM exercises WHERE id = ? LIMIT 1',
        variables: [Variable<String>(exerciseId)],
      )
      .getSingleOrNull();
  if (row == null) return;
  final verified = row.data['is_verified'];
  final isVerified = verified is bool
      ? verified
      : (verified is int ? verified != 0 : verified == true);
  if (isVerified) {
    throw const ValidationException(
      'Cannot remove a verified catalog exercise.',
    );
  }
}

/// Hard-deletes [exerciseId] only when it is a non-verified row.
Future<void> _hardDeleteNonVerifiedExerciseOnly(
  GeneratedDatabase db,
  String exerciseId,
) async {
  await db.customUpdate(
    'DELETE FROM exercises WHERE id = ?1 AND is_verified = 0',
    variables: [Variable<String>(exerciseId)],
  );

  final stillVerified = await db
      .customSelect(
        'SELECT 1 FROM exercises WHERE id = ?1 AND is_verified != 0 LIMIT 1',
        variables: [Variable<String>(exerciseId)],
      )
      .getSingleOrNull();
  if (stillVerified != null) {
    throw const ValidationException(
      'Cannot remove a verified catalog exercise.',
    );
  }
}

Future<List<String>> _collectDuplicateWorkoutExerciseIds(
  GeneratedDatabase db, {
  required String loserId,
  required String winnerId,
}) async {
  final rows = await db.customSelect(
    '''
    SELECT id FROM workout_exercises
    WHERE exercise_id = ?1
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM workout_exercises we2
        WHERE we2.workout_id = workout_exercises.workout_id
          AND we2.exercise_id = ?2
          AND we2.deleted_at IS NULL
      )
    ''',
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  ).get();
  return [for (final row in rows) row.read<String>('id')];
}

Future<void> _hardDeleteDuplicateWorkoutExercises(
  GeneratedDatabase db, {
  required String loserId,
  required String winnerId,
}) async {
  await db.customUpdate(
    "DELETE FROM workout_exercises WHERE exercise_id = ? "
    "AND EXISTS (SELECT 1 FROM workout_exercises we2 "
    "WHERE we2.workout_id = workout_exercises.workout_id "
    "AND we2.exercise_id = ?)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  );
}

Future<List<String>> _collectDuplicateProgressionRuleIds(
  GeneratedDatabase db, {
  required String loserId,
  required String winnerId,
}) async {
  final rows = await db.customSelect(
    '''
    SELECT id FROM progression_rules
    WHERE exercise_id = ?1
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM progression_rules pr2
        WHERE pr2.program_id = progression_rules.program_id
          AND pr2.exercise_id = ?2
          AND pr2.deleted_at IS NULL
      )
    ''',
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
  ).get();
  return [for (final row in rows) row.read<String>('id')];
}

Future<void> _hardDeleteDuplicateProgressionRules(
  GeneratedDatabase db, {
  required String loserId,
  required String winnerId,
}) async {
  await db.customUpdate(
    "DELETE FROM progression_rules WHERE exercise_id = ? AND EXISTS "
    "(SELECT 1 FROM progression_rules pr2 "
    "WHERE pr2.program_id = progression_rules.program_id "
    "AND pr2.exercise_id = ?)",
    variables: [Variable<String>(loserId), Variable<String>(winnerId)],
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
