import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/daos/user_profile_dao.dart';
import '../datasources/user_profile_remote_sync_gateway.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final UserProfileDao _dao;
  final UserProfileRemoteSyncGateway? _remoteGateway;

  UserProfileRepositoryImpl(
    this._dao, {
    UserProfileRemoteSyncGateway? remoteDataSource,
  }) : _remoteGateway = remoteDataSource;

  @override
  Future<Result<domain.UserProfile?>> get() async {
    try {
      final row = await _dao.get();
      if (row != null) return Success(_toDomain(row));

      return _pullRemoteProfileIfNeeded();
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to load profile: $e'));
    }
  }

  @override
  Future<Result<int>> create(domain.UserProfile profile) async {
    try {
      final id = await _dao.create(_toInsertCompanion(profile));
      await _pushLocalProfile(
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
      await _dao.updateById(profile.id, _toUpdateCompanion(profile));
      await _pushLocalProfile(profile, allowUnlinked: false);
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
      final remoteGateway = _remoteGateway;
      final remoteUserId = remoteGateway?.currentUserId;
      if (remoteGateway == null || remoteUserId == null) {
        return get();
      }

      final localRow = await _dao.get();
      final remoteProfile = await remoteGateway.fetchCurrentProfile();

      if (localRow == null && remoteProfile == null) {
        return const Success(null);
      }

      if (localRow == null && remoteProfile != null) {
        return _pullRemoteProfileIfNeeded();
      }

      final local = _toDomain(localRow!);
      _assertProfileBelongsToSession(local, remoteUserId);

      if (remoteProfile == null) {
        await _pushLocalProfile(local, allowUnlinked: local.remoteUserId == null);
        return get();
      }

      if (_remoteIsNewer(local, remoteProfile)) {
        await _updateLocalFromRemote(local.id, remoteProfile, remoteUserId);
      } else {
        await _pushLocalProfile(
          local,
          allowUnlinked: local.remoteUserId == null,
        );
      }

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
      final remoteGateway = _remoteGateway;
      final remoteUserId = remoteGateway?.currentUserId;
      if (remoteGateway == null || remoteUserId == null) {
        return const Success(null);
      }

      final localRow = await _dao.get();
      if (localRow == null) return const Success(null);

      final local = _toDomain(localRow);
      _assertProfileBelongsToSession(local, remoteUserId);
      await _pushLocalProfile(
        local,
        allowUnlinked: local.remoteUserId == null,
      );
      return const Success(null);
    } on ValidationException catch (e) {
      return Failure(e);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to push profile: $e'));
    }
  }

  Future<Result<domain.UserProfile?>> _pullRemoteProfileIfNeeded() async {
    final remoteGateway = _remoteGateway;
    final remoteUserId = remoteGateway?.currentUserId;
    if (remoteGateway == null || remoteUserId == null) {
      return const Success(null);
    }

    final remoteProfile = await remoteGateway.fetchCurrentProfile();
    if (remoteProfile == null) return const Success(null);

    final id = await _dao.create(_toInsertCompanion(remoteProfile));
    final syncedAt = remoteProfile.lastSyncedAt ?? DateTime.now().toUtc();
    await _dao.markSynced(
      id: id,
      remoteUserId: remoteUserId,
      syncedAt: syncedAt,
    );

    return Success(
      remoteProfile.copyWith(
        id: id,
        remoteUserId: () => remoteUserId,
        lastSyncedAt: () => syncedAt,
      ),
    );
  }

  Future<void> _pushLocalProfile(
    domain.UserProfile profile, {
    required bool allowUnlinked,
  }) async {
    final remoteGateway = _remoteGateway;
    final remoteUserId = remoteGateway?.currentUserId;
    if (remoteGateway == null || remoteUserId == null) return;

    if (!allowUnlinked && profile.remoteUserId != remoteUserId) return;

    try {
      final syncedAt = await remoteGateway.upsertCurrentProfile(profile);
      await _dao.markSynced(
        id: profile.id,
        remoteUserId: remoteUserId,
        syncedAt: syncedAt,
      );
    } on Exception {
      // Local-first: profile edits must not be blocked by transient network issues.
    }
  }

  Future<void> _updateLocalFromRemote(
    int localId,
    domain.UserProfile remoteProfile,
    String remoteUserId,
  ) async {
    final syncedAt = remoteProfile.lastSyncedAt ?? DateTime.now().toUtc();
    await _dao.updateById(
      localId,
      _toUpdateCompanion(
        remoteProfile.copyWith(
          id: localId,
          remoteUserId: () => remoteUserId,
          lastSyncedAt: () => syncedAt,
        ),
      ),
    );
    await _dao.markSynced(
      id: localId,
      remoteUserId: remoteUserId,
      syncedAt: syncedAt,
    );
  }

  void _assertProfileBelongsToSession(
    domain.UserProfile profile,
    String remoteUserId,
  ) {
    if (profile.remoteUserId != null && profile.remoteUserId != remoteUserId) {
      throw const ValidationException(
        'Profile is linked to a different account.',
      );
    }
  }

  bool _remoteIsNewer(domain.UserProfile local, domain.UserProfile remote) {
    final remoteAt = remote.lastSyncedAt;
    if (remoteAt == null) return false;

    final localAt = local.lastSyncedAt;
    if (localAt == null) return true;

    return remoteAt.isAfter(localAt);
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
  );
}
