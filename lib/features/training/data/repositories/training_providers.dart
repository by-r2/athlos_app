import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_user_id.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/repositories/cycle_repository.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/program_repository.dart';
import '../../domain/repositories/progression_rule_repository.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import '../../domain/usecases/finish_workout_execution.dart';
import '../../domain/usecases/apply_planned_workout_edit.dart';
import '../../domain/usecases/promote_ad_hoc_workout.dart';
import '../../domain/usecases/start_ad_hoc_workout_execution.dart';
import '../../domain/usecases/substitute_workout_exercise.dart';
import '../training_dao_providers.dart';
import 'cycle_repository_impl.dart';
import 'exercise_repository_impl.dart';
import 'program_repository_impl.dart';
import 'progression_rule_repository_impl.dart';
import 'workout_execution_repository_impl.dart';
import 'workout_repository_impl.dart';

part 'training_providers.g.dart';

String _requireUserId(Ref ref) {
  final userId = ref.watch(authProvider).value?.id;
  if (!isValidSyncUserId(userId)) {
    throw StateError('Training repositories require an authenticated user');
  }
  return userId!;
}

@riverpod
ExerciseRepository exerciseRepository(Ref ref) => ExerciseRepositoryImpl(
  ref.watch(exerciseDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  _requireUserId(ref),
);

@riverpod
WorkoutRepository workoutRepository(Ref ref) => WorkoutRepositoryImpl(
  ref.watch(workoutDaoProvider),
  ref.watch(cycleStepDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  ref.watch(trainingRemoteClientProvider),
  _requireUserId(ref),
);

@riverpod
WorkoutExecutionRepository workoutExecutionRepository(Ref ref) =>
    WorkoutExecutionRepositoryImpl(
      ref.watch(workoutExecutionDaoProvider),
      _requireUserId(ref),
    );

@riverpod
CycleRepository cycleRepository(Ref ref) => CycleRepositoryImpl(
  ref.watch(cycleStepDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  ref.watch(trainingRemoteClientProvider),
  _requireUserId(ref),
);

@riverpod
ProgramRepository programRepository(Ref ref) => ProgramRepositoryImpl(
  ref.watch(programDaoProvider),
  ref.watch(userOwnedSyncRunnerProvider),
  _requireUserId(ref),
);

@riverpod
ProgressionRuleRepository progressionRuleRepository(Ref ref) =>
    ProgressionRuleRepositoryImpl(
      ref.watch(progressionRuleDaoProvider),
      ref.watch(userOwnedSyncRunnerProvider),
      _requireUserId(ref),
    );

@riverpod
CompleteSetUseCase completeSetUseCase(Ref ref) =>
    CompleteSetUseCase(ref.watch(workoutExecutionRepositoryProvider));

@riverpod
FinishWorkoutExecution finishWorkoutExecution(Ref ref) =>
    FinishWorkoutExecution(
      ref.watch(workoutExecutionRepositoryProvider),
      ref.watch(workoutRepositoryProvider),
      ref.watch(programRepositoryProvider),
      ref.watch(exerciseRepositoryProvider),
    );

@riverpod
StartAdHocWorkoutExecution startAdHocWorkoutExecution(Ref ref) =>
    StartAdHocWorkoutExecution(ref.watch(workoutRepositoryProvider));

@riverpod
PromoteAdHocWorkout promoteAdHocWorkout(Ref ref) => PromoteAdHocWorkout(
  ref.watch(workoutRepositoryProvider),
  ref.watch(cycleRepositoryProvider),
);

@riverpod
ApplyPlannedWorkoutEdit applyPlannedWorkoutEdit(Ref ref) =>
    ApplyPlannedWorkoutEdit(ref.watch(workoutRepositoryProvider));

@riverpod
SubstituteWorkoutExercise substituteWorkoutExercise(Ref ref) =>
    const SubstituteWorkoutExercise();
