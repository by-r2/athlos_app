import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import 'datasources/daos/cycle_step_dao.dart';
import 'datasources/daos/exercise_dao.dart';
import 'datasources/daos/program_dao.dart';
import 'datasources/daos/progression_rule_dao.dart';
import 'datasources/daos/workout_dao.dart';
import 'datasources/daos/workout_execution_dao.dart';

part 'training_dao_providers.g.dart';

@riverpod
ExerciseDao exerciseDao(Ref ref) => ExerciseDao(ref.watch(appDatabaseProvider));

@riverpod
WorkoutDao workoutDao(Ref ref) => WorkoutDao(ref.watch(appDatabaseProvider));

@riverpod
WorkoutExecutionDao workoutExecutionDao(Ref ref) =>
    WorkoutExecutionDao(ref.watch(appDatabaseProvider));

@riverpod
CycleStepDao cycleStepDao(Ref ref) =>
    CycleStepDao(ref.watch(appDatabaseProvider));

@riverpod
ProgramDao programDao(Ref ref) => ProgramDao(ref.watch(appDatabaseProvider));

@riverpod
ProgressionRuleDao progressionRuleDao(Ref ref) =>
    ProgressionRuleDao(ref.watch(appDatabaseProvider));
