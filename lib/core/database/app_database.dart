import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/data/datasources/daos/user_profile_dao.dart';
import '../../features/profile/data/datasources/tables/user_profiles_table.dart';
import '../../features/profile/domain/enums/body_aesthetic.dart';
import '../../features/profile/domain/enums/selected_module.dart';
import '../../features/profile/domain/enums/training_goal.dart';
import '../../features/profile/domain/enums/training_style.dart';
import '../../features/training/data/datasources/dev_seeder.dart';
import '../../features/training/data/datasources/equipment_seeder.dart';
import '../../features/training/data/datasources/exercise_seeder.dart';
import '../../features/training/domain/enums/exercise_type.dart';
import '../../features/training/domain/enums/movement_pattern.dart';
import '../../features/training/domain/enums/muscle_role.dart';
import '../../features/training/data/datasources/daos/equipment_dao.dart';
import '../../features/training/data/datasources/daos/exercise_dao.dart';
import '../../features/training/data/datasources/daos/workout_dao.dart';
import '../../features/training/data/datasources/daos/workout_execution_dao.dart';
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
import '../../features/training/data/datasources/tables/workout_exercises_table.dart';
import '../../features/training/data/datasources/tables/workout_executions_table.dart';
import '../../features/training/data/datasources/tables/workouts_table.dart';

part 'app_database.g.dart';

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
    UserEquipments,
    // Profile
    UserProfiles,
  ],
  daos: [
    EquipmentDao,
    ExerciseDao,
    WorkoutDao,
    WorkoutExecutionDao,
    UserProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'athlos'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedEquipments(this);
          await seedExercises(this);
          if (kDebugMode) await seedDevData(this);
        },
        onUpgrade: (m, from, to) async {
          // Dev-only: wipe DB when upgrading from schema versions 3–10 so
          // developers get a clean baseline. Never runs in release (kDebugMode).
          if (kDebugMode && from >= 3 && from <= 10) {
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
        },
      );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
