import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/sync/user_owned_singleton_sync_engine.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/daos/user_profile_dao.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl(
    this._dao,
    this._syncEngine,
  );

  final UserProfileDao _dao;
  final UserOwnedSingletonSyncEngine _syncEngine;

  @override
  Future<Result<domain.UserProfile?>> get() async {
    try {
      final row = await _dao.get();
      if (row == null) return const Success(null);
      return Success(_toDomain(row));
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load profile: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.UserProfile profile) async {
    try {
      final now = DateTime.now().toUtc();
      final id = await _dao.create(
        _toInsertCompanion(
          profile.copyWith(localUpdatedAt: () => now),
        ),
      );
      await _syncEngine.synchronizeAfterMutation(id);
      return Success(id);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to create profile: $e'));
    }
  }

  @override
  Future<Result<void>> update(domain.UserProfile profile) async {
    try {
      final now = DateTime.now().toUtc();
      await _dao.updateById(
        profile.id,
        _toUpdateCompanion(profile.copyWith(localUpdatedAt: () => now)),
      );
      await _syncEngine.synchronizeAfterMutation(profile.id);
      return const Success(null);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to update profile: $e'));
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

  @override
  Future<Result<domain.UserProfile?>> reconcileOnAuth() async {
    try {
      await _syncEngine.synchronize();
      return get();
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to reconcile profile: $e'));
    }
  }

  @override
  Future<Result<void>> pushPendingLocalChanges() async {
    try {
      await _syncEngine.synchronize();
      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to push profile: $e'));
    }
  }

  UserProfilesCompanion _toInsertCompanion(domain.UserProfile profile) =>
      UserProfilesCompanion.insert(
        name: Value(profile.name),
        height: Value(profile.height),
        age: Value(profile.age),
        goal: Value(profile.goal),
        bodyAesthetic: Value(profile.bodyAesthetic),
        trainingStyle: Value(profile.trainingStyle),
        experienceLevel: Value(profile.experienceLevel),
        gender: Value(profile.gender),
        trainingFrequency: Value(profile.trainingFrequency),
        availableWorkoutMinutes: Value(profile.availableWorkoutMinutes),
        trainsAtGym: Value(profile.trainsAtGym),
        injuries: Value(profile.injuries),
        bio: Value(profile.bio),
        ownedEquipmentNames: Value(profile.ownedEquipmentNames),
        lastActiveModule: Value(profile.lastActiveModule),
        currentCycleStreak: Value(profile.currentCycleStreak),
        bestCycleStreak: Value(profile.bestCycleStreak),
        currentFrequencyStreak: Value(profile.currentFrequencyStreak),
        bestFrequencyStreak: Value(profile.bestFrequencyStreak),
        trainingStreaksSchema: Value(
          profile.trainingStreaksSchema == 0 ? 1 : profile.trainingStreaksSchema,
        ),
        remoteUserId: Value(profile.remoteUserId),
        lastSyncedAt: Value(profile.lastSyncedAt),
        localUpdatedAt: Value(profile.localUpdatedAt),
      );

  UserProfilesCompanion _toUpdateCompanion(domain.UserProfile profile) =>
      UserProfilesCompanion(
        name: Value(profile.name),
        height: Value(profile.height),
        age: Value(profile.age),
        goal: Value(profile.goal),
        bodyAesthetic: Value(profile.bodyAesthetic),
        trainingStyle: Value(profile.trainingStyle),
        experienceLevel: Value(profile.experienceLevel),
        gender: Value(profile.gender),
        trainingFrequency: Value(profile.trainingFrequency),
        availableWorkoutMinutes: Value(profile.availableWorkoutMinutes),
        trainsAtGym: Value(profile.trainsAtGym),
        injuries: Value(profile.injuries),
        bio: Value(profile.bio),
        ownedEquipmentNames: Value(profile.ownedEquipmentNames),
        lastActiveModule: Value(profile.lastActiveModule),
        currentCycleStreak: Value(profile.currentCycleStreak),
        bestCycleStreak: Value(profile.bestCycleStreak),
        currentFrequencyStreak: Value(profile.currentFrequencyStreak),
        bestFrequencyStreak: Value(profile.bestFrequencyStreak),
        trainingStreaksSchema: Value(profile.trainingStreaksSchema),
        remoteUserId: Value(profile.remoteUserId),
        lastSyncedAt: Value(profile.lastSyncedAt),
        localUpdatedAt: Value(profile.localUpdatedAt),
      );

  domain.UserProfile _toDomain(UserProfile row) => domain.UserProfile(
    id: row.id,
    name: row.name,
    height: row.height,
    age: row.age,
    goal: row.goal,
    bodyAesthetic: row.bodyAesthetic,
    trainingStyle: row.trainingStyle,
    experienceLevel: row.experienceLevel,
    gender: row.gender,
    trainingFrequency: row.trainingFrequency,
    availableWorkoutMinutes: row.availableWorkoutMinutes,
    trainsAtGym: row.trainsAtGym,
    injuries: row.injuries,
    bio: row.bio,
    ownedEquipmentNames: row.ownedEquipmentNames ?? const [],
    lastActiveModule: row.lastActiveModule,
    currentCycleStreak: row.currentCycleStreak,
    bestCycleStreak: row.bestCycleStreak,
    currentFrequencyStreak: row.currentFrequencyStreak,
    bestFrequencyStreak: row.bestFrequencyStreak,
    trainingStreaksSchema: row.trainingStreaksSchema,
    remoteUserId: row.remoteUserId,
    lastSyncedAt: row.lastSyncedAt,
    localUpdatedAt: row.localUpdatedAt,
  );
}
