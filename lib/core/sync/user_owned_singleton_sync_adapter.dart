/// Feature adapter for singleton user-owned rows (profile).
abstract interface class UserOwnedSingletonSyncAdapter<T> {
  String get tableName;

  String? get currentRemoteUserId;

  Future<UserOwnedSingletonLocalRow<T>?> loadLocalRow();

  Future<UserOwnedSingletonRemoteRow<T>?> fetchRemoteRow();

  Future<int> insertFromRemote(
    UserOwnedSingletonRemoteRow<T> remote,
    String remoteUserId,
  );

  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSingletonRemoteRow<T> remote,
    String remoteUserId,
  );

  Future<DateTime> pushUpsert({
    required int localId,
    required T entity,
  });

  Future<void> markLocalSynced({
    required int localId,
    required String remoteUserId,
    required DateTime syncedAt,
  });

  Future<void> markLocalDirty(int localId);
}

/// Local row snapshot for singleton sync.
class UserOwnedSingletonLocalRow<T> {
  const UserOwnedSingletonLocalRow({
    required this.localId,
    required this.entity,
    this.remoteUserId,
    this.localUpdatedAt,
    this.lastSyncedAt,
  });

  final int localId;
  final T entity;
  final String? remoteUserId;
  final DateTime? localUpdatedAt;
  final DateTime? lastSyncedAt;
}

/// Remote row snapshot for singleton sync.
class UserOwnedSingletonRemoteRow<T> {
  const UserOwnedSingletonRemoteRow({
    required this.entity,
    required this.remoteUpdatedAt,
  });

  final T entity;
  final DateTime remoteUpdatedAt;
}
