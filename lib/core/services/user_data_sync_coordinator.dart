import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../errors/result.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/data/repositories/profile_providers.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';

part 'user_data_sync_coordinator.g.dart';

class UserDataSyncCoordinator {
  const UserDataSyncCoordinator(this._ref);

  final Ref _ref;

  Future<void> reconcileProfileOnSessionChange() async {
    final repository = _ref.read(userProfileRepositoryProvider);
    final result = await repository.reconcileOnAuth();
    result.getOrThrow();
    _ref.invalidate(profileProvider);
    _ref.invalidate(hasProfileProvider);
  }

  Future<void> retryPendingProfileSync() async {
    final repository = _ref.read(userProfileRepositoryProvider);
    final result = await repository.pushPendingLocalChanges();
    result.getOrThrow();
    _ref.invalidate(profileProvider);
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
      ref
          .read(userDataSyncCoordinatorProvider)
          .reconcileProfileOnSessionChange(),
    );
  });
}
