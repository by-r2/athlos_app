import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/sync_record_dao.dart';
import '../../domain/repositories/body_metric_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/body_metric_remote_data_source.dart';
import '../datasources/daos/body_metric_dao.dart';
import '../datasources/daos/user_profile_dao.dart';
import '../datasources/user_profile_remote_data_source.dart';
import 'body_metric_repository_impl.dart';
import 'user_profile_repository_impl.dart';

part 'profile_providers.g.dart';

@riverpod
SyncRecordDao syncRecordDao(Ref ref) =>
    SyncRecordDao(ref.watch(appDatabaseProvider));

@riverpod
UserProfileDao userProfileDao(Ref ref) =>
    UserProfileDao(ref.watch(appDatabaseProvider));

@riverpod
UserProfileRepository userProfileRepository(Ref ref) =>
    UserProfileRepositoryImpl(
      ref.watch(userProfileDaoProvider),
      remoteDataSource: ref.watch(userProfileRemoteDataSourceProvider),
    );

@riverpod
UserProfileRemoteDataSource userProfileRemoteDataSource(Ref ref) =>
    UserProfileRemoteDataSource();

@riverpod
BodyMetricDao bodyMetricDao(Ref ref) =>
    BodyMetricDao(ref.watch(appDatabaseProvider));

@riverpod
BodyMetricRepository bodyMetricRepository(Ref ref) =>
    BodyMetricRepositoryImpl(
      ref.watch(bodyMetricDaoProvider),
      ref.watch(syncRecordDaoProvider),
      remoteGateway: ref.watch(bodyMetricRemoteDataSourceProvider),
    );

@riverpod
BodyMetricRemoteDataSource bodyMetricRemoteDataSource(Ref ref) =>
    BodyMetricRemoteDataSource();
