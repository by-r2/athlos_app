import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Counts of user-owned rows still referencing a missing exercise id.
class GhostExerciseRemapPreview {
  const GhostExerciseRemapPreview({
    required this.workoutExercises,
    required this.executionSets,
    required this.progressionRules,
  });

  final int workoutExercises;
  final int executionSets;
  final int progressionRules;

  int get total => workoutExercises + executionSets + progressionRules;
}

/// Stored exercise row used to show a human label for a ghost id.
class GhostExerciseCatalogRow {
  const GhostExerciseCatalogRow({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.isDeleted,
  });

  final String id;
  final String name;
  final bool isVerified;
  final bool isDeleted;
}

/// Extra context to help the user identify a ghost exercise id.
class GhostExerciseUsageSummary {
  const GhostExerciseUsageSummary({
    required this.workoutNames,
    required this.workoutCount,
  });

  /// A small sample of workout names that reference this id.
  final List<String> workoutNames;

  /// Total number of distinct workouts referencing this id.
  final int workoutCount;
}

/// Reassigns all [userId] rows that reference [ghostExerciseId] to [targetExerciseId].
///
/// Scoped strictly to the given user — never touches another user's data.
class GhostExerciseRemapService {
  GhostExerciseRemapService(this._db);

  final AppDatabase _db;

