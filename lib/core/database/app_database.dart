import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'exercise_canonical_merge.dart';
import 'exercise_migration_maps.dart';
import 'tables/local_duplicate_feedback_table.dart';
import '../../features/profile/data/datasources/daos/body_metric_dao.dart';
import '../../features/profile/data/datasources/daos/user_profile_dao.dart';
import '../../features/profile/data/datasources/tables/body_metrics_table.dart';
import '../../features/profile/data/datasources/tables/user_profiles_table.dart';
import '../../features/profile/domain/enums/body_aesthetic.dart';
import '../../features/profile/domain/enums/experience_level.dart';
import '../../features/profile/domain/enums/gender.dart';
import '../../features/profile/domain/enums/selected_module.dart';
import '../../features/profile/domain/enums/training_goal.dart';
import '../../features/profile/domain/enums/training_style.dart';
import '../../features/training/data/datasources/dev_seeder.dart';
import '../../features/training/data/datasources/exercise_seeder.dart';
import '../../features/training/domain/enums/exercise_type.dart';
import '../../features/training/domain/enums/load_mode.dart';
import '../../features/training/domain/enums/movement_pattern.dart';
import '../../features/training/domain/enums/muscle_role.dart';
import '../../features/training/data/datasources/daos/cycle_step_dao.dart';
import '../../features/training/data/datasources/daos/exercise_dao.dart';
import '../../features/training/data/datasources/daos/program_dao.dart';
import '../../features/training/data/datasources/daos/progression_rule_dao.dart';
import '../../features/training/data/datasources/daos/workout_dao.dart';
import '../../features/training/data/datasources/daos/workout_execution_dao.dart';
import '../../features/training/data/datasources/tables/cycle_steps_table.dart';
import '../../features/training/data/datasources/tables/execution_set_segments_table.dart';
import '../../features/training/data/datasources/tables/execution_sets_table.dart';
import '../../features/training/data/datasources/tables/exercise_target_muscles_table.dart';
import '../../features/training/data/datasources/tables/exercise_variations_table.dart';
import '../../features/training/data/datasources/tables/exercises_table.dart';
import '../../features/training/domain/enums/muscle_group.dart';
import '../../features/training/domain/enums/muscle_region.dart';
import '../../features/training/domain/enums/target_muscle.dart';
import '../../features/training/data/datasources/tables/programs_table.dart';
import '../../features/training/data/datasources/tables/progression_rules_table.dart';
import '../../features/training/data/datasources/tables/workout_exercises_table.dart';
import '../../features/training/data/datasources/tables/workout_executions_table.dart';
import '../../features/training/data/datasources/tables/workouts_table.dart';

part 'app_database.g.dart';

