import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../errors/result.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/data/repositories/profile_providers.dart';
import '../../features/profile/presentation/providers/body_metric_notifier.dart';
import '../../features/profile/presentation/providers/body_metrics_dashboard_provider.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';

part 'user_data_sync_coordinator.g.dart';

class UserDataSyncCoordinator {
  const UserDataSyncCoordinator(this._ref);

  final Ref _ref;

  Future<void> reconcileOnSessionChange() async {
    final profileRepository = _ref.read(userProfileRepositoryProvider);
    final profileResult = await profileRepository.reconcileOnAuth();
    profileResult.getOrThrow();

    final bodyMetricRepository = _ref.read(bodyMetricRepositoryProvider);
    final bodyMetricResult = await bodyMetricRepository.reconcileOnAuth();
    bodyMetricResult.getOrThrow();

    _ref.invalidate(profileProvider);
    _ref.invalidate(hasProfileProvider);
    _invalidateBodyMetricProviders();
  }

  Future<void> retryPendingUserDataSync() async {
    final profileRepository = _ref.read(userProfileRepositoryProvider);
    final profileResult = await profileRepository.pushPendingLocalChanges();
    profileResult.getOrThrow();

    final bodyMetricRepository = _ref.read(bodyMetricRepositoryProvider);
    final bodyMetricResult =
        await bodyMetricRepository.pushPendingLocalChanges();
    bodyMetricResult.getOrThrow();

    _ref.invalidate(profileProvider);
    _invalidateBodyMetricProviders();
  }

  void _invalidateBodyMetricProviders() {
    _ref.invalidate(bodyMetricListProvider);
    _ref.invalidate(bodyMetricsDashboardProvider);
    _ref.invalidate(latestBodyWeightProvider);
  }
}

@Riverpod(keepAlive: true)
UserDataSyncCoordinator userDataSyncCoordinator(Ref ref) =>
    UserDataSyncCoordinator(ref);

@Riverpod(keepAlive: true)
void userProfileCloudSyncListener(Ref ref) {
  ref.listen(authProvider, (previous, next) {
    final previousUser = previous?.value;
    final nextUser = next.value;
    if (previousUser?.id == nextUser?.id) return;

    unawaited(
      ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange(),
    );
  });
}
