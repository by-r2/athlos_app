import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/user_profiles_table.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<UserProfile?> get() => select(userProfiles).getSingleOrNull();

  Future<int> create(UserProfilesCompanion entry) =>
      into(userProfiles).insert(entry);

  Future<void> updateById(int id, UserProfilesCompanion entry) =>
      (update(userProfiles)..where((p) => p.id.equals(id))).write(entry);

  Future<void> markSynced({
    required int id,
    required String remoteUserId,
    required DateTime syncedAt,
  }) => (update(userProfiles)..where((p) => p.id.equals(id))).write(
    UserProfilesCompanion(
      remoteUserId: Value(remoteUserId),
      lastSyncedAt: Value(syncedAt),
    ),
  );

  Future<bool> hasProfile() async {
    final count =
        await (selectOnly(userProfiles)..addColumns([userProfiles.id.count()]))
            .map((row) => row.read(userProfiles.id.count()))
            .getSingle();
    return (count ?? 0) > 0;
  }
}
