import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/data/datasources/body_metric_remote_data_source.dart';
import '../../features/profile/data/datasources/daos/body_metric_dao.dart';
import '../../features/profile/data/datasources/daos/user_profile_dao.dart';
import '../../features/profile/data/datasources/user_profile_remote_data_source.dart';
import '../../features/profile/data/sync/body_metric_sync_adapter.dart';
import '../../features/profile/data/sync/user_profile_sync_adapter.dart';
import '../../features/training/data/sync/training_remote_client.dart';
import '../../features/training/data/sync/training_sync_adapters.dart';
import '../../features/training/data/sync/training_sync_store.dart';
import '../database/app_database.dart';
import '../providers/last_module_provider.dart';
import '../services/supabase_config.dart';
import 'sync_engine_v2.dart';
import 'sync_issue_prefs.dart';
import 'sync_user_id.dart';
import 'user_owned_sync_runner.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
TrainingSyncStore trainingSyncStore(Ref ref) =>
    TrainingSyncStore(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
TrainingRemoteClient trainingRemoteClient(Ref ref) => TrainingRemoteClient();

@Riverpod(keepAlive: true)
Future<int> pendingSyncDirtyCount(Ref ref) async {
  final userId = ref.watch(authProvider).value?.id;
  if (!isValidSyncUserId(userId)) return 0;
  final uid = userId!;

  final training =
      await ref.watch(trainingSyncStoreProvider).countSyncableDirty(uid);
  final bodyMetrics =
      (await ref.watch(bodyMetricDaoProvider).getDirty(uid)).length;
  final bodyTombstones =
      (await ref
              .watch(bodyMetricDaoProvider)
              .getDirtyTombstones(uid))
          .length;
  final profileDirty =
      (await ref.watch(userProfileDaoProvider).getDirty()) != null ? 1 : 0;

  return training + bodyMetrics + bodyTombstones + profileDirty;
}

@Riverpod(keepAlive: true)
SyncEngineV2? syncEngineV2(Ref ref) {
  if (!isSupabaseConfigured) return null;
  final userId = ref.watch(authProvider).value?.id;
  if (!isValidSyncUserId(userId)) return null;
  final uid = userId!;

  final store = ref.watch(trainingSyncStoreProvider);
  final remote = ref.watch(trainingRemoteClientProvider);

  return SyncEngineV2(
    adapters: [
      UserProfileSyncAdapter(
        dao: ref.watch(userProfileDaoProvider),
        remote: ref.watch(userProfileRemoteDataSourceProvider),
      ),
      BodyMetricSyncAdapter(
        dao: ref.watch(bodyMetricDaoProvider),
        remote: ref.watch(bodyMetricRemoteDataSourceProvider),
        userId: uid,
      ),
      ...buildTrainingSyncAdapters(
        store: store,
        remote: remote,
        userId: uid,
      ),
    ],
    prefs: ref.watch(sharedPreferencesProvider),
    issuePrefs: SyncIssuePrefs(ref.watch(sharedPreferencesProvider)),
  );
}

@Riverpod(keepAlive: true)
UserOwnedSyncRunner userOwnedSyncRunner(Ref ref) {
  final engine = ref.watch(syncEngineV2Provider);
  if (engine == null) return UserOwnedSyncRunner.disabled();
  return UserOwnedSyncRunner(engine);
}

@Riverpod(keepAlive: true)
BodyMetricDao bodyMetricDao(Ref ref) =>
    BodyMetricDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
UserProfileDao userProfileDao(Ref ref) =>
    UserProfileDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
UserProfileRemoteDataSource userProfileRemoteDataSource(Ref ref) =>
    UserProfileRemoteDataSource();

@Riverpod(keepAlive: true)
BodyMetricRemoteDataSource bodyMetricRemoteDataSource(Ref ref) =>
    BodyMetricRemoteDataSource();
