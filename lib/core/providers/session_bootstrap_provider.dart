import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
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
  @override
  bool build() => true;

  Future<void> onAuthSessionChanged(
    AuthUser? previousUser,
    AuthUser? nextUser,
  ) async {
    if (previousUser?.id == nextUser?.id) return;

    if (nextUser == null) {
      state = true;
      return;
    }

    state = false;
    ref.invalidate(hasProfileProvider);
    ref.invalidate(profileProvider);

    try {
      final isolation = ref.read(accountDataIsolationServiceProvider);
      if (await isolation.hasOrphanedUserData()) {
        await isolation.claimOrphanedData(nextUser.id);
        await isolation.markAllDirtyForUser(nextUser.id);
      }
      await isolation.purgeStaleProfiles(nextUser.id);

      final hasNetwork = await waitForNetworkAvailableForSync(ref);
      if (!hasNetwork) {
        debugPrint(
          '[SessionBootstrap] skipping sync: no internet after wait',
        );
      } else {
        await ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange();
      }

      // Safety net (anti-destructive):
      // Even if sync cursors are stale or a table sync fails silently, never route a
      // signed-in user to onboarding while a remote profile exists. Fetch current
      // profile directly and persist locally.
      if (hasNetwork) {
        final remote = ref.read(userProfileRemoteDataSourceProvider);
        final remoteProfile = await remote.fetchCurrentProfile();
        if (remoteProfile != null) {
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
              currentCycleStreak: Value(remoteProfile.currentCycleStreak),
              bestCycleStreak: Value(remoteProfile.bestCycleStreak),
              currentFrequencyStreak: Value(remoteProfile.currentFrequencyStreak),
              bestFrequencyStreak: Value(remoteProfile.bestFrequencyStreak),
              trainingStreaksSchema: Value(remoteProfile.trainingStreaksSchema),
              isDirty: const Value(false),
            ),
          );
          ref.invalidate(hasProfileProvider);
          ref.invalidate(profileProvider);
        }
      }
    } on Exception catch (e) {
      debugPrint('[SessionBootstrap] failed: $e');
    } finally {
      if (ref.mounted) state = true;
    }
  }
}

@Riverpod(keepAlive: true)
void sessionBootstrapListener(Ref ref) {
  ref.listen(authProvider, (previous, next) {
    unawaited(
      ref.read(sessionBootstrapProvider.notifier).onAuthSessionChanged(
        previous?.value,
        next.value,
      ),
    );
  });
}
