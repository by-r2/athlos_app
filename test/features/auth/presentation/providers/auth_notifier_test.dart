import 'dart:async';

import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/features/auth/data/repositories/auth_providers.dart';
import 'package:athlos_app/features/auth/domain/entities/auth_error_code.dart';
import 'package:athlos_app/features/auth/domain/entities/auth_user.dart';
import 'package:athlos_app/features/auth/domain/enums/social_auth_provider.dart';
import 'package:athlos_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:athlos_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthNotifier', () {
    test('signInWithEmail atualiza estado com usuario autenticado', () async {
      final user = AuthUser(id: 'user-1', email: 'rafa@example.com');
      final repository = _FakeAuthRepository(signInResult: Success(user));
      final container = _container(repository);
      addTearDown(() {
        container.dispose();
        repository.dispose();
      });

      await container.read(authProvider.future);
      final result = await container
          .read(authProvider.notifier)
          .signInWithEmail(email: 'rafa@example.com', password: 'password123');

      expect(result, same(user));
      expect(container.read(authProvider).value, same(user));
    });

    test('signInWithEmail falho limpa estado e propaga erro', () async {
      final repository = _FakeAuthRepository(
        signInResult: const Failure(
          AuthAppException(AuthErrorCode.invalidCredentials),
        ),
      );
      final container = _container(repository);
      addTearDown(() {
        container.dispose();
        repository.dispose();
      });

      await container.read(authProvider.future);

      await expectLater(
        () => container
            .read(authProvider.notifier)
            .signInWithEmail(
              email: 'missing@example.com',
              password: 'password123',
            ),
        throwsA(isA<AuthAppException>()),
      );
      expect(container.read(authProvider).value, isNull);
    });

    test('signUpWithEmail atualiza estado com usuario criado', () async {
      final user = AuthUser(id: 'user-2', email: 'novo@example.com');
      final repository = _FakeAuthRepository(signUpResult: Success(user));
      final container = _container(repository);
      addTearDown(() {
        container.dispose();
        repository.dispose();
      });

      await container.read(authProvider.future);
      final result = await container
          .read(authProvider.notifier)
          .signUpWithEmail(email: 'novo@example.com', password: 'password123');

      expect(result, same(user));
      expect(container.read(authProvider).value, same(user));
    });

    test(
      'signUpWithEmail falha quando sucesso nao cria sessao atual',
      () async {
        final user = AuthUser(id: 'user-2', email: 'novo@example.com');
        final repository = _FakeAuthRepository(
          signUpResult: Success(user),
          persistSuccessfulAuth: false,
        );
        final container = _container(repository);
        addTearDown(() {
          container.dispose();
          repository.dispose();
        });

        await container.read(authProvider.future);

        await expectLater(
          () => container
              .read(authProvider.notifier)
              .signUpWithEmail(
                email: 'novo@example.com',
                password: 'password123',
              ),
          throwsA(isA<AuthAppException>()),
        );
        expect(container.read(authProvider).value, isNull);
      },
    );

    test('signOut limpa usuario atual', () async {
      final user = AuthUser(id: 'user-1', email: 'rafa@example.com');
      final repository = _FakeAuthRepository(initialUser: user);
      final container = _container(repository);
      addTearDown(() {
        container.dispose();
        repository.dispose();
      });

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).value, isNull);
    });
  });
}

ProviderContainer _container(AuthRepository repository) => ProviderContainer(
  overrides: [authRepositoryProvider.overrideWithValue(repository)],
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.initialUser,
    this.signInResult,
    this.signUpResult,
    this.persistSuccessfulAuth = true,
  });

  final AuthUser? initialUser;
  final Result<AuthUser>? signInResult;
  final Result<AuthUser>? signUpResult;
  final bool persistSuccessfulAuth;
  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  void dispose() => _controller.close();

  @override
  Future<Result<AuthUser?>> currentUser() async {
    _currentUser ??= initialUser;
    return Success(_currentUser);
  }

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result =
        signInResult ??
        Success(AuthUser(id: 'user-1', email: email.trim().toLowerCase()));
    if (result case Success(:final value) when persistSuccessfulAuth) {
      _currentUser = value;
      _controller.add(value);
    }
    return result;
  }

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final result =
        signUpResult ??
        Success(AuthUser(id: 'user-1', email: email.trim().toLowerCase()));
    if (result case Success(:final value) when persistSuccessfulAuth) {
      _currentUser = value;
      _controller.add(value);
    }
    return result;
  }

  @override
  Future<Result<void>> signInWithSocialProvider(
    SocialAuthProvider provider,
  ) async => const Success(null);

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async =>
      const Success(null);

  @override
  Future<Result<void>> updatePassword({required String newPassword}) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async {
    _currentUser = null;
    _controller.add(null);
    return const Success(null);
  }
}
