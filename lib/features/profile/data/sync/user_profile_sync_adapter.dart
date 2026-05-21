import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_adapter.dart';
import '../../domain/entities/user_profile.dart' as domain;
import '../datasources/daos/user_profile_dao.dart';
import '../datasources/user_profile_remote_sync_gateway.dart';

class UserProfileSyncAdapter implements SyncAdapter<domain.UserProfile> {
  UserProfileSyncAdapter({
    required UserProfileDao dao,
    required UserProfileRemoteSyncGateway remote,
  })  : _dao = dao,
        _remote = remote;

  final UserProfileDao _dao;
  final UserProfileRemoteSyncGateway _remote;

  @override
  String get tableName => 'user_profiles';

  @override
  String getId(domain.UserProfile row) => row.id;

  @override
  Future<List<domain.UserProfile>> loadDirty() async {
    final row = await _dao.getDirty();
    if (row == null) return const [];
    return [_toDomain(row)];
  }

  @override
  Future<List<domain.UserProfile>> loadDirtyTombstones() async => const [];

  @override
  Future<void> pushToRemote(List<domain.UserProfile> rows) async {
    for (final profile in rows) {
      await _remote.upsertCurrentProfile(profile);
    }
  }

  @override
  Future<void> pushDeletes(List<domain.UserProfile> rows) async {}

  @override
  Future<List<domain.UserProfile>> pullFromRemote(DateTime lastPullAt) async {
    final profile = await _remote.fetchUpdatedSince(lastPullAt);
    if (profile == null) return const [];
    return [profile];
  }

  @override
  Future<void> applyRemoteRows(List<domain.UserProfile> rows) async {
    for (final profile in rows) {
      final local = await _dao.getById(profile.id);
      if (local != null && local.isDirty) continue;
      await _dao.upsert(
        _toCompanion(profile).copyWith(isDirty: const Value(false)),
      );
    }
  }

  @override
  Future<void> markClean(List<String> ids) async {
    for (final id in ids) {
      await _dao.markClean(id);
    }
  }

  @override
  Future<void> hardDelete(List<String> ids) async {}

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
  );

  UserProfilesCompanion _toCompanion(domain.UserProfile profile) =>
      UserProfilesCompanion(
        id: Value(profile.id),
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
          profile.trainingStreaksSchema == 0
              ? 1
              : profile.trainingStreaksSchema,
        ),
      );
}
