import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/auth_error_code.dart';
import '../../../../core/services/supabase_config.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/enums/social_auth_provider.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepositoryImpl implements AuthRepository {
  supabase.SupabaseClient? get _client =>
      isSupabaseConfigured ? supabase.Supabase.instance.client : null;

  @override
  Future<Result<AuthUser?>> currentUser() async {
    final client = _client;
    if (client == null) return const Success(null);

    try {
      return Success(_toDomain(client.auth.currentSession?.user));
    } on Exception {
      return const Failure(AuthAppException(AuthErrorCode.generic));
    }
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    final client = _client;
    if (client == null) return Stream<AuthUser?>.value(null);

    return client.auth.onAuthStateChange
        .where(
          (event) => event.event != supabase.AuthChangeEvent.initialSession,
        )
        .map((event) => _toDomain(event.session?.user));
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure(AuthAppException(AuthErrorCode.generic));
    }

    try {
      final requestedEmail = _normalizeEmail(email);
      await _clearExistingSession(client);
      final response = await client.auth.signUp(
        email: requestedEmail,
        password: password,
      );
      final user = _toDomain(response.session?.user);
      if (user == null || _normalizeEmail(user.email) != requestedEmail) {
        await _clearExistingSession(client);
        return const Failure(AuthAppException(AuthErrorCode.emailNotConfirmed));
      }
      return Success(user);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(_mapAuthException(e)));
    } on Exception catch (e) {
      return Failure(NetworkException('Failed to sign up: $e'));
    }
  }

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure(AuthAppException(AuthErrorCode.generic));
    }

    try {
      final requestedEmail = _normalizeEmail(email);
      await _clearExistingSession(client);
      final response = await client.auth.signInWithPassword(
        email: requestedEmail,
        password: password,
      );
      final user = _toDomain(response.session?.user);
      if (user == null || _normalizeEmail(user.email) != requestedEmail) {
        await _clearExistingSession(client);
        return const Failure(
          AuthAppException(AuthErrorCode.invalidCredentials),
        );
      }
      return Success(user);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(_mapAuthException(e)));
    } on Exception catch (e) {
      return Failure(NetworkException('Failed to sign in: $e'));
    }
  }

  @override
  Future<Result<void>> signInWithSocialProvider(
    SocialAuthProvider provider,
  ) async {
    final client = _client;
    if (client == null) {
      return const Failure(AuthAppException(AuthErrorCode.generic));
    }

    try {
      final started = await client.auth.signInWithOAuth(
        _toSupabaseProvider(provider),
        redirectTo: supabaseRedirectUrl,
      );
      if (!started) {
        return const Failure(AuthAppException(AuthErrorCode.generic));
      }
      return const Success(null);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(_mapAuthException(e)));
    } on Exception catch (e) {
      return Failure(NetworkException('Failed to start social sign-in: $e'));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    final client = _client;
    if (client == null) return const Success(null);

    try {
      await client.auth.signOut();
      return const Success(null);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(_mapAuthException(e)));
    } on Exception catch (e) {
      return Failure(NetworkException('Failed to sign out: $e'));
    }
  }

  AuthUser? _toDomain(supabase.User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName = metadata['name'] ?? metadata['full_name'];
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: displayName is String ? displayName : null,
    );
  }

  String _normalizeEmail(String? email) => (email ?? '').trim().toLowerCase();

  String _mapAuthException(supabase.AuthException exception) {
    final message = exception.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return AuthErrorCode.invalidCredentials;
    }
    if (message.contains('email not confirmed') ||
        message.contains('confirm your email')) {
      return AuthErrorCode.emailNotConfirmed;
    }
    if (message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already')) {
      return AuthErrorCode.accountAlreadyExists;
    }
    return AuthErrorCode.generic;
  }

  Future<void> _clearExistingSession(supabase.SupabaseClient client) async {
    if (client.auth.currentSession == null) return;
    await client.auth.signOut();
  }

  supabase.OAuthProvider _toSupabaseProvider(SocialAuthProvider provider) =>
      switch (provider) {
        SocialAuthProvider.google => supabase.OAuthProvider.google,
      };
}
