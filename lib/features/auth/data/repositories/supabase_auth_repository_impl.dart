import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
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
      return Success(_toDomain(client.auth.currentUser));
    } on Exception catch (e) {
      return Failure(AuthAppException('Failed to restore auth session: $e'));
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
      return const Failure(AuthAppException('Supabase is not configured.'));
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = _toDomain(response.user ?? response.session?.user);
      if (user == null) {
        return const Failure(
          AuthAppException('Sign up did not return an authenticated user.'),
        );
      }
      return Success(user);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(e.message));
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
      return const Failure(AuthAppException('Supabase is not configured.'));
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = _toDomain(response.user ?? response.session?.user);
      if (user == null) {
        return const Failure(
          AuthAppException('Sign in did not return an authenticated user.'),
        );
      }
      return Success(user);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(e.message));
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
      return const Failure(AuthAppException('Supabase is not configured.'));
    }

    try {
      final started = await client.auth.signInWithOAuth(
        _toSupabaseProvider(provider),
        redirectTo: supabaseRedirectUrl,
      );
      if (!started) {
        return const Failure(
          AuthAppException('Could not start the social sign-in flow.'),
        );
      }
      return const Success(null);
    } on supabase.AuthException catch (e) {
      return Failure(AuthAppException(e.message));
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
      return Failure(AuthAppException(e.message));
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

  supabase.OAuthProvider _toSupabaseProvider(SocialAuthProvider provider) =>
      switch (provider) {
        SocialAuthProvider.google => supabase.OAuthProvider.google,
      };
}
