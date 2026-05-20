import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/user_owned_collection_sync_engine.dart';
import '../training_dao_providers.dart';
import 'training_remote_client.dart';
import 'training_sync_refs.dart';
import 'user_cycle_step_sync_adapter.dart';
import 'user_execution_set_sync_adapter.dart';
import 'user_exercise_sync_adapter.dart';
import 'user_program_sync_adapter.dart';
import 'user_progression_rule_sync_adapter.dart';
import 'user_workout_execution_sync_adapter.dart';
import 'user_workout_sync_adapter.dart';

part 'training_sync_providers.g.dart';

@Riverpod(keepAlive: true)
TrainingRemoteClient trainingRemoteClient(Ref ref) => TrainingRemoteClient();

@Riverpod(keepAlive: true)
TrainingSyncRefs trainingSyncRefs(Ref ref) => TrainingSyncRefs(
  store: ref.watch(syncRecordStoreProvider),
  exerciseDao: ref.watch(exerciseDaoProvider),
  workoutDao: ref.watch(workoutDaoProvider),
  programDao: ref.watch(programDaoProvider),
  executionDao: ref.watch(workoutExecutionDaoProvider),
  remoteClient: ref.watch(trainingRemoteClientProvider),
);

@Riverpod(keepAlive: true)
UserExerciseSyncAdapter userExerciseSyncAdapter(Ref ref) => UserExerciseSyncAdapter(
  ref.watch(exerciseDaoProvider),
  remoteClient: ref.watch(trainingRemoteClientProvider),
);

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userExerciseCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userExerciseSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserWorkoutSyncAdapter userWorkoutSyncAdapter(Ref ref) => UserWorkoutSyncAdapter(
  ref.watch(workoutDaoProvider),
  ref.watch(exerciseDaoProvider),
  ref.watch(syncRecordStoreProvider),
  remoteClient: ref.watch(trainingRemoteClientProvider),
);

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userWorkoutCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userWorkoutSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserProgramSyncAdapter userProgramSyncAdapter(Ref ref) => UserProgramSyncAdapter(
  ref.watch(programDaoProvider),
  remoteClient: ref.watch(trainingRemoteClientProvider),
);

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userProgramCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userProgramSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserProgressionRuleSyncAdapter userProgressionRuleSyncAdapter(Ref ref) =>
    UserProgressionRuleSyncAdapter(
      ref.watch(progressionRuleDaoProvider),
      ref.watch(trainingSyncRefsProvider),
      remoteClient: ref.watch(trainingRemoteClientProvider),
    );

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userProgressionRuleCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userProgressionRuleSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserCycleStepSyncAdapter userCycleStepSyncAdapter(Ref ref) => UserCycleStepSyncAdapter(
  ref.watch(cycleStepDaoProvider),
  ref.watch(trainingSyncRefsProvider),
  remoteClient: ref.watch(trainingRemoteClientProvider),
);

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userCycleStepCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userCycleStepSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserWorkoutExecutionSyncAdapter userWorkoutExecutionSyncAdapter(Ref ref) =>
    UserWorkoutExecutionSyncAdapter(
      ref.watch(workoutExecutionDaoProvider),
      ref.watch(trainingSyncRefsProvider),
      remoteClient: ref.watch(trainingRemoteClientProvider),
    );

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userWorkoutExecutionCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userWorkoutExecutionSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserExecutionSetSyncAdapter userExecutionSetSyncAdapter(Ref ref) =>
    UserExecutionSetSyncAdapter(
      ref.watch(workoutExecutionDaoProvider),
      ref.watch(trainingSyncRefsProvider),
      remoteClient: ref.watch(trainingRemoteClientProvider),
    );

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine userExecutionSetCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(userExecutionSetSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );
