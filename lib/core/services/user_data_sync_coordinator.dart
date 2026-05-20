import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/network_connectivity_provider.dart';
import '../../features/profile/presentation/providers/user_cloud_sync_status_provider.dart';
import 'cloud_sync_prefs.dart';
import '../services/supabase_config.dart';
import '../sync/sync_status.dart';
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
    if (!isSupabaseConfigured) return;
    if (_ref.read(authProvider).value == null) return;
    if (!_ref.read(isNetworkAvailableForSyncProvider)) return;

    final prefs = _ref.read(cloudSyncPrefsProvider);
    await prefs.recordAttempt();

    await _ref
        .read(userOwnedSyncRunnerProvider)
        .synchronizeAuthenticatedUserData(trigger: trigger);

    if (await _hasCleanSyncState()) {
      await prefs.recordSuccess();
    }

    _ref.invalidate(profileProvider);
    _ref.invalidate(hasProfileProvider);
    _ref.invalidate(userCloudSyncStatusProvider);
    _invalidateBodyMetricProviders();
  }

  Future<void> reconcileOnSessionChange() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.sessionChange);

  Future<void> retryPendingUserDataSync() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.resume);

  Future<bool> _hasCleanSyncState() async {
    final store = _ref.read(syncRecordStoreProvider);
    final tables = _ref
        .read(userOwnedSyncRegistryProvider)
        .targets
        .map((target) => target.tableName);
    for (final table in tables) {
      final records = await store.listForTable(table);
      for (final record in records) {
        if (record.status == SyncStatus.pending ||
            record.status == SyncStatus.failed) {
          return false;
        }
      }
    }
    return true;
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
void userDataCloudSyncListener(Ref ref) {
  ref.watch(networkConnectivityProvider);
  ref.listen(authProvider, (previous, next) {
    final previousUser = previous?.value;
    final nextUser = next.value;
    if (previousUser?.id == nextUser?.id) return;

    unawaited(
      ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange(),
    );
  });
}

@Riverpod(keepAlive: true)
void userDataCloudSyncConnectivityListener(Ref ref) {
  ref.listen(networkConnectivityProvider, (previous, next) {
    final wasOnline = previous?.value ?? false;
    final isOnline = next.value ?? false;
    if (wasOnline || !isOnline) return;
    if (ref.read(authProvider).value == null) return;

    unawaited(
      ref
          .read(userDataSyncCoordinatorProvider)
          .synchronizeAuthenticatedUserData(trigger: SyncTrigger.connectivity),
    );
  });
}
