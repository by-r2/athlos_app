import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/network_connectivity_provider.dart';
import '../../features/profile/presentation/providers/user_cloud_sync_status_provider.dart';
import 'cloud_sync_prefs.dart';
import '../services/account_data_isolation_service.dart';
import '../services/supabase_config.dart';
import '../sync/sync_user_id.dart';
import '../sync/sync_trigger.dart';
import '../sync/sync_providers.dart';
import '../../features/profile/presentation/providers/body_metric_notifier.dart';
import '../../features/profile/presentation/providers/body_metrics_dashboard_provider.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/training/presentation/providers/exercise_notifier.dart';
import '../../features/training/presentation/providers/program_notifier.dart';
import '../../features/training/presentation/providers/workout_execution_notifier.dart';
import '../../features/training/presentation/providers/workout_notifier.dart';
import 'workout_sync_guard.dart';

part 'user_data_sync_coordinator.g.dart';

/// Coordinates full-user sync and post-workout session sync.
///
/// Full sync runs on login, manual retry, and Hub scheduled (24h) — never on
/// app resume or connectivity changes. Blocked while a workout is active.
class UserDataSyncCoordinator {
  UserDataSyncCoordinator(this._ref);

  final Ref _ref;
  bool _scheduledSyncAttemptedThisSession = false;

  Future<void> synchronizeAuthenticatedUserData({
    required SyncTrigger trigger,
  }) async {
    if (!isSupabaseConfigured) return;
    final userId = _ref.read(authProvider).value?.id;
    if (!isValidSyncUserId(userId)) return;

    await _claimOrphanedDataIfNeeded(userId!);

    if (!_ref.read(isNetworkAvailableForSyncProvider)) {
      if (trigger == SyncTrigger.sessionChange ||
          trigger == SyncTrigger.manual) {
        final hasNetwork = await waitForNetworkAvailableForSync(_ref);
        if (!hasNetwork) return;
      } else {
        return;
      }
    }

    if (trigger != SyncTrigger.sessionChange &&
        _ref.read(isWorkoutSessionBlockingCloudSyncProvider)) {
      return;
    }

    final prefs = _ref.read(cloudSyncPrefsProvider);
    await prefs.recordAttempt();

    try {
      await _ref
          .read(userOwnedSyncRunnerProvider)
          .synchronizeAuthenticatedUserData(trigger: trigger);
      await prefs.recordSuccess();
    } on Exception catch (e) {
      debugPrint('[UserDataSyncCoordinator] full sync failed: $e');
      rethrow;
    }

    _refreshProvidersAfterFullSync();
  }

  /// Once per app session when opening Hub, if last success was 24h+ ago.
  Future<void> maybeRunScheduledSync() async {
    if (_scheduledSyncAttemptedThisSession) return;
    _scheduledSyncAttemptedThisSession = true;

    if (!isSupabaseConfigured) return;
    if (_ref.read(authProvider).value == null) return;
    if (!_ref.read(isNetworkAvailableForSyncProvider)) return;
    if (_ref.read(isWorkoutSessionBlockingCloudSyncProvider)) return;

    final prefs = _ref.read(cloudSyncPrefsProvider);
    if (!prefs.isScheduledSyncDue) return;

    try {
      await synchronizeAuthenticatedUserData(trigger: SyncTrigger.scheduled);
    } on Exception catch (e) {
      debugPrint('[UserDataSyncCoordinator] scheduled sync failed: $e');
    }
  }

  Future<void> reconcileOnSessionChange() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.sessionChange);

  Future<void> synchronizeManual() =>
      synchronizeAuthenticatedUserData(trigger: SyncTrigger.manual);

  /// Push finished or cancelled workout session to the cloud (no full pull).
  Future<void> syncWorkoutSessionToCloud() async {
    if (!isSupabaseConfigured) return;
    if (_ref.read(authProvider).value == null) return;
    if (!_ref.read(isNetworkAvailableForSyncProvider)) return;

    final prefs = _ref.read(cloudSyncPrefsProvider);
    await prefs.recordAttempt();

    try {
      await _ref.read(userOwnedSyncRunnerProvider).syncWorkoutSessionTables();
      await prefs.recordSuccess();
    } on Exception catch (e) {
      debugPrint('[UserDataSyncCoordinator] workout session sync failed: $e');
    }

    _refreshProvidersAfterWorkoutSessionSync();
  }

  void _refreshProvidersAfterFullSync() {
    _ref.invalidate(profileProvider);
    _ref.invalidate(userCloudSyncStatusProvider);
    _ref.invalidate(bodyMetricListProvider);
    _ref.invalidate(bodyMetricsDashboardProvider);
    _ref.invalidate(latestBodyWeightProvider);
    _ref.invalidate(pendingSyncDirtyCountProvider);
    _invalidateTrainingListProviders();
  }

  void _refreshProvidersAfterWorkoutSessionSync() {
    _ref.invalidate(userCloudSyncStatusProvider);
    _ref.invalidate(pendingSyncDirtyCountProvider);
    _ref.invalidate(workoutExecutionListProvider);
    _ref.invalidate(lastFinishedWorkoutIdProvider);
  }

  Future<void> _claimOrphanedDataIfNeeded(String userId) async {
    final isolation = _ref.read(accountDataIsolationServiceProvider);
    if (!await isolation.hasOrphanedUserData()) return;
    await isolation.claimOrphanedData(userId);
    await isolation.markAllDirtyForUser(userId);
  }

  void _invalidateTrainingListProviders() {
    _ref.invalidate(workoutListProvider);
    _ref.invalidate(archivedWorkoutListProvider);
    _ref.invalidate(exerciseListProvider);
    _ref.invalidate(programListProvider);
    _ref.invalidate(activeProgramProvider);
    _ref.invalidate(workoutExecutionListProvider);
    _ref.invalidate(danglingExecutionProvider);
  }
}

@Riverpod(keepAlive: true)
UserDataSyncCoordinator userDataSyncCoordinator(Ref ref) =>
    UserDataSyncCoordinator(ref);

/// Reserved for future online/offline UI hints — does not trigger sync.
@Riverpod(keepAlive: true)
void userDataCloudSyncConnectivityListener(Ref ref) {
  ref.listen(networkConnectivityProvider, (_, _) {});
}
