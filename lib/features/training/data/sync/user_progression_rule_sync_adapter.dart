import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import 'training_sync_helpers.dart';
import '../../../../core/utils/sync_id.dart';
import '../datasources/daos/progression_rule_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_refs.dart';
import 'training_sync_table_names.dart';

class ProgressionRuleSyncBundle {
  const ProgressionRuleSyncBundle({
    required this.type,
    required this.value,
    required this.frequency,
    this.condition,
    this.conditionValue,
    this.programId,
    this.exerciseId,
    this.programRemoteId,
    this.exerciseRemoteId,
    this.remoteId,
    this.lastSyncedAt,
    this.localUpdatedAt,
  });

  factory ProgressionRuleSyncBundle.fromLocal(ProgressionRule row) =>
      ProgressionRuleSyncBundle(
        type: row.type,
        value: row.value,
        frequency: row.frequency,
        condition: row.condition,
        conditionValue: row.conditionValue,
        programId: row.programId,
        exerciseId: row.exerciseId,
        remoteId: row.remoteId,
        lastSyncedAt: row.lastSyncedAt,
        localUpdatedAt: row.localUpdatedAt,
      );

  final String type;
  final double value;
  final String frequency;
  final String? condition;
  final double? conditionValue;
  final int? programId;
  final int? exerciseId;
  final String? programRemoteId;
  final String? exerciseRemoteId;
  final String? remoteId;
  final DateTime? lastSyncedAt;
  final DateTime? localUpdatedAt;
}

class UserProgressionRuleSyncAdapter
    implements UserOwnedCollectionSyncAdapter<ProgressionRuleSyncBundle> {
  UserProgressionRuleSyncAdapter(
    this._dao,
    this._refs, {
    TrainingRemoteClient? remoteClient,
  }) : _remote = remoteClient ?? TrainingRemoteClient();

  final ProgressionRuleDao _dao;
  final TrainingSyncRefs _refs;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userProgressionRules;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<ProgressionRuleSyncBundle>>> loadLocalRows() async {
    final rows = await _dao.getAll();
    return rows
        .map(
          (row) => UserOwnedSyncLocalRow(
            localId: row.id,
            entity: ProgressionRuleSyncBundle.fromLocal(row),
            remoteId: row.remoteId,
            localUpdatedAt: row.localUpdatedAt,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<ProgressionRuleSyncBundle>>>
  fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<ProgressionRuleSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<ProgressionRuleSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    final exerciseId = await _refs.exerciseLocalId(bundle.exerciseRemoteId);
    if (programId == null || exerciseId == null) {
      throw DatabaseException(
        'Cannot apply progression rule ${remote.remoteId}: missing FK',
      );
    }

    final id = await _dao.create(
      ProgressionRulesCompanion.insert(
        programId: programId,
        exerciseId: exerciseId,
        type: bundle.type,
        value: bundle.value,
        frequency: bundle.frequency,
        condition: Value(bundle.condition),
        conditionValue: Value(bundle.conditionValue),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
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
    UserOwnedSyncRemoteRow<ProgressionRuleSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    final exerciseId = await _refs.exerciseLocalId(bundle.exerciseRemoteId);
    if (programId == null || exerciseId == null) {
      throw DatabaseException(
        'Cannot update progression rule ${remote.remoteId}: missing FK',
      );
    }

    await _dao.updateRule(
      localId,
      ProgressionRulesCompanion(
        programId: Value(programId),
        exerciseId: Value(exerciseId),
        type: Value(bundle.type),
        value: Value(bundle.value),
        frequency: Value(bundle.frequency),
        condition: Value(bundle.condition),
        conditionValue: Value(bundle.conditionValue),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
    await _dao.markSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required ProgressionRuleSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException(
        'User must be signed in to sync progression rules.',
      );
    }

    final programId = entity.programId;
    final exerciseId = entity.exerciseId;
    if (programId == null || exerciseId == null) {
      throw DatabaseException(
        'Cannot push progression rule $localId: missing local FK',
      );
    }

    final programRemoteId = requireRemoteId(
      await _refs.programRemoteId(programId),
      'Program not synced yet for progression rule $localId',
    );
    final exerciseRemoteId = requireRemoteId(
      await _refs.exerciseRemoteId(exerciseId),
      'Exercise not synced yet for progression rule $localId',
    );

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      {
        'id': remoteId,
        'user_id': userId,
        'program_remote_id': programRemoteId,
        'exercise_remote_id': exerciseRemoteId,
        'type': entity.type,
        'value': entity.value,
        'frequency': entity.frequency,
        'condition': entity.condition,
        'condition_value': entity.conditionValue,
        'updated_at': syncedAt.toIso8601String(),
        'deleted_at': null,
      },
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

  UserOwnedSyncRemoteRow<ProgressionRuleSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: ProgressionRuleSyncBundle(
        type: json['type'] as String? ?? 'weight',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        frequency: json['frequency'] as String? ?? 'every_session',
        condition: json['condition'] as String?,
        conditionValue: _asDouble(json['condition_value']),
        programRemoteId: json['program_remote_id'] as String?,
        exerciseRemoteId: json['exercise_remote_id'] as String?,
        remoteId: remoteId,
        lastSyncedAt: updatedAt,
        localUpdatedAt: updatedAt,
      ),
      remoteUpdatedAt: updatedAt,
    );
  }

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
