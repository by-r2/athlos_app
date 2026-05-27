import 'dart:async';

import 'package:athlos_app/core/data/repositories/local_backup_providers.dart';
import 'package:athlos_app/core/database/app_database.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:athlos_app/core/sync/sync_providers.dart';
import 'package:athlos_app/features/auth/data/repositories/auth_providers.dart';
import 'package:athlos_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:athlos_app/features/auth/domain/entities/auth_user.dart';
import 'package:athlos_app/features/auth/domain/enums/social_auth_provider.dart';
import 'package:athlos_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:athlos_app/features/profile/data/repositories/profile_providers.dart';
import 'package:athlos_app/features/training/data/repositories/training_providers.dart';
import 'package:athlos_app/features/training/data/training_dao_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Providers wiring', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          authRepositoryProvider.overrideWithValue(
            _StubAuthRepository(userId: 'test-user-id'),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('training/profile/core providers resolvem dependencias', () async {
      await container.read(authProvider.future);

      expect(container.read(exerciseDaoProvider), isNotNull);
      expect(container.read(workoutDaoProvider), isNotNull);
      expect(container.read(workoutExecutionDaoProvider), isNotNull);
      expect(container.read(cycleStepDaoProvider), isNotNull);

      expect(container.read(exerciseRepositoryProvider), isNotNull);
      expect(container.read(workoutRepositoryProvider), isNotNull);
      expect(container.read(workoutExecutionRepositoryProvider), isNotNull);
      expect(container.read(cycleRepositoryProvider), isNotNull);
      expect(container.read(completeSetUseCaseProvider), isNotNull);

      expect(container.read(userProfileDaoProvider), isNotNull);
      expect(container.read(userProfileRepositoryProvider), isNotNull);
      expect(container.read(bodyMetricRepositoryProvider), isNotNull);
      expect(container.read(userOwnedSyncRunnerProvider), isNotNull);
      expect(container.read(trainingSyncStoreProvider), isNotNull);

      expect(container.read(localBackupRepositoryProvider), isNotNull);
      expect(container.read(scanRuntimeLocalDuplicatesUseCaseProvider), isNotNull);
    });
  });
}

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository({required this.userId});

  final String userId;

  AuthUser get _user => AuthUser(id: userId);

  @override
  Future<Result<AuthUser?>> currentUser() async => Success(_user);

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<Result<void>> resendSignupConfirmation({required String email}) async =>
      const Success(null);

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      Success(_user);

  @override
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      Success(_user);

  @override
  Future<Result<void>> signInWithSocialProvider(
    SocialAuthProvider provider,
  ) async =>
      const Success(null);

  @override
  Future<Result<void>> sendPasswordResetEmail({required String email}) async =>
      const Success(null);

  @override
  Future<Result<void>> updatePassword({required String newPassword}) async =>
      const Success(null);

  @override
  Future<Result<void>> signOut() async => const Success(null);
}
