import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/data/repositories/auth_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/enums/social_auth_provider.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthUser?> build() async {
    final repository = ref.watch(authRepositoryProvider);
    final result = await repository.currentUser();
    final subscription = repository.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(subscription.cancel);

    return result.getOrThrow();
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final previousUser = state.value;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password);
      state = AsyncData(result.getOrThrow());
    } on Object {
      state = AsyncData(previousUser);
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final previousUser = state.value;
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password);
      state = AsyncData(result.getOrThrow());
    } on Object {
      state = AsyncData(previousUser);
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
}
