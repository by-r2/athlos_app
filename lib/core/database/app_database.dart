import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tables/catalog_governance_applied_rules_table.dart';
import 'tables/catalog_governance_events_table.dart';
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
import '../../features/training/data/datasources/equipment_seeder.dart';
import '../../features/training/data/datasources/exercise_seeder.dart';
import '../../features/training/domain/enums/exercise_type.dart';
import '../../features/training/domain/enums/movement_pattern.dart';
import '../../features/training/domain/enums/muscle_role.dart';
import '../../features/training/data/datasources/daos/cycle_step_dao.dart';
import '../../features/training/data/datasources/daos/equipment_dao.dart';
import '../../features/training/data/datasources/daos/exercise_dao.dart';
import '../../features/training/data/datasources/daos/program_dao.dart';
import '../../features/training/data/datasources/daos/progression_rule_dao.dart';
import '../../features/training/data/datasources/daos/workout_dao.dart';
import '../../features/training/data/datasources/daos/workout_execution_dao.dart';
import '../../features/training/data/datasources/tables/cycle_steps_table.dart';
import '../../features/training/data/datasources/tables/equipments_table.dart';
import '../../features/training/data/datasources/tables/execution_set_segments_table.dart';
import '../../features/training/data/datasources/tables/execution_sets_table.dart';
import '../../features/training/data/datasources/tables/exercise_equipments_table.dart';
import '../../features/training/data/datasources/tables/exercise_target_muscles_table.dart';
import '../../features/training/data/datasources/tables/exercise_variations_table.dart';
import '../../features/training/data/datasources/tables/exercises_table.dart';
import '../../features/training/data/datasources/tables/user_equipments_table.dart';
import '../../features/training/domain/enums/equipment_category.dart';
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
    // Training
    Equipments,
    Exercises,
    ExerciseEquipments,
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
    UserEquipments,
    CatalogGovernanceEvents,
    CatalogGovernanceAppliedRules,
    LocalDuplicateFeedback,
    // Profile
    UserProfiles,
    BodyMetrics,
  ],
  daos: [
    EquipmentDao,
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
  int get schemaVersion => 29;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedEquipments(this);
      await seedExercises(this);
      if (_shouldSeedDevData) await seedDevData(this);
    },
    onUpgrade: (m, from, to) async {
      if (_shouldSeedDevData && from >= 3 && from <= 28) {
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
        await seedEquipments(this);
        await seedExercises(this);
        await seedDevData(this);
        return;
      }

      if (from < 2) {
        // Rename restSeconds → rest
        await customStatement(
          'ALTER TABLE workout_exercises RENAME COLUMN rest_seconds TO rest',
        );

        // New column: exercises.type (default 'strength')
        await customStatement(
          "ALTER TABLE exercises ADD COLUMN type TEXT NOT NULL DEFAULT '${ExerciseType.strength.name}'",
        );

        // New column: workout_exercises.duration (nullable int)
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN duration INTEGER',
        );

        // Make workout_exercises.reps nullable via table recreation.
        // SQLite doesn't support ALTER COLUMN to drop NOT NULL, so we
        // recreate the table preserving data.
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

        // Make execution_sets.planned_reps and reps nullable, add
        // duration and distance columns via table recreation.
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

        // Seed new equipment and exercises
        await seedEquipmentsV2(this);
        await seedExercisesV2(this);
      }

      if (from < 3) {
        await customStatement(
          "ALTER TABLE exercise_target_muscles ADD COLUMN role TEXT NOT NULL DEFAULT 'primary'",
        );
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN movement_pattern TEXT',
        );
        await seedEquipmentsV3(this);
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
        // Create the old cycle_steps schema (with step_type) via raw SQL
        // so this migration stays stable regardless of the current Drift schema.
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
        await seedEquipmentsV4(this);
        await seedExercisesV4(this);
      }

      if (from < 9) {
        await customStatement(
          'ALTER TABLE workout_exercises ADD COLUMN is_unilateral INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 10) {
        await customStatement(
          'ALTER TABLE equipments ADD COLUMN catalog_remote_id TEXT',
        );
        await customStatement(
          'ALTER TABLE exercises ADD COLUMN catalog_remote_id TEXT',
        );
      }

      if (from < 11) {
        await seedEquipmentsV5(this);
        await seedExercisesV5(this);
      }

      if (from < 12) {
        await m.createTable(catalogGovernanceEvents);
        await m.createTable(catalogGovernanceAppliedRules);
      }

      if (from < 13) {
        await m.createTable(localDuplicateFeedback);
      }

      if (from < 14) {
        // Phase 1: simplify cycle — remove rest steps, drop stepType column,
        // make workoutId non-nullable, compact ordering.
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
        // Phase 2: rep ranges + AMRAP — replace reps with minReps/maxReps,
        // add isAmrap. Existing fixed reps → min == max.
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
        // Phase 6a: RPE — optional perceived exertion per set.
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN rpe INTEGER',
        );
      }

      if (from < 17) {
        // Phase 7: warmup sets — excluded from volume and progression.
        await customStatement(
          'ALTER TABLE execution_sets ADD COLUMN is_warmup INTEGER NOT NULL DEFAULT 0',
        );
      }

      if (from < 18) {
        // Phase 3: Training Program (mesocycle).
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
        // Phase 4: Deload strategy columns on programs.
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
        // Phase 5: Progression rules per exercise within a program.
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
        // Phase 6d: Bodyweight exercise flag.
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
        // Phase 9: Body weight timeline.
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
        // L/R tracking for unilateral exercises.
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
        // Migrate profile.weight into body_metrics, then drop the column.
        await customStatement('''
          INSERT INTO body_metrics (weight, recorded_at)
          SELECT weight, CAST(strftime('%s','now') AS INTEGER)
          FROM user_profiles
          WHERE weight IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM body_metrics)
        ''');
        await customStatement(
          'ALTER TABLE user_profiles DROP COLUMN weight',
        );
      }

      if (from < 25) {
        // Mandatory program model: eliminate free cycle, make programId
        // non-nullable on cycle_steps and workout_executions, add
        // exercise_config_snapshot for robust history.

        // 1. Ensure at least one program exists.
        final anyProgram = await customSelect(
          'SELECT id FROM programs LIMIT 1',
        ).getSingleOrNull();
        int defaultProgramId;
        if (anyProgram != null) {
          final activeProgram = await customSelect(
            'SELECT id FROM programs WHERE is_active = 1 LIMIT 1',
          ).getSingleOrNull();
          defaultProgramId = activeProgram?.read<int>('id') ??
              anyProgram.read<int>('id');
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

        // 2. Migrate free cycle steps into the default program, then delete
        //    remaining orphans.
        await customStatement(
          'UPDATE cycle_steps SET program_id = $defaultProgramId '
          'WHERE program_id IS NULL',
        );

        // 3. Migrate orphaned workout executions.
        await customStatement(
          'UPDATE workout_executions SET program_id = $defaultProgramId '
          'WHERE program_id IS NULL',
        );

        // 4. Recreate cycle_steps with program_id NOT NULL.
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

        // 5. Recreate workout_executions with program_id NOT NULL +
        //    exercise_config_snapshot column.
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

        // 6. Ensure the default program is active.
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
        // Convert legacy reps → duration for historical sets of isometric exercises.
        // Users stored seconds in the reps field as a workaround.
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

    },
  );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
