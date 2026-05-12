import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/daos/user_profile_dao.dart';
import '../datasources/user_profile_remote_data_source.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileDao _dao;
  final UserProfileRemoteDataSource? _remoteDataSource;

  UserProfileRepositoryImpl(
    this._dao, {
    UserProfileRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<domain.UserProfile?>> get() async {
    try {
      final row = await _dao.get();
      if (row != null) return Success(_toDomain(row));

      final remoteProfile = await _remoteDataSource?.fetchCurrentProfile();
      if (remoteProfile == null) return const Success(null);

      final idResult = await create(remoteProfile);
      final id = idResult.getOrThrow();
      final syncedAt = remoteProfile.lastSyncedAt ?? DateTime.now().toUtc();
      final remoteUserId = remoteProfile.remoteUserId;
      if (remoteUserId != null) {
        await _dao.markSynced(
          id: id,
          remoteUserId: remoteUserId,
          syncedAt: syncedAt,
        );
      }
      return Success(
        remoteProfile.copyWith(id: id, lastSyncedAt: () => syncedAt),
      );
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load profile: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.UserProfile profile) async {
    try {
      final id = await _dao.create(
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
          currentCycleStreak: const Value(0),
          bestCycleStreak: const Value(0),
          currentFrequencyStreak: const Value(0),
          bestFrequencyStreak: const Value(0),
          trainingStreaksSchema: const Value(1),
          remoteUserId: Value(profile.remoteUserId),
          lastSyncedAt: Value(profile.lastSyncedAt),
        ),
      );
      await _syncProfileIfPossible(
        profile.copyWith(id: id),
        allowUnlinked: true,
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
        ),
      );
      await _syncProfileIfPossible(profile, allowUnlinked: false);
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

  Future<void> _syncProfileIfPossible(
    domain.UserProfile profile, {
    required bool allowUnlinked,
  }) async {
    try {
      final remoteDataSource = _remoteDataSource;
      final remoteUserId = remoteDataSource?.currentUserId;
      if (remoteUserId == null) return;
      if (!allowUnlinked && profile.remoteUserId != remoteUserId) return;

      final syncedAt = await remoteDataSource!.upsertCurrentProfile(profile);
      await _dao.markSynced(
        id: profile.id,
        remoteUserId: remoteUserId,
        syncedAt: syncedAt,
      );
    } on Exception {
      // Local-first safety: explicit cloud migration surfaces errors, but local
      // profile edits should not be lost or blocked by a transient network issue.
    }
  }

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
  );
}
