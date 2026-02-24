import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../../domain/enums/selected_module.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/daos/user_profile_dao.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileDao _dao;

  UserProfileRepositoryImpl(this._dao);

  @override
  Future<Result<domain.UserProfile?>> get() async {
    try {
      final row = await _dao.get();
      return Success(row != null ? _toDomain(row) : null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load profile: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.UserProfile profile) async {
    try {
      final id = await _dao.create(
        UserProfilesCompanion.insert(
          weight: Value(profile.weight),
          height: Value(profile.height),
          age: Value(profile.age),
          goal: Value(profile.goal),
          bodyAesthetic: Value(profile.bodyAesthetic),
          trainingStyle: Value(profile.trainingStyle),
          lastActiveModule: Value(profile.lastActiveModule),
        ),
      );
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create profile: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.UserProfile profile) async {
    try {
      await _dao.updateById(
        profile.id,
        UserProfilesCompanion(
          weight: Value(profile.weight),
          height: Value(profile.height),
          age: Value(profile.age),
          goal: Value(profile.goal),
          bodyAesthetic: Value(profile.bodyAesthetic),
          trainingStyle: Value(profile.trainingStyle),
          lastActiveModule: Value(profile.lastActiveModule),
        ),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update profile: $e'));
    }
  }

  @override
  Future<Result<void>> updateLastActiveModule(AppModule module) async {
    try {
      final profile = await _dao.get();
      if (profile == null) {
        return const Failure(
            NotFoundException('No profile found to update module'));
      }
      await _dao.updateById(
        profile.id,
        UserProfilesCompanion(lastActiveModule: Value(module)),
      );
      return const Success(null);
    } on Exception catch (e) {
      return Failure(
          DatabaseException('Failed to update active module: $e'));
    }
  }

  @override
  Future<Result<bool>> hasProfile() async {
    try {
      final exists = await _dao.hasProfile();
      return Success(exists);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to check profile: $e'));
    }
  }

  domain.UserProfile _toDomain(UserProfile row) => domain.UserProfile(
        id: row.id,
        weight: row.weight,
        height: row.height,
        age: row.age,
        goal: row.goal,
        bodyAesthetic: row.bodyAesthetic,
        trainingStyle: row.trainingStyle,
        lastActiveModule: row.lastActiveModule,
      );
}