  Future<GhostExerciseCatalogRow?> lookupExerciseRow(String exerciseId) async {
    final row = await _db
        .customSelect(
          'SELECT name, is_verified, deleted_at FROM exercises WHERE id = ? LIMIT 1',
          variables: [Variable<String>(exerciseId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return GhostExerciseCatalogRow(
      id: exerciseId,
      name: row.read<String>('name'),
      isVerified: row.read<bool>('is_verified'),
      isDeleted: row.data['deleted_at'] != null,
    );
  }

  Future<GhostExerciseUsageSummary> usageSummaryForUser({
    required String userId,
    required String ghostExerciseId,
    int maxWorkoutNames = 5,
  }) async {
    // We only use `workout_exercises` here because it is the canonical template
    // source for the screen. `execution_sets` can reference legacy ids too, but
    // listing workout names is usually enough for user recognition.
    final rows = await _db.customSelect(
      '''
      SELECT DISTINCT w.name AS workout_name
      FROM workout_exercises we
      INNER JOIN workouts w ON w.id = we.workout_id
      WHERE we.user_id = ?1
        AND we.exercise_id = ?2
        AND we.deleted_at IS NULL
        AND w.deleted_at IS NULL
      ORDER BY w.name ASC
      LIMIT ?3
      ''',
      variables: [
        Variable<String>(userId),
        Variable<String>(ghostExerciseId),
        Variable<int>(maxWorkoutNames),
      ],
    ).get();
    final names = <String>[
      for (final r in rows) r.read<String>('workout_name'),
    ];

    final workoutCount = await _count(
      '''
      SELECT COUNT(DISTINCT workout_id) AS c
      FROM workout_exercises
      WHERE user_id = ? AND exercise_id = ? AND deleted_at IS NULL
      ''',
      userId,
      ghostExerciseId,
    );

    return GhostExerciseUsageSummary(
      workoutNames: names,
      workoutCount: workoutCount,
    );
  }

  Future<GhostExerciseRemapPreview> previewForUser({
    required String userId,
    required String ghostExerciseId,
  }) async {
    final workoutExercises = await _count(
      'SELECT COUNT(*) AS c FROM workout_exercises '
      'WHERE user_id = ? AND exercise_id = ? AND deleted_at IS NULL',
      userId,
      ghostExerciseId,
    );
    final executionSets = await _count(
      'SELECT COUNT(*) AS c FROM execution_sets '
      'WHERE user_id = ? AND exercise_id = ? AND deleted_at IS NULL',
      userId,
      ghostExerciseId,
    );
    final progressionRules = await _count(
      'SELECT COUNT(*) AS c FROM progression_rules '
      'WHERE user_id = ? AND exercise_id = ? AND deleted_at IS NULL',
      userId,
      ghostExerciseId,
    );
    return GhostExerciseRemapPreview(
      workoutExercises: workoutExercises,
      executionSets: executionSets,
      progressionRules: progressionRules,
    );
  }

  Future<GhostExerciseRemapPreview> remapForUser({
    required String userId,
    required String ghostExerciseId,
    required String targetExerciseId,
  }) async {
    if (ghostExerciseId == targetExerciseId) {
      return previewForUser(userId: userId, ghostExerciseId: ghostExerciseId);
    }

    final targetExists = await _db
        .customSelect(
          'SELECT 1 FROM exercises WHERE id = ? AND deleted_at IS NULL LIMIT 1',
          variables: [Variable<String>(targetExerciseId)],
        )
        .getSingleOrNull();
    if (targetExists == null) {
      throw StateError('Target exercise $targetExerciseId not found in catalog');
    }

    return _db.transaction(() async {
      final now = DateTime.now().toUtc();
      final nowVar = Variable<DateTime>(now);

      await _db.customUpdate(
        '''
        DELETE FROM workout_exercises
        WHERE user_id = ?1
          AND exercise_id = ?2
          AND deleted_at IS NULL
          AND EXISTS (
            SELECT 1 FROM workout_exercises we2
            WHERE we2.user_id = ?1
              AND we2.workout_id = workout_exercises.workout_id
              AND we2.exercise_id = ?3
              AND we2.deleted_at IS NULL
          )
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
        ],
      );

      await _db.customUpdate(
        '''
        UPDATE workout_exercises
        SET exercise_id = ?3, is_dirty = 1, updated_at = ?4
        WHERE user_id = ?1 AND exercise_id = ?2 AND deleted_at IS NULL
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
          nowVar,
        ],
      );

      await _db.customUpdate(
        '''
        DELETE FROM execution_sets
        WHERE user_id = ?1
          AND exercise_id = ?2
          AND deleted_at IS NULL
          AND EXISTS (
            SELECT 1 FROM execution_sets es2
            WHERE es2.user_id = ?1
              AND es2.execution_id = execution_sets.execution_id
              AND es2.exercise_id = ?3
              AND es2.set_number = execution_sets.set_number
              AND es2.deleted_at IS NULL
          )
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
        ],
      );

      await _db.customUpdate(
        '''
        UPDATE execution_sets
        SET exercise_id = ?3, is_dirty = 1, updated_at = ?4
        WHERE user_id = ?1 AND exercise_id = ?2 AND deleted_at IS NULL
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
          nowVar,
        ],
      );

      await _db.customUpdate(
        '''
        DELETE FROM progression_rules
        WHERE user_id = ?1
          AND exercise_id = ?2
          AND deleted_at IS NULL
          AND EXISTS (
            SELECT 1 FROM progression_rules pr2
            WHERE pr2.user_id = ?1
              AND pr2.program_id = progression_rules.program_id
              AND pr2.exercise_id = ?3
              AND pr2.deleted_at IS NULL
          )
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
        ],
      );

      await _db.customUpdate(
        '''
        UPDATE progression_rules
        SET exercise_id = ?3, is_dirty = 1, updated_at = ?4
        WHERE user_id = ?1 AND exercise_id = ?2 AND deleted_at IS NULL
        ''',
        variables: [
          Variable<String>(userId),
          Variable<String>(ghostExerciseId),
          Variable<String>(targetExerciseId),
          nowVar,
        ],
      );

      return previewForUser(userId: userId, ghostExerciseId: ghostExerciseId);
    });
  }

  Future<int> _count(String sql, String userId, String exerciseId) async {
    final row = await _db
        .customSelect(
          sql,
          variables: [
            Variable<String>(userId),
            Variable<String>(exerciseId),
          ],
        )
        .getSingle();
    return row.read<int>('c');
  }
}