const _skipDevSeed = bool.fromEnvironment('SKIP_DEV_SEED');

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseTargetMuscles,
    ExerciseVariations,
    Workouts,
    WorkoutExercises,
    WorkoutExecutions,
    ExecutionSets,
    ExecutionSetSegments,
    Programs,
    ProgressionRules,
    CycleSteps,
    LocalDuplicateFeedback,
    UserProfiles,
    BodyMetrics,
  ],
  daos: [
    ExerciseDao,
    ProgramDao,
    ProgressionRuleDao,
    WorkoutDao,
    WorkoutExecutionDao,
    CycleStepDao,
    UserProfileDao,
    BodyMetricDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  final bool _enableDevSeed;

  AppDatabase({bool enableDevSeed = true})
    : _enableDevSeed = enableDevSeed,
      super(driftDatabase(name: 'athlos'));

  AppDatabase.forTesting(super.executor, {bool enableDevSeed = false})
    : _enableDevSeed = enableDevSeed,
      super();

  bool get _shouldSeedDevData => kDebugMode && !_skipDevSeed && _enableDevSeed;

  @override
  int get schemaVersion => 40;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedExercises(this);
      if (_shouldSeedDevData) await seedDevData(this);
    },
    onUpgrade: (m, from, to) async {
      if (_shouldSeedDevData && from >= 3 && from <= 29) {
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
        await seedExercises(this);
        await seedDevData(this);
        return;
      }

      if (from < 2) {
        await customStatement(
          'ALTER TABLE workout_exercises RENAME COLUMN rest_seconds TO rest',
        );
        await customStatement(
          "ALTER TABLE exercises ADD COLUMN type TEXT NOT NULL DEFAULT '${ExerciseType.strength.name}'",
        );
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN duration INTEGER',
        );

        await customStatement('''
              CREATE TABLE workout_exercises_tmp (
                workout_id INTEGER NOT NULL REFERENCES workouts(id),
                exercise_id INTEGER NOT NULL REFERENCES exercises(id),
                "order" INTEGER NOT NULL,
                sets INTEGER NOT NULL,
                reps INTEGER,
                rest INTEGER NOT NULL DEFAULT 60,
                duration INTEGER,
                group_id INTEGER,
                PRIMARY KEY (workout_id, exercise_id)
              )
            ''');
        await customStatement('''
              INSERT INTO workout_exercises_tmp
                (workout_id, exercise_id, "order", sets, reps, rest, group_id)
              SELECT workout_id, exercise_id, "order", sets, reps, rest, group_id
              FROM workout_exercises
            ''');
        await customStatement('DROP TABLE workout_exercises');
        await customStatement(
          'ALTER TABLE workout_exercises_tmp RENAME TO workout_exercises',
        );

        await customStatement('''
              CREATE TABLE execution_sets_tmp (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                execution_id INTEGER NOT NULL REFERENCES workout_executions(id),
                exercise_id INTEGER NOT NULL REFERENCES exercises(id),
                set_number INTEGER NOT NULL,
                planned_reps INTEGER,
                planned_weight REAL,
                reps INTEGER,
                weight REAL,
                duration INTEGER,
                distance REAL,
                is_completed INTEGER NOT NULL DEFAULT 0,
                notes TEXT
              )
            ''');
        await customStatement('''
              INSERT INTO execution_sets_tmp
                (id, execution_id, exercise_id, set_number, planned_reps,
                 planned_weight, reps, weight, is_completed, notes)
              SELECT id, execution_id, exercise_id, set_number, planned_reps,
                     planned_weight, reps, weight, is_completed, notes
              FROM execution_sets
            ''');
        await customStatement('DROP TABLE execution_sets');
        await customStatement(
          'ALTER TABLE execution_sets_tmp RENAME TO execution_sets',
        );

        await seedExercisesV2(this);
      }

      if (from < 3) {
        await customStatement(
          "ALTER TABLE exercise_target_muscles ADD COLUMN role TEXT NOT NULL DEFAULT 'primary'",
        );
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN movement_pattern TEXT',
        );
        await seedExercisesV3(this);
      }

      if (from < 4) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN experience_level TEXT',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN training_frequency INTEGER',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN trains_at_gym INTEGER',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN injuries TEXT',
        );
        await customStatement('ALTER TABLE user_profiles ADD COLUMN bio TEXT');
      }

      if (from < 5) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN gender TEXT',
        );
      }

      if (from < 6) {
        await customStatement('''
          CREATE TABLE cycle_steps (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            order_index INTEGER NOT NULL,
            step_type TEXT NOT NULL,
            workout_id INTEGER REFERENCES workouts(id)
          )
        ''');
        final active = await customSelect(
          'SELECT id FROM workouts WHERE is_archived = 0 AND sort_order IS NOT NULL ORDER BY sort_order ASC',
        ).get();
        for (var i = 0; i < active.length; i++) {
          await customStatement(
            "INSERT INTO cycle_steps (order_index, step_type, workout_id) VALUES ($i, 'workout', ${active[i].read<int>('id')})",
          );
        }
      }

      if (from < 7) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN available_workout_minutes INTEGER',
        );
      }

      if (from < 8) {
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN notes TEXT',
        );
        await seedExercisesV4(this);
      }

      if (from < 9) {
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN is_unilateral INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 10) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN catalog_remote_id TEXT',
        );
      }

      if (from < 11) {
        await seedExercisesV5(this);
      }

      if (from < 12) {
        // Governance tables created here were later dropped in v40.
        // Raw SQL to avoid referencing deleted Drift table classes.
        await customStatement('''
          CREATE TABLE IF NOT EXISTS catalog_governance_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id INTEGER NOT NULL,
            payload TEXT,
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS catalog_governance_applied_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL,
            rule_type TEXT NOT NULL,
            applied_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      }

      if (from < 13) {
        await m.createTable(localDuplicateFeedback);
      }

      if (from < 14) {
        await customStatement(
          "DELETE FROM cycle_steps WHERE step_type = 'rest' OR workout_id IS NULL",
        );
        await customStatement('''
          CREATE TABLE cycle_steps_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            order_index INTEGER NOT NULL,
            workout_id INTEGER NOT NULL REFERENCES workouts(id)
          )
        ''');
        await customStatement('''
          INSERT INTO cycle_steps_tmp (order_index, workout_id)
          SELECT ROW_NUMBER() OVER (ORDER BY order_index) - 1, workout_id
          FROM cycle_steps
        ''');
        await customStatement('DROP TABLE cycle_steps');
        await customStatement(
          'ALTER TABLE cycle_steps_tmp RENAME TO cycle_steps',
        );
      }

      if (from < 15) {
        await customStatement(
          'ALTER TABLE workout_exercises RENAME COLUMN reps TO min_reps',
        );
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN max_reps INTEGER',
        );
        await customStatement(
          'UPDATE workout_exercises SET max_reps = min_reps',
        );
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN is_amrap INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 16) {
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN rpe INTEGER',
        );
      }

      if (from < 17) {
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN is_warmup INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 18) {
        await customStatement('''
          CREATE TABLE programs (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            focus TEXT NOT NULL,
            duration_mode TEXT NOT NULL,
            duration_value INTEGER NOT NULL,
            default_rest_seconds INTEGER,
            is_active INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            archived_at INTEGER
          )
        ''');
        await customStatement(
          'ALTER TABLE cycle_steps ADD COLUMN program_id INTEGER REFERENCES programs(id)',
        );
        await customStatement(
          'ALTER TABLE workout_executions ADD COLUMN program_id INTEGER REFERENCES programs(id)',
        );
      }

      if (from < 19) {
        await customStatement(
          'ALTER TABLE programs ADD COLUMN is_in_deload INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE programs ADD COLUMN deload_frequency INTEGER',
        );
        await customStatement(
          'ALTER TABLE programs ADD COLUMN deload_strategy TEXT',
        );
        await customStatement(
          'ALTER TABLE programs ADD COLUMN deload_volume_multiplier REAL',
        );
        await customStatement(
          'ALTER TABLE programs ADD COLUMN deload_intensity_multiplier REAL',
        );
      }

      if (from < 20) {
        await customStatement('''
          CREATE TABLE progression_rules (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL REFERENCES programs(id),
            exercise_id INTEGER NOT NULL REFERENCES exercises(id),
            type TEXT NOT NULL,
            value REAL NOT NULL,
            frequency TEXT NOT NULL,
            condition TEXT,
            condition_value REAL
          )
        ''');
      }

      if (from < 21) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN is_bodyweight INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement('''
          UPDATE exercises SET is_bodyweight = 1
          WHERE name IN (
            'pushUp','declinePushUp','inclinePushUp','kneePushUp',
            'pullUp','chinUp','invertedRow','pikePushUp',
            'diamondPushUp','dip','crunch','plank',
            'hangingLegRaise','gluteBridge'
          )
        ''');
      }

      if (from < 22) {
        await customStatement('''
          CREATE TABLE body_metrics (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            weight REAL NOT NULL,
            body_fat_percent REAL,
            recorded_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
          )
        ''');
      }

      if (from < 23) {
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN left_reps INTEGER',
        );
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN left_weight REAL',
        );
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN right_reps INTEGER',
        );
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN right_weight REAL',
        );
      }

      if (from < 24) {
        await customStatement('''
          INSERT INTO body_metrics (weight, recorded_at)
          SELECT weight, CAST(strftime('%s','now') AS INTEGER)
          FROM user_profiles
          WHERE weight IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM body_metrics)
        ''');
        await customStatement('ALTER TABLE user_profiles DROP COLUMN weight');
      }

      if (from < 25) {
        final anyProgram = await customSelect(
          'SELECT id FROM programs LIMIT 1',
        ).getSingleOrNull();
        int defaultProgramId;
        if (anyProgram != null) {
          final activeProgram = await customSelect(
            'SELECT id FROM programs WHERE is_active = 1 LIMIT 1',
          ).getSingleOrNull();
          defaultProgramId =
              activeProgram?.read<int>('id') ?? anyProgram.read<int>('id');
        } else {
          await customStatement('''
            INSERT INTO programs (name, focus, duration_mode, duration_value, is_active, created_at)
            VALUES ('Meu Programa', 'hypertrophy', 'sessions', 12, 1,
                    CAST(strftime('%s','now') AS INTEGER))
          ''');
          final newRow = await customSelect(
            'SELECT last_insert_rowid() AS id',
          ).getSingle();
          defaultProgramId = newRow.read<int>('id');
        }

        await customStatement(
          'UPDATE cycle_steps SET program_id = $defaultProgramId '
          'WHERE program_id IS NULL',
        );

        await customStatement(
          'UPDATE workout_executions SET program_id = $defaultProgramId '
          'WHERE program_id IS NULL',
        );

        await customStatement('''
          CREATE TABLE cycle_steps_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL REFERENCES programs(id),
            order_index INTEGER NOT NULL,
            workout_id INTEGER NOT NULL REFERENCES workouts(id)
          )
        ''');
        await customStatement('''
          INSERT INTO cycle_steps_tmp (id, program_id, order_index, workout_id)
          SELECT id, program_id, order_index, workout_id FROM cycle_steps
        ''');
        await customStatement('DROP TABLE cycle_steps');
        await customStatement(
          'ALTER TABLE cycle_steps_tmp RENAME TO cycle_steps',
        );

        await customStatement('''
          CREATE TABLE workout_executions_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            workout_id INTEGER NOT NULL REFERENCES workouts(id),
            program_id INTEGER NOT NULL REFERENCES programs(id),
            started_at INTEGER NOT NULL,
            finished_at INTEGER,
            notes TEXT,
            exercise_config_snapshot TEXT
          )
        ''');
        await customStatement('''
          INSERT INTO workout_executions_tmp
            (id, workout_id, program_id, started_at, finished_at, notes)
          SELECT id, workout_id, program_id, started_at, finished_at, notes
          FROM workout_executions
        ''');
        await customStatement('DROP TABLE workout_executions');
        await customStatement(
          'ALTER TABLE workout_executions_tmp RENAME TO workout_executions',
        );

        final hasActive = await customSelect(
          'SELECT id FROM programs WHERE is_active = 1 LIMIT 1',
        ).getSingleOrNull();
        if (hasActive == null) {
          await customStatement(
            'UPDATE programs SET is_active = 1 WHERE id = $defaultProgramId',
          );
        }
      }

      if (from < 26) {
        await seedExercisesV6(this);
      }

      if (from < 27) {
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN is_unilateral INTEGER',
        );
      }

      if (from < 28) {
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN is_isometric INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          "UPDATE exercises SET is_isometric = 1 WHERE name = 'plank'",
        );
        await customStatement('''
          UPDATE execution_sets
          SET duration = reps, reps = NULL
          WHERE exercise_id IN (SELECT id FROM exercises WHERE is_isometric = 1)
            AND duration IS NULL
            AND reps IS NOT NULL
        ''');
        await seedExercisesV7(this);
      }

      if (from < 29) {
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN current_cycle_streak INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN best_cycle_streak INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN current_frequency_streak INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN best_frequency_streak INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN training_streaks_schema INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 30) {
        // Move owned equipment from `user_equipments` (FK to legacy `equipments`)
        // into a free-text JSON list on `user_profiles`. Drop catalog tables.
        await customStatement(
          'ALTER TABLE user_profiles ADD COLUMN owned_equipment_names TEXT',
        );

        final ownedRows = await customSelect(
          'SELECT e.name AS name '
          'FROM user_equipments u '
          'INNER JOIN equipments e ON e.id = u.equipment_id',
        ).get();
        final ownedNames = <String>[];
        for (final row in ownedRows) {
          final name = row.read<String?>('name')?.trim();
          if (name != null && name.isNotEmpty && !ownedNames.contains(name)) {
            ownedNames.add(name);
          }
        }
        if (ownedNames.isNotEmpty) {
          final encoded = jsonEncode(ownedNames);
          await customUpdate(
            'UPDATE user_profiles SET owned_equipment_names = ?',
            variables: [Variable<String>(encoded)],
          );
        }

        await customStatement('DROP TABLE IF EXISTS exercise_equipments');
        await customStatement('DROP TABLE IF EXISTS user_equipments');
        await customStatement('DROP TABLE IF EXISTS equipments');

        for (final entry in kExerciseRenamePreV30ToCanonical.entries) {
          await customUpdate(
            'UPDATE exercises SET name = ? WHERE name = ?',
            variables: [
              Variable<String>(entry.value),
              Variable<String>(entry.key),
            ],
          );
        }

        // Same migration: collapse rows that differ only by bar / preacher station /
        // rope vs bar on cable pushdown (`kExerciseMergeLosersIntoKeeper`).
        await applyExerciseCanonicalMerges(this);
      }

      if (from < 31) {
        await seedExercisesV8(this);
      }

      if (from < 32) {
        await seedExercisesV9(this);
      }

      if (from < 33) {
        await seedExercisesV33(this);
      }

      if (from < 34) {
        // Add the new structured load mode columns alongside the legacy
        // `is_bodyweight` flag so the migration can read both during the
        // transition.
        await customStatement(
          "ALTER TABLE exercises ADD COLUMN default_load_mode TEXT "
          "NOT NULL DEFAULT '${LoadMode.weighted.name}'",
        );
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN bodyweight_load_factor REAL',
        );
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN load_mode_override TEXT',
        );

        // Migrate the legacy boolean into the new enum column. Everything
        // that was `is_bodyweight = 1` becomes the bodyweight load mode.
        await customStatement(
          "UPDATE exercises SET default_load_mode = '${LoadMode.bodyweight.name}' "
          "WHERE is_bodyweight = 1",
        );

        // Apply load factors from the literature (Ebben et al. 2011 JSCR /
        // ExRx via de Leva). Isometrics keep `bodyweight_load_factor = NULL`
        // because their volume is duration-based, not reps × load.
        await seedExercisesV34(this);

        // Drop the legacy `is_bodyweight` column via recreate-and-copy
        // (matches the pattern used by earlier table-shape migrations and
        // works on every SQLite version, including pre-3.35 devices).
        await customStatement('''
          CREATE TABLE exercises_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            catalog_remote_id TEXT,
            name TEXT NOT NULL,
            muscle_group TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'strength',
            movement_pattern TEXT,
            description TEXT,
            is_verified INTEGER NOT NULL DEFAULT 0,
            default_load_mode TEXT NOT NULL DEFAULT 'weighted',
            bodyweight_load_factor REAL,
            is_isometric INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await customStatement('''
          INSERT INTO exercises_tmp
            (id, catalog_remote_id, name, muscle_group, type, movement_pattern,
             description, is_verified, default_load_mode, bodyweight_load_factor,
             is_isometric)
          SELECT id, catalog_remote_id, name, muscle_group, type, movement_pattern,
                 description, is_verified, default_load_mode, bodyweight_load_factor,
                 is_isometric
          FROM exercises
        ''');
        await customStatement('DROP TABLE exercises');
        await customStatement('ALTER TABLE exercises_tmp RENAME TO exercises');
      }

      if (from < 35) {
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN body_weight_snapshot REAL',
        );
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN load_mode_override TEXT',
        );

        // Drop `execution_sets.notes` via recreate-and-copy for broad SQLite
        // compatibility (pre-3.35).
        await customStatement('''
          CREATE TABLE execution_sets_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            execution_id INTEGER NOT NULL REFERENCES workout_executions(id),
            exercise_id INTEGER NOT NULL REFERENCES exercises(id),
            set_number INTEGER NOT NULL,
            planned_reps INTEGER,
            planned_weight REAL,
            reps INTEGER,
            weight REAL,
            duration INTEGER,
            distance REAL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            is_warmup INTEGER NOT NULL DEFAULT 0,
            rpe INTEGER,
            body_weight_snapshot REAL,
            load_mode_override TEXT,
            left_reps INTEGER,
            left_weight REAL,
            right_reps INTEGER,
            right_weight REAL,
            is_unilateral INTEGER
          )
        ''');
        await customStatement('''
          INSERT INTO execution_sets_tmp
            (id, execution_id, exercise_id, set_number, planned_reps,
             planned_weight, reps, weight, duration, distance, is_completed,
             is_warmup, rpe, body_weight_snapshot, load_mode_override, left_reps,
             left_weight, right_reps, right_weight, is_unilateral)
          SELECT id, execution_id, exercise_id, set_number, planned_reps,
                 planned_weight, reps, weight, duration, distance, is_completed,
                 is_warmup, rpe, body_weight_snapshot, load_mode_override, left_reps,
                 left_weight, right_reps, right_weight, is_unilateral
          FROM execution_sets
        ''');
        await customStatement('DROP TABLE execution_sets');
        await customStatement(
          'ALTER TABLE execution_sets_tmp RENAME TO execution_sets',
        );

        // Drop `workout_executions.notes` via recreate-and-copy.
        await customStatement('''
          CREATE TABLE workout_executions_tmp (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            workout_id INTEGER NOT NULL REFERENCES workouts(id),
            program_id INTEGER NOT NULL REFERENCES programs(id),
            started_at INTEGER NOT NULL,
            finished_at INTEGER,
            exercise_config_snapshot TEXT
          )
        ''');
        await customStatement('''
          INSERT INTO workout_executions_tmp
            (id, workout_id, program_id, started_at, finished_at, exercise_config_snapshot)
          SELECT id, workout_id, program_id, started_at, finished_at, exercise_config_snapshot
          FROM workout_executions
        ''');
        await customStatement('DROP TABLE workout_executions');
        await customStatement(
          'ALTER TABLE workout_executions_tmp RENAME TO workout_executions',
        );
      }

      if (from < 36) {
        await _addColumnIfNotExists(
          table: 'user_profiles',
          column: 'remote_user_id',
          definition: 'TEXT',
        );
        await _addColumnIfNotExists(
          table: 'user_profiles',
          column: 'last_synced_at',
          definition: 'INTEGER',
        );
        await customStatement('''
          CREATE TABLE IF NOT EXISTS sync_records (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            local_id INTEGER NOT NULL,
            sync_id TEXT NOT NULL,
            remote_id TEXT,
            remote_user_id TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            last_pushed_at INTEGER,
            deleted_at INTEGER
          )
        ''');
      }

      if (from < 37) {
        await _addColumnIfNotExists(
          table: 'body_metrics',
          column: 'remote_id',
          definition: 'TEXT',
        );
        await _addColumnIfNotExists(
          table: 'body_metrics',
          column: 'last_synced_at',
          definition: 'INTEGER',
        );
      }

      if (from < 38) {
        await _addColumnIfNotExists(
          table: 'user_profiles',
          column: 'local_updated_at',
          definition: 'INTEGER',
        );
        await _addColumnIfNotExists(
          table: 'body_metrics',
          column: 'local_updated_at',
          definition: 'INTEGER',
        );
        await _addColumnIfNotExists(
          table: 'sync_records',
          column: 'last_pushed_at',
          definition: 'INTEGER',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS sync_records_table_remote_id_idx '
          'ON sync_records(table_name, remote_id)',
        );
      }

      if (from < 39) {
        for (final table in [
          'exercises',
          'workouts',
          'programs',
          'workout_executions',
          'execution_sets',
          'progression_rules',
          'cycle_steps',
        ]) {
          if (!await _tableExists(table)) continue;
          await _addColumnIfNotExists(
            table: table,
            column: 'remote_id',
            definition: 'TEXT',
          );
          await _addColumnIfNotExists(
            table: table,
            column: 'last_synced_at',
            definition: 'INTEGER',
          );
          await _addColumnIfNotExists(
            table: table,
            column: 'local_updated_at',
            definition: 'INTEGER',
          );
        }
      }

      if (from < 40) {
        await _migrateToUuidFirst(m);
      }
    },
  );

  Future<void> _migrateToUuidFirst(Migrator m) async {
    // UUID v5 namespace for catalog exercises (same as Supabase migration)
    const ns = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

    // --- Helper: generate UUID v4 in pure SQL (via randomblob) ---
    const uuidV4Expr =
        "lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || "
        "substr(hex(randomblob(2)),2) || '-' || "
        "substr('89ab', abs(random()) % 4 + 1, 1) || "
        "substr(hex(randomblob(2)),2) || '-' || hex(randomblob(6)))";

    // --- 1. Create new exercises table with TEXT PK ---
    await customStatement('''
      CREATE TABLE exercises_new (
        id TEXT NOT NULL PRIMARY KEY,
        created_by TEXT,
        is_verified INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'strength',
        movement_pattern TEXT,
        description TEXT,
        default_load_mode TEXT NOT NULL DEFAULT 'weighted',
        bodyweight_load_factor REAL,
        is_isometric INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Build UUID mapping for exercises (old INT id → new UUID)
    await customStatement('''
      CREATE TEMP TABLE _exercise_id_map (
        old_id INTEGER NOT NULL,
        new_id TEXT NOT NULL
      )
    ''');

    // For verified exercises: use a placeholder UUID based on name hash.
    // Real UUID v5 will be assigned by the seeder after migration.
    final exerciseRows = await customSelect(
      'SELECT id, name, is_verified FROM exercises',
    ).get();

    for (final row in exerciseRows) {
      final oldId = row.read<int>('id');
      final name = row.read<String>('name');
      final isVerified = row.read<bool>('is_verified');

      String newId;
      if (isVerified) {
        newId = uuid5(ns, name);
      } else {
        newId = uuid4();
      }

      await customStatement(
        "INSERT INTO _exercise_id_map (old_id, new_id) VALUES ($oldId, '$newId')",
      );
    }

    // Copy exercises with new UUIDs
    await customStatement('''
      INSERT INTO exercises_new (id, created_by, is_verified, name, muscle_group, type,
        movement_pattern, description, default_load_mode, bodyweight_load_factor,
        is_isometric, updated_at, is_dirty)
      SELECT
        m.new_id, NULL, e.is_verified, e.name, e.muscle_group, e.type,
        e.movement_pattern, e.description, e.default_load_mode,
        e.bodyweight_load_factor, e.is_isometric,
        COALESCE(e.local_updated_at, strftime('%s','now')),
        CASE WHEN e.is_verified = 0 THEN 1 ELSE 0 END
      FROM exercises e
      JOIN _exercise_id_map m ON m.old_id = e.id
    ''');

    // --- 2. Workouts: INT → UUID ---
    await customStatement('''
      CREATE TABLE workouts_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        description TEXT,
        sort_order INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO workouts_new (id, name, description, sort_order, is_archived, created_at, updated_at)
      SELECT $uuidV4Expr, name, description, sort_order, is_archived, created_at,
        COALESCE(local_updated_at, strftime('%s','now'))
      FROM workouts
    ''');
    // Build workout mapping
    await customStatement('''
      CREATE TEMP TABLE _workout_id_map AS
      SELECT w.id AS old_id, wn.id AS new_id
      FROM workouts w
      JOIN workouts_new wn ON wn.name = w.name AND wn.created_at = w.created_at
    ''');

    // --- 3. Programs: INT → UUID ---
    await customStatement('''
      CREATE TABLE programs_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        focus TEXT NOT NULL,
        duration_mode TEXT NOT NULL,
        duration_value INTEGER NOT NULL,
        default_rest_seconds INTEGER,
        is_active INTEGER NOT NULL DEFAULT 0,
        is_in_deload INTEGER NOT NULL DEFAULT 0,
        deload_frequency INTEGER,
        deload_strategy TEXT,
        deload_volume_multiplier REAL,
        deload_intensity_multiplier REAL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        archived_at INTEGER,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO programs_new (id, name, focus, duration_mode, duration_value,
        default_rest_seconds, is_active, is_in_deload, deload_frequency,
        deload_strategy, deload_volume_multiplier, deload_intensity_multiplier,
        created_at, archived_at, updated_at)
      SELECT $uuidV4Expr, name, focus, duration_mode, duration_value,
        default_rest_seconds, is_active, is_in_deload, deload_frequency,
        deload_strategy, deload_volume_multiplier, deload_intensity_multiplier,
        created_at, archived_at, COALESCE(local_updated_at, strftime('%s','now'))
      FROM programs
    ''');
    await customStatement('''
      CREATE TEMP TABLE _program_id_map AS
      SELECT p.id AS old_id, pn.id AS new_id
      FROM programs p
      JOIN programs_new pn ON pn.name = p.name AND pn.created_at = p.created_at
    ''');

    // --- 4. Workout Exercises: composite PK → UUID PK ---
    await customStatement('''
      CREATE TABLE workout_exercises_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        workout_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        sets INTEGER NOT NULL DEFAULT 1,
        min_reps INTEGER,
        max_reps INTEGER,
        is_amrap INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER DEFAULT 60,
        duration_seconds INTEGER,
        group_id INTEGER,
        is_unilateral INTEGER NOT NULL DEFAULT 0,
        load_mode_override TEXT,
        notes TEXT,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO workout_exercises_new (id, workout_id, exercise_id, sort_order,
        sets, min_reps, max_reps, is_amrap, rest_seconds, duration_seconds,
        group_id, is_unilateral, load_mode_override, notes)
      SELECT $uuidV4Expr, wm.new_id, em.new_id, we."order",
        we.sets, we.min_reps, we.max_reps, we.is_amrap, we.rest, we.duration,
        we.group_id, we.is_unilateral, we.load_mode_override, we.notes
      FROM workout_exercises we
      JOIN _workout_id_map wm ON wm.old_id = we.workout_id
      JOIN _exercise_id_map em ON em.old_id = we.exercise_id
    ''');

    // --- 5. Workout Executions: INT → UUID ---
    await customStatement('''
      CREATE TABLE workout_executions_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        workout_id TEXT NOT NULL,
        program_id TEXT NOT NULL,
        started_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        finished_at INTEGER,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO workout_executions_new (id, workout_id, program_id, started_at,
        finished_at, updated_at)
      SELECT $uuidV4Expr, wm.new_id, pm.new_id, we.started_at,
        we.finished_at, COALESCE(we.local_updated_at, strftime('%s','now'))
      FROM workout_executions we
      JOIN _workout_id_map wm ON wm.old_id = we.workout_id
      JOIN _program_id_map pm ON pm.old_id = we.program_id
    ''');
    await customStatement('''
      CREATE TEMP TABLE _execution_id_map AS
      SELECT we.id AS old_id, wen.id AS new_id
      FROM workout_executions we
      JOIN workout_executions_new wen ON wen.started_at = we.started_at
    ''');

    // --- 6. Execution Sets: INT → UUID ---
    await customStatement('''
      CREATE TABLE execution_sets_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        execution_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        planned_reps INTEGER,
        planned_weight REAL,
        reps INTEGER,
        weight REAL,
        duration_seconds INTEGER,
        distance_meters REAL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        rpe INTEGER,
        body_weight_snapshot REAL,
        load_mode_override TEXT,
        left_reps INTEGER,
        left_weight REAL,
        right_reps INTEGER,
        right_weight REAL,
        is_unilateral INTEGER,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO execution_sets_new (id, execution_id, exercise_id, set_number,
        planned_reps, planned_weight, reps, weight, duration_seconds, distance_meters,
        is_completed, is_warmup, rpe, body_weight_snapshot, load_mode_override,
        left_reps, left_weight, right_reps, right_weight, is_unilateral, updated_at)
      SELECT $uuidV4Expr, exm.new_id, em.new_id, es.set_number,
        es.planned_reps, es.planned_weight, es.reps, es.weight, es.duration, es.distance,
        es.is_completed, es.is_warmup, es.rpe, es.body_weight_snapshot,
        es.load_mode_override, es.left_reps, es.left_weight, es.right_reps,
        es.right_weight, es.is_unilateral,
        COALESCE(es.local_updated_at, strftime('%s','now'))
      FROM execution_sets es
      JOIN _execution_id_map exm ON exm.old_id = es.execution_id
      JOIN _exercise_id_map em ON em.old_id = es.exercise_id
    ''');

    // --- 7. Execution Set Segments: INT → UUID ---
    await customStatement('''
      CREATE TABLE execution_set_segments_new (
        id TEXT NOT NULL PRIMARY KEY,
        execution_set_id TEXT NOT NULL,
        segment_order INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        weight REAL
      )
    ''');
    await customStatement('''
      CREATE TEMP TABLE _es_id_map AS
      SELECT es.id AS old_id, esn.id AS new_id
      FROM execution_sets es
      JOIN execution_sets_new esn ON esn.set_number = es.set_number
        AND esn.execution_id = (SELECT new_id FROM _execution_id_map WHERE old_id = es.execution_id)
    ''');
    await customStatement('''
      INSERT INTO execution_set_segments_new (id, execution_set_id, segment_order, reps, weight)
      SELECT $uuidV4Expr, esm.new_id, seg.segment_order, seg.reps, seg.weight
      FROM execution_set_segments seg
      JOIN _es_id_map esm ON esm.old_id = seg.execution_set_id
    ''');

    // --- 8. Progression Rules: INT → UUID ---
    await customStatement('''
      CREATE TABLE progression_rules_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        program_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        type TEXT NOT NULL,
        value REAL NOT NULL,
        frequency TEXT NOT NULL,
        condition TEXT,
        condition_value REAL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO progression_rules_new (id, program_id, exercise_id, type, value,
        frequency, condition, condition_value, updated_at)
      SELECT $uuidV4Expr, pm.new_id, em.new_id, pr.type, pr.value,
        pr.frequency, pr.condition, pr.condition_value,
        COALESCE(pr.local_updated_at, strftime('%s','now'))
      FROM progression_rules pr
      JOIN _program_id_map pm ON pm.old_id = pr.program_id
      JOIN _exercise_id_map em ON em.old_id = pr.exercise_id
    ''');

    // --- 9. Cycle Steps: INT → UUID ---
    await customStatement('''
      CREATE TABLE cycle_steps_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        program_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        workout_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO cycle_steps_new (id, program_id, order_index, workout_id, updated_at)
      SELECT $uuidV4Expr, pm.new_id, cs.order_index, wm.new_id,
        COALESCE(cs.local_updated_at, strftime('%s','now'))
      FROM cycle_steps cs
      JOIN _program_id_map pm ON pm.old_id = cs.program_id
      JOIN _workout_id_map wm ON wm.old_id = cs.workout_id
    ''');

    // --- 10. Body Metrics: INT → UUID ---
    await customStatement('''
      CREATE TABLE body_metrics_new (
        id TEXT NOT NULL PRIMARY KEY,
        user_id TEXT NOT NULL DEFAULT '',
        weight REAL NOT NULL,
        body_fat_percent REAL,
        recorded_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        deleted_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO body_metrics_new (id, weight, body_fat_percent, recorded_at, updated_at)
      SELECT $uuidV4Expr, bm.weight, bm.body_fat_percent, bm.recorded_at,
        COALESCE(bm.local_updated_at, strftime('%s','now'))
      FROM body_metrics bm
    ''');

    // --- 11. User Profiles: INT → UUID (PK = auth user id) ---
    await customStatement('''
      CREATE TABLE user_profiles_new (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT,
        height REAL,
        age INTEGER,
        goal TEXT,
        body_aesthetic TEXT,
        training_style TEXT,
        experience_level TEXT,
        gender TEXT,
        training_frequency INTEGER,
        available_workout_minutes INTEGER,
        trains_at_gym INTEGER,
        injuries TEXT,
        bio TEXT,
        owned_equipment_names TEXT,
        last_active_module TEXT NOT NULL DEFAULT 'training',
        current_cycle_streak INTEGER NOT NULL DEFAULT 0,
        best_cycle_streak INTEGER NOT NULL DEFAULT 0,
        current_frequency_streak INTEGER NOT NULL DEFAULT 0,
        best_frequency_streak INTEGER NOT NULL DEFAULT 0,
        training_streaks_schema INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        is_dirty INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await customStatement('''
      INSERT INTO user_profiles_new (id, name, height, age, goal, body_aesthetic,
        training_style, experience_level, gender, training_frequency,
        available_workout_minutes, trains_at_gym, injuries, bio,
        owned_equipment_names, last_active_module, current_cycle_streak,
        best_cycle_streak, current_frequency_streak, best_frequency_streak,
        training_streaks_schema, updated_at)
      SELECT COALESCE(remote_user_id, $uuidV4Expr), name, height, age, goal,
        body_aesthetic, training_style, experience_level, gender,
        training_frequency, available_workout_minutes, trains_at_gym, injuries,
        bio, owned_equipment_names, last_active_module, current_cycle_streak,
        best_cycle_streak, current_frequency_streak, best_frequency_streak,
        training_streaks_schema, COALESCE(local_updated_at, strftime('%s','now'))
      FROM user_profiles
    ''');

    // --- 12. Exercise Target Muscles: update FK ---
    await customStatement('''
      CREATE TABLE exercise_target_muscles_new (
        exercise_id TEXT NOT NULL,
        target_muscle TEXT NOT NULL,
        muscle_region TEXT,
        role TEXT NOT NULL DEFAULT 'primary',
        PRIMARY KEY (exercise_id, target_muscle)
      )
    ''');
    await customStatement('''
      INSERT INTO exercise_target_muscles_new (exercise_id, target_muscle, muscle_region, role)
      SELECT em.new_id, etm.target_muscle, etm.muscle_region, etm.role
      FROM exercise_target_muscles etm
      JOIN _exercise_id_map em ON em.old_id = etm.exercise_id
    ''');

    // --- 13. Exercise Variations: update FK ---
    await customStatement('''
      CREATE TABLE exercise_variations_new (
        exercise_id TEXT NOT NULL,
        variation_id TEXT NOT NULL,
        PRIMARY KEY (exercise_id, variation_id)
      )
    ''');
    await customStatement('''
      INSERT INTO exercise_variations_new (exercise_id, variation_id)
      SELECT em1.new_id, em2.new_id
      FROM exercise_variations ev
      JOIN _exercise_id_map em1 ON em1.old_id = ev.exercise_id
      JOIN _exercise_id_map em2 ON em2.old_id = ev.variation_id
    ''');

    // --- 14. Drop old tables and rename ---
    await customStatement('DROP TABLE IF EXISTS execution_set_segments');
    await customStatement('DROP TABLE IF EXISTS execution_sets');
    await customStatement('DROP TABLE IF EXISTS workout_executions');
    await customStatement('DROP TABLE IF EXISTS progression_rules');
    await customStatement('DROP TABLE IF EXISTS cycle_steps');
    await customStatement('DROP TABLE IF EXISTS workout_exercises');
    await customStatement('DROP TABLE IF EXISTS exercise_target_muscles');
    await customStatement('DROP TABLE IF EXISTS exercise_variations');
    await customStatement('DROP TABLE IF EXISTS workouts');
    await customStatement('DROP TABLE IF EXISTS programs');
    await customStatement('DROP TABLE IF EXISTS exercises');
    await customStatement('DROP TABLE IF EXISTS body_metrics');
    await customStatement('DROP TABLE IF EXISTS user_profiles');
    await customStatement('DROP TABLE IF EXISTS sync_records');
    await customStatement('DROP TABLE IF EXISTS catalog_governance_events');
    await customStatement('DROP TABLE IF EXISTS catalog_governance_applied_rules');

    await customStatement('ALTER TABLE exercises_new RENAME TO exercises');
    await customStatement('ALTER TABLE workouts_new RENAME TO workouts');
    await customStatement('ALTER TABLE programs_new RENAME TO programs');
    await customStatement('ALTER TABLE workout_exercises_new RENAME TO workout_exercises');
    await customStatement('ALTER TABLE workout_executions_new RENAME TO workout_executions');
    await customStatement('ALTER TABLE execution_sets_new RENAME TO execution_sets');
    await customStatement('ALTER TABLE execution_set_segments_new RENAME TO execution_set_segments');
    await customStatement('ALTER TABLE progression_rules_new RENAME TO progression_rules');
    await customStatement('ALTER TABLE cycle_steps_new RENAME TO cycle_steps');
    await customStatement('ALTER TABLE body_metrics_new RENAME TO body_metrics');
    await customStatement('ALTER TABLE user_profiles_new RENAME TO user_profiles');
    await customStatement('ALTER TABLE exercise_target_muscles_new RENAME TO exercise_target_muscles');
    await customStatement('ALTER TABLE exercise_variations_new RENAME TO exercise_variations');

    // --- 15. Drop temp tables ---
    await customStatement('DROP TABLE IF EXISTS _exercise_id_map');
    await customStatement('DROP TABLE IF EXISTS _workout_id_map');
    await customStatement('DROP TABLE IF EXISTS _program_id_map');
    await customStatement('DROP TABLE IF EXISTS _execution_id_map');
    await customStatement('DROP TABLE IF EXISTS _es_id_map');

    // --- 16. Re-seed exercises with correct UUID v5 ---
    await seedExercises(this);
  }

  /// Generate UUID v5 using SHA-1 (pure Dart implementation for migration).
  static String uuid5(String namespace, String name) {
    final nsBytes = _parseUuid(namespace);
    final nameBytes = utf8.encode(name);
    final data = [...nsBytes, ...nameBytes];
    final hash = _sha1(data);
    hash[6] = (hash[6] & 0x0f) | 0x50;
    hash[8] = (hash[8] & 0x3f) | 0x80;
    final hex = hash.sublist(0, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Generate UUID v4 (random).
  static String uuid4() {
    final rng = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static List<int> _parseUuid(String uuid) {
    final hex = uuid.replaceAll('-', '');
    return List.generate(16, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
  }

  static List<int> _sha1(List<int> data) {
    var h0 = 0x67452301;
    var h1 = 0xEFCDAB89;
    var h2 = 0x98BADCFE;
    var h3 = 0x10325476;
    var h4 = 0xC3D2E1F0;
    final bitLen = data.length * 8;
    data.add(0x80);
    while (data.length % 64 != 56) {
      data.add(0);
    }
    for (var i = 56; i >= 0; i -= 8) {
      data.add((bitLen >> i) & 0xff);
    }
    for (var chunk = 0; chunk < data.length; chunk += 64) {
      final w = List<int>.filled(80, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = (data[chunk + i * 4] << 24) |
            (data[chunk + i * 4 + 1] << 16) |
            (data[chunk + i * 4 + 2] << 8) |
            data[chunk + i * 4 + 3];
      }
      for (var i = 16; i < 80; i++) {
        w[i] = _rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      }
      var a = h0, b = h1, c = h2, d = h3, e = h4;
      for (var i = 0; i < 80; i++) {
        int f, k;
        if (i < 20) { f = (b & c) | (~b & d); k = 0x5A827999; }
        else if (i < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1; }
        else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC; }
        else { f = b ^ c ^ d; k = 0xCA62C1D6; }
        final temp = (_rotl(a, 5) + f + e + k + w[i]) & 0xFFFFFFFF;
        e = d; d = c; c = _rotl(b, 30); b = a; a = temp;
      }
      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
    }
    final result = <int>[];
    for (final h in [h0, h1, h2, h3, h4]) {
      result.add((h >> 24) & 0xff);
      result.add((h >> 16) & 0xff);
      result.add((h >> 8) & 0xff);
      result.add(h & 0xff);
    }
    return result;
  }

  static int _rotl(int n, int count) =>
      ((n << count) | (n >> (32 - count))) & 0xFFFFFFFF;

  Future<bool> _tableExists(String table) async {
    final row = await customSelect(
      "SELECT 1 AS present FROM sqlite_master "
      "WHERE type = 'table' AND name = '$table' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }

  Future<bool> _tableHasColumn(String table, String column) async {
    final rows = await customSelect("PRAGMA table_info('$table')").get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  Future<void> _addColumnIfNotExists({
    required String table,
    required String column,
    required String definition,
  }) async {
    if (await _tableHasColumn(table, column)) return;
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _createTableIfNotExists(Migrator m, TableInfo table) async {
    final tableName = table.actualTableName;
    final exists = await customSelect(
      "SELECT 1 AS present FROM sqlite_master "
      "WHERE type = 'table' AND name = '$tableName' LIMIT 1",
    ).getSingleOrNull();
    if (exists != null) return;
    await m.createTable(table);
  }
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
