import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import 'training_sync_helpers.dart';
import '../../../../core/utils/sync_id.dart';
import '../datasources/daos/cycle_step_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_refs.dart';
import 'training_sync_table_names.dart';

class CycleStepSyncBundle {
  const CycleStepSyncBundle({
    required this.orderIndex,
    this.programId,
    this.workoutId,
    this.programRemoteId,
    this.workoutRemoteId,
    this.remoteId,
    this.lastSyncedAt,
    this.localUpdatedAt,
  });

  factory CycleStepSyncBundle.fromLocal(CycleStep row) => CycleStepSyncBundle(
    orderIndex: row.orderIndex,
    programId: row.programId,
    workoutId: row.workoutId,
    remoteId: row.remoteId,
    lastSyncedAt: row.lastSyncedAt,
    localUpdatedAt: row.localUpdatedAt,
  );

  final int orderIndex;
  final int? programId;
  final int? workoutId;
  final String? programRemoteId;
  final String? workoutRemoteId;
  final String? remoteId;
  final DateTime? lastSyncedAt;
  final DateTime? localUpdatedAt;
}

class UserCycleStepSyncAdapter
    implements UserOwnedCollectionSyncAdapter<CycleStepSyncBundle> {
  UserCycleStepSyncAdapter(
    this._dao,
    this._refs, {
    TrainingRemoteClient? remoteClient,
  }) : _remote = remoteClient ?? TrainingRemoteClient();

  final CycleStepDao _dao;
  final TrainingSyncRefs _refs;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userCycleSteps;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<CycleStepSyncBundle>>> loadLocalRows() async {
    final rows = await _dao.getAll();
    return rows
        .map(
          (row) => UserOwnedSyncLocalRow(
            localId: row.id,
            entity: CycleStepSyncBundle.fromLocal(row),
            remoteId: row.remoteId,
            localUpdatedAt: row.localUpdatedAt,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<CycleStepSyncBundle>>> fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<CycleStepSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<CycleStepSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    final workoutId = await _refs.workoutLocalId(bundle.workoutRemoteId);
    if (programId == null || workoutId == null) {
      throw DatabaseException(
        'Cannot apply cycle step ${remote.remoteId}: missing FK',
      );
    }

    final id = await _dao.insertStep(
      CycleStepsCompanion.insert(
        programId: programId,
        orderIndex: bundle.orderIndex,
        workoutId: workoutId,
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
    UserOwnedSyncRemoteRow<CycleStepSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    final workoutId = await _refs.workoutLocalId(bundle.workoutRemoteId);
    if (programId == null || workoutId == null) {
      throw DatabaseException(
        'Cannot update cycle step ${remote.remoteId}: missing FK',
      );
    }

    await _dao.updateStep(
      localId,
      CycleStepsCompanion(
        programId: Value(programId),
        orderIndex: Value(bundle.orderIndex),
        workoutId: Value(workoutId),
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
    required CycleStepSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync cycle steps.');
    }

    final programId = entity.programId;
    final workoutId = entity.workoutId;
    if (programId == null || workoutId == null) {
      throw DatabaseException('Cannot push cycle step $localId: missing local FK');
    }

    final programRemoteId = requireRemoteId(
      await _refs.programRemoteId(programId),
      'Program not synced yet for cycle step $localId',
    );
    final workoutRemoteId = requireRemoteId(
      await _refs.workoutRemoteId(workoutId),
      'Workout not synced yet for cycle step $localId',
    );

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      {
        'id': remoteId,
        'user_id': userId,
        'program_remote_id': programRemoteId,
        'order_index': entity.orderIndex,
        'workout_remote_id': workoutRemoteId,
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

  UserOwnedSyncRemoteRow<CycleStepSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: CycleStepSyncBundle(
        orderIndex: json['order_index'] as int? ?? 0,
        programRemoteId: json['program_remote_id'] as String?,
        workoutRemoteId: json['workout_remote_id'] as String?,
        remoteId: remoteId,
        lastSyncedAt: updatedAt,
        localUpdatedAt: updatedAt,
      ),
      remoteUpdatedAt: updatedAt,
    );
  }

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
