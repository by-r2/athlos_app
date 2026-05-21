import '../../../../core/errors/result.dart';
import '../entities/auth_user.dart';
import '../enums/social_auth_provider.dart';

abstract interface class AuthRepository {
  Future<Result<AuthUser?>> currentUser();

  Stream<AuthUser?> authStateChanges();

  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<void>> signInWithSocialProvider(SocialAuthProvider provider);

  Future<Result<void>> sendPasswordResetEmail({required String email});

  Future<Result<void>> updatePassword({required String newPassword});

  Future<Result<void>> signOut();
}
