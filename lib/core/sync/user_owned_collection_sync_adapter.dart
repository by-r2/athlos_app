/// Local row snapshot used by collection sync engines.
class UserOwnedSyncLocalRow<T> {
  const UserOwnedSyncLocalRow({
    required this.localId,
    required this.entity,
    this.remoteId,
    this.localUpdatedAt,
    this.lastSyncedAt,
  });

  final int localId;
  final T entity;
  final String? remoteId;
  final DateTime? localUpdatedAt;
  final DateTime? lastSyncedAt;
}

/// Remote row snapshot used by collection sync engines.
class UserOwnedSyncRemoteRow<T> {
  const UserOwnedSyncRemoteRow({
    required this.remoteId,
    required this.entity,
    required this.remoteUpdatedAt,
  });

  final String remoteId;
  final T entity;
  final DateTime remoteUpdatedAt;
}

/// Feature adapter for user-owned collections (timeline rows, etc.).
abstract interface class UserOwnedCollectionSyncAdapter<T> {
  String get tableName;

  String? get currentRemoteUserId;

  Future<List<UserOwnedSyncLocalRow<T>>> loadLocalRows();

  Future<List<UserOwnedSyncRemoteRow<T>>> fetchRemoteRows();

  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<T> remote,
    String remoteUserId,
  );

  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<T> remote,
    String remoteUserId,
  );

  Future<DateTime> pushUpsert({
    required int localId,
    required T entity,
    required String remoteId,
  });

  Future<void> pushDelete(String remoteId);

  Future<void> markLocalSynced({
    required int localId,
    required String remoteId,
    required DateTime syncedAt,
    required String remoteUserId,
  });

  Future<void> markLocalDirty(int localId);

  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  });
}
