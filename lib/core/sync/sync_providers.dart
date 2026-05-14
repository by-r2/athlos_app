import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/data/datasources/body_metric_remote_data_source.dart';
import '../../features/profile/data/datasources/daos/body_metric_dao.dart';
import '../../features/profile/data/datasources/daos/user_profile_dao.dart';
import '../../features/profile/data/datasources/user_profile_remote_data_source.dart';
import '../../features/profile/data/sync/body_metric_sync_adapter.dart';
import '../../features/profile/data/sync/user_profile_sync_adapter.dart';
import '../database/app_database.dart';
import '../database/daos/sync_record_dao.dart';
import 'sync_record_store.dart';
import 'user_owned_collection_sync_engine.dart';
import 'user_owned_singleton_sync_engine.dart';
import 'user_owned_sync_registry.dart';
import 'user_owned_sync_runner.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
SyncRecordStore syncRecordStore(Ref ref) =>
    SyncRecordStore(ref.watch(syncRecordDaoProvider));

@Riverpod(keepAlive: true)
BodyMetricSyncAdapter bodyMetricSyncAdapter(Ref ref) => BodyMetricSyncAdapter(
  ref.watch(bodyMetricDaoProvider),
  remoteGateway: ref.watch(bodyMetricRemoteDataSourceProvider),
);

@Riverpod(keepAlive: true)
UserOwnedCollectionSyncEngine bodyMetricCollectionSyncEngine(Ref ref) =>
    UserOwnedCollectionSyncEngine(
      adapter: ref.watch(bodyMetricSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserProfileSyncAdapter userProfileSyncAdapter(Ref ref) => UserProfileSyncAdapter(
  ref.watch(userProfileDaoProvider),
  remoteGateway: ref.watch(userProfileRemoteDataSourceProvider),
);

@Riverpod(keepAlive: true)
UserOwnedSingletonSyncEngine userProfileSingletonSyncEngine(Ref ref) =>
    UserOwnedSingletonSyncEngine(
      adapter: ref.watch(userProfileSyncAdapterProvider),
      store: ref.watch(syncRecordStoreProvider),
    );

@Riverpod(keepAlive: true)
UserOwnedSyncRegistry userOwnedSyncRegistry(Ref ref) => UserOwnedSyncRegistry([
  ref.watch(userProfileSingletonSyncEngineProvider),
  ref.watch(bodyMetricCollectionSyncEngineProvider),
]);

@Riverpod(keepAlive: true)
UserOwnedSyncRunner userOwnedSyncRunner(Ref ref) =>
    UserOwnedSyncRunner(ref.watch(userOwnedSyncRegistryProvider));

@Riverpod(keepAlive: true)
SyncRecordDao syncRecordDao(Ref ref) =>
    SyncRecordDao(ref.watch(appDatabaseProvider));

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
