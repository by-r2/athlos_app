import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
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

      await ref.read(userDataSyncCoordinatorProvider).reconcileOnSessionChange();
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
