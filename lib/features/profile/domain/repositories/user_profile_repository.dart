import '../../../../core/errors/result.dart';
import '../entities/user_profile.dart';

/// Contract for user profile data operations.
abstract interface class UserProfileRepository {
  Future<Result<UserProfile?>> get();
  Future<Result<String>> create(UserProfile profile);
  Future<Result<void>> update(UserProfile profile);
  Future<Result<bool>> hasProfile();

  /// Reconciles the local profile cache with the authenticated remote account.
  Future<Result<UserProfile?>> reconcileOnAuth();

  /// Pushes the local profile to the remote account when a session is active.
  Future<Result<void>> pushPendingLocalChanges();

  /// Read-only snapshot from Supabase for the current session (no DB write).
  Future<Result<UserProfile?>> fetchRemoteSnapshot();

  /// Overwrites local cached profile with remote data without marking dirty.
  Future<Result<void>> restoreFromRemote(UserProfile profile);
}
