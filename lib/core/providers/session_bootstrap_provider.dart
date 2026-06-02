import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/training/presentation/providers/recalculate_training_streaks.dart';
import '../sync/sync_providers.dart';
import '../providers/network_connectivity_provider.dart';
import '../services/account_data_isolation_service.dart';
import '../services/user_data_sync_coordinator.dart';

part 'session_bootstrap_provider.g.dart';

/// Whether post-login isolation + sync has finished for the current session.
///
/// While `false`, entry redirects stay on [RoutePaths.splash] to avoid flashing
/// profile setup before remote data is pulled.
@Riverpod(keepAlive: true)
class SessionBootstrap extends _$SessionBootstrap {
  static const _profileFetchTimeout = Duration(seconds: 15);

  @override
  bool build() => true;

  /// Unblocks [GoRouter] entry redirects when startup is stuck on splash.
  void markBootstrapComplete() {
    state = true;
  }

  Future<void> onAuthSessionChanged(
    AuthUser? previousUser,
    AuthUser? nextUser,
  ) async {
    if (previousUser?.id == nextUser?.id) return;

    if (nextUser == null) {
      ref.invalidate(hasProfileProvider);
      ref.invalidate(profileProvider);
      state = true;
      return;
    }

    state = false;
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);

    var hasNetwork = false;
    try {
      final isolation = ref.read(accountDataIsolationServiceProvider);
      if (await isolation.hasOrphanedUserData()) {
        await isolation.claimOrphanedData(nextUser.id);
        await isolation.markAllDirtyForUser(nextUser.id);
      }
      await isolation.purgeStaleProfiles(nextUser.id);

      hasNetwork = await waitForNetworkAvailableForSync(ref);
      if (!hasNetwork) {
        debugPrint(
          '[SessionBootstrap] skipping remote profile fetch: no internet after wait',
        );
      } else {
        await _pullAndCacheRemoteProfile().timeout(_profileFetchTimeout);
      }
    } on Exception catch (e) {
      debugPrint('[SessionBootstrap] fast path failed: $e');
    } finally {
      if (ref.mounted) state = true;
    }

    if (hasNetwork && ref.mounted) {
      unawaited(_runBackgroundSessionSync());
    }
  }

  /// Safety net (anti-destructive): never route to onboarding while a remote
  /// profile exists. Only this fetch blocks splash — full table sync runs later.
  Future<void> _pullAndCacheRemoteProfile() async {
    final remote = ref.read(userProfileRemoteDataSourceProvider);
    final remoteProfile = await remote.fetchCurrentProfile();
    if (remoteProfile == null) return;

    final dao = ref.read(userProfileDaoProvider);
    await dao.upsert(
      UserProfilesCompanion(
        id: Value(remoteProfile.id),
        name: Value(remoteProfile.name),
        height: Value(remoteProfile.height),
        age: Value(remoteProfile.age),
        goal: Value(remoteProfile.goal),
        bodyAesthetic: Value(remoteProfile.bodyAesthetic),
        trainingStyle: Value(remoteProfile.trainingStyle),
        experienceLevel: Value(remoteProfile.experienceLevel),
        gender: Value(remoteProfile.gender),
        trainingFrequency: Value(remoteProfile.trainingFrequency),
        availableWorkoutMinutes: Value(remoteProfile.availableWorkoutMinutes),
        trainsAtGym: Value(remoteProfile.trainsAtGym),
        injuries: Value(remoteProfile.injuries),
        bio: Value(remoteProfile.bio),
        ownedEquipmentNames: Value(remoteProfile.ownedEquipmentNames),
        lastActiveModule: Value(remoteProfile.lastActiveModule),
        currentFrequencyStreak: Value(remoteProfile.currentFrequencyStreak),
        bestFrequencyStreak: Value(remoteProfile.bestFrequencyStreak),
        trainingStreaksSchema: Value(remoteProfile.trainingStreaksSchema),
        isDirty: const Value(false),
      ),
    );
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);
  }

  Future<void> _runBackgroundSessionSync() async {
    try {
      await ref
          .read(userDataSyncCoordinatorProvider)
          .reconcileOnSessionChange()
          .timeout(const Duration(minutes: 2));
    } on Exception catch (e) {
      debugPrint('[SessionBootstrap] background sync failed: $e');
    }

    try {
      await ref
          .read(trainingStreaksMaterializedProvider.future)
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      debugPrint('[SessionBootstrap] streak materialization failed: $e');
    }

    if (!ref.mounted) return;
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);
  }
}

@Riverpod(keepAlive: true)
void sessionBootstrapListener(Ref ref) {
  ref.listen(
    authProvider,
    (previous, next) {
      unawaited(
        ref.read(sessionBootstrapProvider.notifier).onAuthSessionChanged(
          previous?.value,
          next.value,
        ),
      );
    },
    fireImmediately: true,
  );
}
