import '../../../../core/errors/result.dart';
import '../entities/user_profile.dart';

/// Contract for user profile data operations.
abstract interface class UserProfileRepository {
  Future<Result<UserProfile?>> get();
  Future<Result<int>> create(UserProfile profile);
  Future<Result<void>> update(UserProfile profile);
  Future<Result<bool>> hasProfile();
}
