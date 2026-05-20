/// Ordered sync targets executed by [UserOwnedSyncRunner].
abstract interface class UserOwnedSyncTarget {
  String get tableName;

  Future<void> synchronize();
}
