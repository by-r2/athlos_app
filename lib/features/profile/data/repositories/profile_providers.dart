import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/repositories/body_metric_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import 'body_metric_repository_impl.dart';
import 'user_profile_repository_impl.dart';
import '../../../../core/sync/sync_providers.dart';

part 'profile_providers.g.dart';

@riverpod
UserProfileRepository userProfileRepository(Ref ref) =>
    UserProfileRepositoryImpl(
      ref.watch(userProfileDaoProvider),
      ref.watch(userProfileSingletonSyncEngineProvider),
    );

@riverpod
BodyMetricRepository bodyMetricRepository(Ref ref) =>
    BodyMetricRepositoryImpl(
      ref.watch(bodyMetricDaoProvider),
      ref.watch(syncRecordStoreProvider),
      ref.watch(bodyMetricCollectionSyncEngineProvider),
    );
