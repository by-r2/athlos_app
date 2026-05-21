import '../../domain/entities/user_profile.dart';

/// Contract for remote user profile sync operations.
abstract interface class UserProfileRemoteSyncGateway {
  String? get currentUserId;

  Future<UserProfile?> fetchCurrentProfile();

  Future<UserProfile?> fetchUpdatedSince(DateTime lastPullAt);

  Future<DateTime> upsertCurrentProfile(UserProfile profile);
}
