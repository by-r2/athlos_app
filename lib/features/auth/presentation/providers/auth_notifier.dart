import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/data/repositories/auth_providers.dart';
import '../../domain/entities/auth_error_code.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/enums/social_auth_provider.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthUser?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    final result = await repository.currentUser();
    final subscription = repository.authStateChanges().listen(
      (user) => state = AsyncData(user),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[Auth] authStateChanges error: $error');
      },
    );
    ref.onDispose(subscription.cancel);

    return result.getOrThrow();
  }

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final previousUser = state.value;
    state = const AsyncLoading();
    try {
      if (previousUser != null) {
        final signOutResult = await ref.read(authRepositoryProvider).signOut();
        signOutResult.getOrThrow();
      }
      final result = await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password);
      final user = result.getOrThrow();
      await _ensureCurrentSession(
        user,
        failureCode: AuthErrorCode.emailNotConfirmed,
      );
      state = AsyncData(user);
      return user;
    } on Object {
      state = const AsyncData(null);
      rethrow;
    }
  }

  /// Resends signup confirmation email ([AuthRepository.resendSignupConfirmation]).
  Future<void> resendSignupConfirmationEmail({required String email}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .resendSignupConfirmation(email: email);
    result.getOrThrow();
  }

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final previousUser = state.value;
    state = const AsyncLoading();
    try {
      if (previousUser != null) {
        final signOutResult = await ref.read(authRepositoryProvider).signOut();
        signOutResult.getOrThrow();
      }
      final result = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);
      final user = result.getOrThrow();
      await _ensureCurrentSession(
        user,
        failureCode: AuthErrorCode.invalidCredentials,
      );
      state = AsyncData(user);
      return user;
    } on Object {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> signInWithSocialProvider(SocialAuthProvider provider) async {
    final currentUser = state.value;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signInWithSocialProvider(provider);
      result.getOrThrow();
      state = AsyncData(currentUser);
    } on Object {
      state = AsyncData(currentUser);
      rethrow;
    }
  }

  Future<void> signOut() async {
    final previousUser = state.value;
    state = const AsyncLoading();
    try {
      final result = await ref.read(authRepositoryProvider).signOut();
      result.getOrThrow();
      state = const AsyncData(null);
    } on Object {
      state = AsyncData(previousUser);
      rethrow;
    }
  }

  Future<void> _ensureCurrentSession(
    AuthUser expectedUser, {
    required String failureCode,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final currentUser = (await repository.currentUser()).getOrThrow();
    if (currentUser?.id == expectedUser.id) return;

    await repository.signOut();
    throw AuthAppException(failureCode);
  }
}
