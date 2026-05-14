import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../sync/sync_trigger.dart';
import '../sync/sync_providers.dart';
import '../../features/profile/presentation/providers/body_metric_notifier.dart';
import '../../features/profile/presentation/providers/body_metrics_dashboard_provider.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';

part 'user_data_sync_coordinator.g.dart';

class UserDataSyncCoordinator {
  const UserDataSyncCoordinator(this._ref);

  final Ref _ref;

  Future<void> synchronizeAuthenticatedUserData({
    required SyncTrigger trigger,
  }) async {
    await _ref
        .read(userOwnedSyncRunnerProvider)
        .synchronizeAuthenticatedUserData(trigger: trigger);

    _ref.invalidate(profileProvider);
    _ref.invalidate(hasProfileProvider);
    _invalidateBodyMetricProviders();
  }

  Future<void> reconcileOnSessionChange() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.sessionChange);

  Future<void> retryPendingUserDataSync() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.resume);

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
void userDataCloudSyncListener(Ref ref) {
  ref.listen(authProvider, (previous, next) {
    final previousUser = previous?.value;
    final nextUser = next.value;
    if (previousUser?.id == nextUser?.id) return;

    unawaited(
      ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange(),
    );
  });
}
