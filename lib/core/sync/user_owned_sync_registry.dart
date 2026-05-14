import 'user_owned_sync_target.dart';

/// Fixed execution order for authenticated user-owned sync.
class UserOwnedSyncRegistry {
  UserOwnedSyncRegistry(this._targets);

  final List<UserOwnedSyncTarget> _targets;

  List<UserOwnedSyncTarget> get targets => List.unmodifiable(_targets);

  UserOwnedSyncTarget? targetForTable(String tableName) {
    for (final target in _targets) {
      if (target.tableName == tableName) return target;
    }
    return null;
  }
}
