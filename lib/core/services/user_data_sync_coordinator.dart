import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/network_connectivity_provider.dart';
import '../../features/profile/presentation/providers/user_cloud_sync_status_provider.dart';
import 'account_data_isolation_service.dart';
import 'cloud_sync_prefs.dart';
import '../services/supabase_config.dart';
import '../sync/sync_trigger.dart';
import '../sync/sync_providers.dart';
import '../../features/profile/presentation/providers/body_metric_notifier.dart';
import '../../features/profile/presentation/providers/body_metrics_dashboard_provider.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/training/presentation/providers/active_execution_notifier.dart';
import '../../features/training/presentation/providers/exercise_notifier.dart';
import '../../features/training/presentation/providers/program_notifier.dart';
import '../../features/training/presentation/providers/workout_execution_notifier.dart';
import '../../features/training/presentation/providers/workout_notifier.dart';

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

    await prefs.recordSuccess();

    _invalidateUserDataProviders();
  }

  Future<void> reconcileOnSessionChange() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.sessionChange);

  Future<void> retryPendingUserDataSync() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.resume);

  void _invalidateUserDataProviders() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(hasProfileProvider);
    _ref.invalidate(userCloudSyncStatusProvider);
    _ref.invalidate(bodyMetricListProvider);
    _ref.invalidate(bodyMetricsDashboardProvider);
    _ref.invalidate(latestBodyWeightProvider);
    _ref.invalidate(pendingSyncDirtyCountProvider);
    _invalidateTrainingProviders();
  }

  void _invalidateTrainingProviders() {
    _ref.invalidate(workoutListProvider);
    _ref.invalidate(archivedWorkoutListProvider);
    _ref.invalidate(exerciseListProvider);
    _ref.invalidate(programListProvider);
    _ref.invalidate(activeProgramProvider);
    _ref.invalidate(workoutExecutionListProvider);
    _ref.invalidate(activeExecutionProvider);
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

    unawaited(_onAuthSessionChanged(ref, previousUser, nextUser));
  });
}

Future<void> _onAuthSessionChanged(
  Ref ref,
  AuthUser? previousUser,
  AuthUser? nextUser,
) async {
  try {
    if (nextUser != null) {
      final isolation = ref.read(accountDataIsolationServiceProvider);
      if (await isolation.hasOrphanedUserData()) {
        await isolation.claimOrphanedData(nextUser.id);
        await isolation.markAllDirtyForUser(nextUser.id);
      }
      await isolation.purgeStaleProfiles(nextUser.id);
    }

    await ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange();
  } on Exception catch (e) {
    debugPrint('[UserDataSync] session change handling failed: $e');
  }
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
