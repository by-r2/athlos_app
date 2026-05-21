import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_notifier.dart';
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
      ref.watch(userOwnedSyncRunnerProvider),
    );

@riverpod
BodyMetricRepository bodyMetricRepository(Ref ref) {
  final userId = ref.watch(authProvider).value?.id;
  if (userId == null) {
    throw StateError('BodyMetricRepository requires an authenticated user');
  }
  return BodyMetricRepositoryImpl(
    ref.watch(bodyMetricDaoProvider),
    ref.watch(userOwnedSyncRunnerProvider),
    userId,
  );
}
