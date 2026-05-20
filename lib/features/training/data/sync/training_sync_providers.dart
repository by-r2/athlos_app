import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/user_owned_collection_sync_engine.dart';
import '../training_dao_providers.dart';
import 'training_remote_client.dart';
import 'user_exercise_sync_adapter.dart';
import 'user_workout_sync_adapter.dart';

part 'training_sync_providers.g.dart';

@Riverpod(keepAlive: true)
TrainingRemoteClient trainingRemoteClient(Ref ref) => TrainingRemoteClient();

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
