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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedEquipments(this);
          await seedExercises(this);
          if (kDebugMode) await seedDevData(this);
        },
        onUpgrade: (m, from, to) async {
          // Dev databases used schema versions 1–10 before the first public
          // release. Wipe and recreate so developers get a clean baseline.
          if (from >= 2 && from <= 10) {
            for (final table in allTables) {
              await m.deleteTable(table.actualTableName);
            }
            await m.createAll();
            await seedEquipments(this);
            await seedExercises(this);
            if (kDebugMode) await seedDevData(this);
            return;
          }

          // Incremental migrations for public releases.
          // When bumping schemaVersion, run `dart run drift_dev make-migrations`
          // and use the generated stepByStep() / migrationSteps() here.
          // See: https://drift.simonbinder.eu/migrations/step_by_step/
        },
      );
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
