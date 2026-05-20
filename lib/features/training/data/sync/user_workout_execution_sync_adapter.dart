import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import 'training_sync_helpers.dart';
import '../../../../core/utils/sync_id.dart';
import '../datasources/daos/workout_execution_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_refs.dart';
import 'training_sync_table_names.dart';

class WorkoutExecutionSyncBundle {
  const WorkoutExecutionSyncBundle({
    required this.workoutId,
    required this.programId,
    required this.startedAt,
    this.finishedAt,
    this.exerciseConfigSnapshot,
    this.workoutRemoteId,
    this.programRemoteId,
    this.remoteId,
    this.lastSyncedAt,
    this.localUpdatedAt,
  });

  factory WorkoutExecutionSyncBundle.fromLocal(WorkoutExecution row) =>
      WorkoutExecutionSyncBundle(
        workoutId: row.workoutId,
        programId: row.programId,
        startedAt: row.startedAt,
        finishedAt: row.finishedAt,
        exerciseConfigSnapshot: row.exerciseConfigSnapshot,
        remoteId: row.remoteId,
        lastSyncedAt: row.lastSyncedAt,
        localUpdatedAt: row.localUpdatedAt,
      );

  final int workoutId;
  final int programId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? exerciseConfigSnapshot;
  final String? workoutRemoteId;
  final String? programRemoteId;
  final String? remoteId;
  final DateTime? lastSyncedAt;
  final DateTime? localUpdatedAt;
}

class UserWorkoutExecutionSyncAdapter
    implements UserOwnedCollectionSyncAdapter<WorkoutExecutionSyncBundle> {
  UserWorkoutExecutionSyncAdapter(
    this._dao,
    this._refs, {
    TrainingRemoteClient? remoteClient,
  }) : _remote = remoteClient ?? TrainingRemoteClient();

  final WorkoutExecutionDao _dao;
  final TrainingSyncRefs _refs;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userWorkoutExecutions;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<WorkoutExecutionSyncBundle>>>
  loadLocalRows() async {
    final rows = await _dao.getAllForSync();
    return rows
        .map(
          (row) => UserOwnedSyncLocalRow(
            localId: row.id,
            entity: WorkoutExecutionSyncBundle.fromLocal(row),
            remoteId: row.remoteId,
            localUpdatedAt: row.localUpdatedAt,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<WorkoutExecutionSyncBundle>>>
  fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<WorkoutExecutionSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<WorkoutExecutionSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final workoutId = await _refs.workoutLocalId(bundle.workoutRemoteId);
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    if (workoutId == null || programId == null) {
      throw DatabaseException(
        'Cannot apply execution ${remote.remoteId}: missing FK',
      );
    }

    final id = await _dao.create(
      WorkoutExecutionsCompanion.insert(
        workoutId: workoutId,
        programId: programId,
        startedAt: Value(bundle.startedAt),
        finishedAt: Value(bundle.finishedAt),
        exerciseConfigSnapshot: Value(bundle.exerciseConfigSnapshot),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
    await _dao.markExecutionSynced(
      id: id,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<WorkoutExecutionSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final workoutId = await _refs.workoutLocalId(bundle.workoutRemoteId);
    final programId = await _refs.programLocalId(bundle.programRemoteId);
    if (workoutId == null || programId == null) {
      throw DatabaseException(
        'Cannot update execution ${remote.remoteId}: missing FK',
      );
    }

    await _dao.updateExecution(
      localId,
      WorkoutExecutionsCompanion(
        workoutId: Value(workoutId),
        programId: Value(programId),
        startedAt: Value(bundle.startedAt),
        finishedAt: Value(bundle.finishedAt),
        exerciseConfigSnapshot: Value(bundle.exerciseConfigSnapshot),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
    await _dao.markExecutionSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required WorkoutExecutionSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException(
        'User must be signed in to sync workout executions.',
      );
    }

    final workoutRemoteId = requireRemoteId(
      await _refs.workoutRemoteId(entity.workoutId),
      'Workout not synced yet for execution $localId',
    );
    final programRemoteId = requireRemoteId(
      await _refs.programRemoteId(entity.programId),
      'Program not synced yet for execution $localId',
    );

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      {
        'id': remoteId,
        'user_id': userId,
        'workout_remote_id': workoutRemoteId,
        'program_remote_id': programRemoteId,
        'started_at': entity.startedAt.toUtc().toIso8601String(),
        'finished_at': entity.finishedAt?.toUtc().toIso8601String(),
        'exercise_config_snapshot': entity.exerciseConfigSnapshot,
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
      _dao.markExecutionSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);

  @override
  Future<void> markLocalDirty(int localId) => _dao.markExecutionLocalDirty(localId);

  @override
  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  }) =>
      existingSyncId ?? entityRemoteId ?? generateSyncUuid();

  UserOwnedSyncRemoteRow<WorkoutExecutionSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: WorkoutExecutionSyncBundle(
        workoutId: 0,
        programId: 0,
        startedAt: _parseDate(json['started_at']) ?? DateTime.now().toUtc(),
        finishedAt: _parseDate(json['finished_at']),
        exerciseConfigSnapshot: json['exercise_config_snapshot'] as String?,
        workoutRemoteId: json['workout_remote_id'] as String?,
        programRemoteId: json['program_remote_id'] as String?,
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
