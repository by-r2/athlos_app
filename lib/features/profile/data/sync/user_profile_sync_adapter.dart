import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/user_owned_singleton_sync_adapter.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../datasources/daos/user_profile_dao.dart';
import '../datasources/user_profile_remote_sync_gateway.dart';

const userProfilesSyncTableName = 'user_profiles';

class UserProfileSyncAdapter implements UserOwnedSingletonSyncAdapter<domain.UserProfile> {
  UserProfileSyncAdapter(this._dao, {UserProfileRemoteSyncGateway? remoteGateway})
    : _remoteGateway = remoteGateway;

  final UserProfileDao _dao;
  final UserProfileRemoteSyncGateway? _remoteGateway;

  @override
  String get tableName => userProfilesSyncTableName;

  @override
  String? get currentRemoteUserId => _remoteGateway?.currentUserId;

  @override
  Future<UserOwnedSingletonLocalRow<domain.UserProfile>?> loadLocalRow() async {
    final row = await _dao.get();
    if (row == null) return null;
    return UserOwnedSingletonLocalRow(
      localId: row.id,
      entity: _toDomain(row),
      remoteUserId: row.remoteUserId,
      localUpdatedAt: row.localUpdatedAt,
      lastSyncedAt: row.lastSyncedAt,
    );
  }

  @override
  Future<UserOwnedSingletonRemoteRow<domain.UserProfile>?> fetchRemoteRow() async {
    final gateway = _remoteGateway;
    if (gateway == null) return null;

    final profile = await gateway.fetchCurrentProfile();
    if (profile == null) return null;

    return UserOwnedSingletonRemoteRow(
      entity: profile,
      remoteUpdatedAt: profile.lastSyncedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSingletonRemoteRow<domain.UserProfile> remote,
    String remoteUserId,
  ) async {
    final id = await _dao.create(_toInsertCompanion(remote.entity));
    final syncedAt = remote.remoteUpdatedAt;
    await _dao.markSynced(
      id: id,
      remoteUserId: remoteUserId,
      syncedAt: syncedAt,
    );
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSingletonRemoteRow<domain.UserProfile> remote,
    String remoteUserId,
  ) async {
    final syncedAt = remote.remoteUpdatedAt;
    await _dao.updateById(
      localId,
      _toUpdateCompanion(
        remote.entity.copyWith(
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

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required domain.UserProfile entity,
  }) async {
    final gateway = _remoteGateway;
    if (gateway == null) {
      throw StateError('Remote gateway is not configured.');
    }

    return gateway.upsertCurrentProfile(entity);
  }

  @override
  Future<void> markLocalSynced({
    required int localId,
    required String remoteUserId,
    required DateTime syncedAt,
  }) =>
      _dao.markSynced(
        id: localId,
        remoteUserId: remoteUserId,
        syncedAt: syncedAt,
      );

  @override
  Future<void> markLocalDirty(int localId) => _dao.markLocalDirty(localId);

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
        localUpdatedAt: Value(profile.localUpdatedAt ?? DateTime.now().toUtc()),
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
}
