import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/user_owned_sync_runner.dart';
import '../sync/training_sync_table_names.dart';
import '../../../profile/data/repositories/profile_providers.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/program_repository.dart';
import '../../domain/repositories/progression_rule_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import '../training_dao_providers.dart';
import 'cycle_repository_impl.dart';
import 'exercise_repository_impl.dart';
import 'program_repository_impl.dart';
import 'progression_rule_repository_impl.dart';
import 'workout_execution_repository_impl.dart';
import 'workout_repository_impl.dart';

part 'training_providers.g.dart';

// --- Repositories ---

@riverpod
ExerciseRepository exerciseRepository(Ref ref) => ExerciseRepositoryImpl(
  ref.watch(exerciseDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  ref.watch(syncRecordStoreProvider),
);

@riverpod
WorkoutRepository workoutRepository(Ref ref) => WorkoutRepositoryImpl(
  ref.watch(workoutDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  ref.watch(syncRecordStoreProvider),
);

@riverpod
WorkoutExecutionRepository workoutExecutionRepository(Ref ref) =>
    WorkoutExecutionRepositoryImpl(
      ref.watch(workoutExecutionDaoProvider),
      ref.watch(userOwnedSyncRunnerProvider),
      ref.watch(syncRecordStoreProvider),
      exerciseRepository: ref.watch(exerciseRepositoryProvider),
      workoutRepository: ref.watch(workoutRepositoryProvider),
      bodyMetricRepository: ref.watch(bodyMetricRepositoryProvider),
    );

@riverpod
CycleRepository cycleRepository(Ref ref) => CycleRepositoryImpl(
  ref.watch(cycleStepDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
);

@riverpod
ProgramRepository programRepository(Ref ref) => ProgramRepositoryImpl(
  ref.watch(programDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  ref.watch(syncRecordStoreProvider),
);

@riverpod
ProgressionRuleRepository progressionRuleRepository(Ref ref) =>
    ProgressionRuleRepositoryImpl(
      ref.watch(progressionRuleDaoProvider),
      ref.watch(userOwnedSyncRunnerProvider),
      ref.watch(syncRecordStoreProvider),
    );

// --- Use Cases ---

@riverpod
CompleteSetUseCase completeSetUseCase(Ref ref) =>
    CompleteSetUseCase(ref.watch(workoutExecutionRepositoryProvider));
