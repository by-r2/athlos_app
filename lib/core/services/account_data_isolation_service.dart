import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../providers/last_module_provider.dart'; // sharedPreferencesProvider

part 'account_data_isolation_service.g.dart';

/// Wipes local user-owned data on logout and claims orphaned rows on first login.
class AccountDataIsolationService {
  AccountDataIsolationService(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  static const _orphanUserId = '';

  /// Whether legacy local rows still have an empty [user_id] from pre-auth usage.
  Future<bool> hasOrphanedUserData() async {
    final result = await _db.customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM workouts WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM workout_exercises WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM programs WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM progression_rules WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM cycle_steps WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM workout_executions WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM execution_sets WHERE user_id = ?1) +
        (SELECT COUNT(*) FROM body_metrics WHERE user_id = ?1) AS total
      ''',
      variables: [Variable.withString(_orphanUserId)],
    ).getSingle();
    return result.read<int>('total') > 0;
  }

  /// Assigns orphaned local rows to [userId] after account creation or first login.
  Future<void> claimOrphanedData(String userId) async {
    await _db.transaction(() async {
      for (final table in _userOwnedTablesWithUserId) {
        await _db.customUpdate(
          'UPDATE $table SET user_id = ? WHERE user_id = ?',
          variables: [Variable<String>(userId), Variable<String>(_orphanUserId)],
          updates: {},
        );
      }

      await _db.customUpdate(
        'UPDATE exercises SET created_by = ? '
        'WHERE created_by = ? AND is_verified = 0',
        variables: [Variable<String>(userId), Variable<String>(_orphanUserId)],
        updates: {_db.exercises},
      );

      final profiles = await _db.select(_db.userProfiles).get();
      final hasCorrectProfile = profiles.any((p) => p.id == userId);
      if (hasCorrectProfile) {
        for (final profile in profiles) {
          if (profile.id == userId) continue;
          await _db.customUpdate(
            'DELETE FROM user_profiles WHERE id = ?',
            variables: [Variable<String>(profile.id)],
            updates: {_db.userProfiles},
          );
        }
      } else if (profiles.isNotEmpty) {
        final first = profiles.first;
        await _db.customUpdate(
          'UPDATE user_profiles SET id = ? WHERE id = ?',
          variables: [Variable<String>(userId), Variable<String>(first.id)],
          updates: {_db.userProfiles},
        );
        for (final profile in profiles.skip(1)) {
          await _db.customUpdate(
            'DELETE FROM user_profiles WHERE id = ?',
            variables: [Variable<String>(profile.id)],
            updates: {_db.userProfiles},
          );
        }
      }
    });
  }

  /// Removes stale profile rows that don't belong to [userId].
  Future<void> purgeStaleProfiles(String userId) async {
    await _db.customUpdate(
      'DELETE FROM user_profiles WHERE id != ?',
      variables: [Variable<String>(userId)],
      updates: {_db.userProfiles},
    );
  }

  /// Marks all user-owned rows dirty so the next sync pushes them to the remote.
  Future<void> markAllDirtyForUser(String userId) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.workouts)..where((w) => w.userId.equals(userId)))
          .write(WorkoutsCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await (_db.update(_db.workoutExercises)
            ..where((we) => we.userId.equals(userId)))
          .write(
        WorkoutExercisesCompanion(isDirty: const Value(true), updatedAt: Value(now)),
      );
      await (_db.update(_db.programs)..where((p) => p.userId.equals(userId)))
          .write(ProgramsCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await (_db.update(_db.progressionRules)
            ..where((r) => r.userId.equals(userId)))
          .write(
        ProgressionRulesCompanion(isDirty: const Value(true), updatedAt: Value(now)),
      );
      await (_db.update(_db.cycleSteps)..where((s) => s.userId.equals(userId)))
          .write(CycleStepsCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await (_db.update(_db.workoutExecutions)
            ..where((e) => e.userId.equals(userId)))
          .write(
        WorkoutExecutionsCompanion(isDirty: const Value(true), updatedAt: Value(now)),
      );
      await (_db.update(_db.executionSets)..where((s) => s.userId.equals(userId)))
          .write(ExecutionSetsCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await (_db.update(_db.bodyMetrics)..where((m) => m.userId.equals(userId)))
          .write(BodyMetricsCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await (_db.update(_db.exercises)
            ..where(
              (e) => e.createdBy.equals(userId) & e.isVerified.equals(false),
            ))
          .write(ExercisesCompanion(isDirty: const Value(true), updatedAt: Value(now)));
      await _db.update(_db.userProfiles).write(
        const UserProfilesCompanion(isDirty: Value(true)),
      );
    });
  }

  /// Removes all user-owned local data and sync pull cursors (post-logout).
  Future<void> wipeUserData() async {
    await _db.transaction(() async {
      await _db.delete(_db.workoutExercises).go();
      await _db.delete(_db.executionSetSegments).go();
      await _db.delete(_db.executionSets).go();
      await _db.delete(_db.workoutExecutions).go();
      await _db.delete(_db.cycleSteps).go();
      await _db.delete(_db.progressionRules).go();
      await _db.delete(_db.programs).go();
      await _db.delete(_db.workouts).go();
      await _db.delete(_db.bodyMetrics).go();

      await _db.customUpdate(
        'DELETE FROM exercise_target_muscles WHERE exercise_id IN '
        '(SELECT id FROM exercises WHERE is_verified = 0)',
        updates: {_db.exerciseTargetMuscles},
      );
      await _db.customUpdate(
        'DELETE FROM exercise_variations WHERE exercise_id IN '
        '(SELECT id FROM exercises WHERE is_verified = 0) '
        'OR variation_id IN '
        '(SELECT id FROM exercises WHERE is_verified = 0)',
        updates: {_db.exerciseVariations},
      );

      await (_db.delete(_db.exercises)
            ..where((e) => e.isVerified.equals(false)))
          .go();
      await _db.delete(_db.userProfiles).go();
    });

    final keysToRemove = _prefs
        .getKeys()
        .where((key) => key.startsWith('sync_last_pull_'))
        .toList();
    for (final key in keysToRemove) {
      await _prefs.remove(key);
    }
  }

  static const _userOwnedTablesWithUserId = [
    'workouts',
    'workout_exercises',
    'programs',
    'progression_rules',
    'cycle_steps',
    'workout_executions',
    'execution_sets',
    'body_metrics',
  ];
}

@Riverpod(keepAlive: true)
AccountDataIsolationService accountDataIsolationService(Ref ref) =>
    AccountDataIsolationService(
      ref.watch(appDatabaseProvider),
      ref.watch(sharedPreferencesProvider),
    );
