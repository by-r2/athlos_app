import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import '../../../../core/utils/sync_id.dart';
import '../datasources/daos/program_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

class UserProgramSyncAdapter implements UserOwnedCollectionSyncAdapter<Program> {
  UserProgramSyncAdapter(this._dao, {TrainingRemoteClient? remoteClient})
    : _remote = remoteClient ?? TrainingRemoteClient();

  final ProgramDao _dao;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userPrograms;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<Program>>> loadLocalRows() async {
    final rows = await _dao.getAll();
    return rows
        .map(
          (row) => UserOwnedSyncLocalRow(
            localId: row.id,
            entity: row,
            remoteId: row.remoteId,
            localUpdatedAt: row.localUpdatedAt,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<Program>>> fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<Program>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<Program> remote,
    String remoteUserId,
  ) async {
    final id = await _dao.create(_toInsertCompanion(remote.entity));
    await _dao.markSynced(
      id: id,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<Program> remote,
    String remoteUserId,
  ) async {
    await _dao.updateProgram(localId, _toUpdateCompanion(remote.entity));
    await _dao.markSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required Program entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync programs.');
    }

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      _toRemoteJson(entity, userId: userId, remoteId: remoteId, syncedAt: syncedAt),
      onConflict: 'id',
    );
    return syncedAt;
  }

  @override
  Future<void> pushDelete(String remoteId) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return;

    final syncedAt = DateTime.now().toUtc();
    await client
        .from(tableName)
        .update({'deleted_at': syncedAt.toIso8601String()})
        .eq('id', remoteId)
        .eq('user_id', userId);
  }

  @override
  Future<void> markLocalSynced({
    required int localId,
    required String remoteId,
    required DateTime syncedAt,
    required String remoteUserId,
  }) =>
      _dao.markSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);

  @override
  Future<void> markLocalDirty(int localId) => _dao.markLocalDirty(localId);

  @override
  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  }) =>
      existingSyncId ?? entityRemoteId ?? generateSyncUuid();

  UserOwnedSyncRemoteRow<Program>? _remoteRowFromJson(Map<String, dynamic> json) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    final entity = Program(
      id: 0,
      name: json['name'] as String? ?? '',
      focus: json['focus'] as String? ?? 'hypertrophy',
      durationMode: json['duration_mode'] as String? ?? 'weeks',
      durationValue: json['duration_value'] as int? ?? 1,
      defaultRestSeconds: json['default_rest_seconds'] as int?,
      isActive: json['is_active'] as bool? ?? false,
      isInDeload: json['is_in_deload'] as bool? ?? false,
      deloadFrequency: json['deload_frequency'] as int?,
      deloadStrategy: json['deload_strategy'] as String?,
      deloadVolumeMultiplier: _asDouble(json['deload_volume_multiplier']),
      deloadIntensityMultiplier: _asDouble(json['deload_intensity_multiplier']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
      archivedAt: _parseDate(json['archived_at']),
      remoteId: remoteId,
      lastSyncedAt: updatedAt,
      localUpdatedAt: updatedAt,
    );
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: entity,
      remoteUpdatedAt: updatedAt,
    );
  }

  Map<String, dynamic> _toRemoteJson(
    Program row, {
    required String userId,
    required String remoteId,
    required DateTime syncedAt,
  }) =>
      {
        'id': remoteId,
        'user_id': userId,
        'name': row.name,
        'focus': row.focus,
        'duration_mode': row.durationMode,
        'duration_value': row.durationValue,
        'default_rest_seconds': row.defaultRestSeconds,
        'is_active': row.isActive,
        'is_in_deload': row.isInDeload,
        'deload_frequency': row.deloadFrequency,
        'deload_strategy': row.deloadStrategy,
        'deload_volume_multiplier': row.deloadVolumeMultiplier,
        'deload_intensity_multiplier': row.deloadIntensityMultiplier,
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'archived_at': row.archivedAt?.toUtc().toIso8601String(),
        'updated_at': syncedAt.toIso8601String(),
        'deleted_at': null,
      };

  ProgramsCompanion _toInsertCompanion(Program row) => ProgramsCompanion.insert(
    name: row.name,
    focus: row.focus,
    durationMode: row.durationMode,
    durationValue: row.durationValue,
    defaultRestSeconds: Value(row.defaultRestSeconds),
    isActive: Value(row.isActive),
    isInDeload: Value(row.isInDeload),
    deloadFrequency: Value(row.deloadFrequency),
    deloadStrategy: Value(row.deloadStrategy),
    deloadVolumeMultiplier: Value(row.deloadVolumeMultiplier),
    deloadIntensityMultiplier: Value(row.deloadIntensityMultiplier),
    createdAt: Value(row.createdAt),
    archivedAt: Value(row.archivedAt),
    remoteId: Value(row.remoteId),
    lastSyncedAt: Value(row.lastSyncedAt),
    localUpdatedAt: Value(row.localUpdatedAt ?? DateTime.now().toUtc()),
  );

  ProgramsCompanion _toUpdateCompanion(Program row) => ProgramsCompanion(
    name: Value(row.name),
    focus: Value(row.focus),
    durationMode: Value(row.durationMode),
    durationValue: Value(row.durationValue),
    defaultRestSeconds: Value(row.defaultRestSeconds),
    isActive: Value(row.isActive),
    isInDeload: Value(row.isInDeload),
    deloadFrequency: Value(row.deloadFrequency),
    deloadStrategy: Value(row.deloadStrategy),
    deloadVolumeMultiplier: Value(row.deloadVolumeMultiplier),
    deloadIntensityMultiplier: Value(row.deloadIntensityMultiplier),
    archivedAt: Value(row.archivedAt),
    remoteId: Value(row.remoteId),
    lastSyncedAt: Value(row.lastSyncedAt),
    localUpdatedAt: Value(row.localUpdatedAt),
  );

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
