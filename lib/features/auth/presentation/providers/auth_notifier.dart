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
    final subscription = repository.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(subscription.cancel);

    final result = await repository.currentUser();
    return result.getOrThrow();
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signUpWithEmail(email: email, password: password);
    state = AsyncData(result.getOrThrow());
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: email, password: password);
    state = AsyncData(result.getOrThrow());
  }

  Future<void> signInWithSocialProvider(SocialAuthProvider provider) async {
    state = const AsyncLoading();
    final currentUser = state.value;
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithSocialProvider(provider);
    result.getOrThrow();
    state = AsyncData(currentUser);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signOut();
    result.getOrThrow();
    state = const AsyncData(null);
  }
}
