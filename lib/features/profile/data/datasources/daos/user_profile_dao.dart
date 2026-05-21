import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../tables/user_profiles_table.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  Future<UserProfile?> get() =>
      (select(userProfiles)..limit(1)).getSingleOrNull();

  Future<UserProfile?> getById(String id) => (select(userProfiles)
        ..where((p) => p.id.equals(id)))
      .getSingleOrNull();

  Future<UserProfile?> getDirty() => (select(userProfiles)
        ..where((p) => p.isDirty.equals(true))
        ..limit(1))
      .getSingleOrNull();

  Future<void> upsert(UserProfilesCompanion entry) =>
      into(userProfiles).insertOnConflictUpdate(entry);

  Future<void> updateById(String id, UserProfilesCompanion entry) {
    final now = DateTime.now().toUtc();
    return (update(userProfiles)..where((p) => p.id.equals(id))).write(
      entry.copyWith(
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<bool> hasProfile() async {
    final count =
        await (selectOnly(userProfiles)..addColumns([userProfiles.id.count()]))
            .map((row) => row.read(userProfiles.id.count()))
            .getSingle();
    return (count ?? 0) > 0;
  }

  Future<void> markClean(String id) =>
      (update(userProfiles)..where((p) => p.id.equals(id)))
          .write(const UserProfilesCompanion(isDirty: Value(false)));
}
