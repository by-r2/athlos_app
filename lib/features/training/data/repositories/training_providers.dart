import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../profile/data/repositories/profile_providers.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/program_repository.dart';
import '../../domain/repositories/progression_rule_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import '../datasources/daos/cycle_step_dao.dart';
import '../datasources/daos/exercise_dao.dart';
import '../datasources/daos/program_dao.dart';
import '../datasources/daos/progression_rule_dao.dart';
import '../datasources/daos/workout_dao.dart';
import '../datasources/daos/workout_execution_dao.dart';
import 'cycle_repository_impl.dart';
import 'exercise_repository_impl.dart';
import 'program_repository_impl.dart';
import 'progression_rule_repository_impl.dart';
import 'workout_execution_repository_impl.dart';
import 'workout_repository_impl.dart';

part 'training_providers.g.dart';

// --- DAOs ---

@riverpod
ExerciseDao exerciseDao(Ref ref) =>
    ExerciseDao(ref.watch(appDatabaseProvider));

@riverpod
WorkoutDao workoutDao(Ref ref) =>
    WorkoutDao(ref.watch(appDatabaseProvider));

@riverpod
WorkoutExecutionDao workoutExecutionDao(Ref ref) =>
    WorkoutExecutionDao(ref.watch(appDatabaseProvider));

@riverpod
CycleStepDao cycleStepDao(Ref ref) =>
    CycleStepDao(ref.watch(appDatabaseProvider));

@riverpod
ProgramDao programDao(Ref ref) =>
    ProgramDao(ref.watch(appDatabaseProvider));

@riverpod
ProgressionRuleDao progressionRuleDao(Ref ref) =>
    ProgressionRuleDao(ref.watch(appDatabaseProvider));

// --- Repositories ---

@riverpod
ExerciseRepository exerciseRepository(Ref ref) =>
    ExerciseRepositoryImpl(ref.watch(exerciseDaoProvider));

@riverpod
WorkoutRepository workoutRepository(Ref ref) =>
    WorkoutRepositoryImpl(ref.watch(workoutDaoProvider));

@riverpod
WorkoutExecutionRepository workoutExecutionRepository(Ref ref) =>
    WorkoutExecutionRepositoryImpl(
      ref.watch(workoutExecutionDaoProvider),
      exerciseRepository: ref.watch(exerciseRepositoryProvider),
      workoutRepository: ref.watch(workoutRepositoryProvider),
      bodyMetricRepository: ref.watch(bodyMetricRepositoryProvider),
    );

@riverpod
CycleRepository cycleRepository(Ref ref) =>
    CycleRepositoryImpl(ref.watch(cycleStepDaoProvider));

@riverpod
ProgramRepository programRepository(Ref ref) =>
    ProgramRepositoryImpl(ref.watch(programDaoProvider));

@riverpod
ProgressionRuleRepository progressionRuleRepository(Ref ref) =>
    ProgressionRuleRepositoryImpl(ref.watch(progressionRuleDaoProvider));

// --- Use Cases ---

@riverpod
CompleteSetUseCase completeSetUseCase(Ref ref) =>
    CompleteSetUseCase(ref.watch(workoutExecutionRepositoryProvider));
