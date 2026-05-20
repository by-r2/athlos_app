import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import 'training_sync_helpers.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/enums/load_mode.dart';
import '../datasources/daos/workout_execution_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_refs.dart';
import 'training_sync_table_names.dart';

class ExecutionSetSyncBundle {
  const ExecutionSetSyncBundle({
    required this.set,
    this.segments = const [],
    this.executionRemoteId,
    this.exerciseRemoteId,
    this.remoteSegmentsConfig = const [],
  });

  final ExecutionSet set;
  final List<ExecutionSetSegment> segments;
  final String? executionRemoteId;
  final String? exerciseRemoteId;
  final List<Map<String, dynamic>> remoteSegmentsConfig;
}

class UserExecutionSetSyncAdapter
    implements UserOwnedCollectionSyncAdapter<ExecutionSetSyncBundle> {
  UserExecutionSetSyncAdapter(
    this._dao,
    this._refs, {
    TrainingRemoteClient? remoteClient,
  }) : _remote = remoteClient ?? TrainingRemoteClient();

  final WorkoutExecutionDao _dao;
  final TrainingSyncRefs _refs;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userExecutionSets;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<ExecutionSetSyncBundle>>> loadLocalRows() async {
    final rows = await _dao.getAllSetsForSync();
    final results = <UserOwnedSyncLocalRow<ExecutionSetSyncBundle>>[];
    for (final row in rows) {
      final segments = await _dao.getSegments(row.id);
      results.add(
        UserOwnedSyncLocalRow(
          localId: row.id,
          entity: ExecutionSetSyncBundle(set: row, segments: segments),
          remoteId: row.remoteId,
          localUpdatedAt: row.localUpdatedAt,
          lastSyncedAt: row.lastSyncedAt,
        ),
      );
    }
    return results;
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<ExecutionSetSyncBundle>>> fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<ExecutionSetSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<ExecutionSetSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final executionId = await _refs.executionLocalId(bundle.executionRemoteId);
    final exerciseId = await _refs.exerciseLocalId(bundle.exerciseRemoteId);
    if (executionId == null || exerciseId == null) {
      throw DatabaseException(
        'Cannot apply execution set ${remote.remoteId}: missing FK',
      );
    }

    final set = bundle.set;
    final id = await _dao.insertSet(
      ExecutionSetsCompanion.insert(
        executionId: executionId,
        exerciseId: exerciseId,
        setNumber: set.setNumber,
        plannedReps: Value(set.plannedReps),
        plannedWeight: Value(set.plannedWeight),
        reps: Value(set.reps),
        weight: Value(set.weight),
        duration: Value(set.duration),
        distance: Value(set.distance),
        isCompleted: Value(set.isCompleted),
        isWarmup: Value(set.isWarmup),
        rpe: Value(set.rpe),
        bodyWeightSnapshot: Value(set.bodyWeightSnapshot),
        loadModeOverride: Value(set.loadModeOverride),
        leftReps: Value(set.leftReps),
        leftWeight: Value(set.leftWeight),
        rightReps: Value(set.rightReps),
        rightWeight: Value(set.rightWeight),
        isUnilateral: Value(set.isUnilateral),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
    await _applySegments(id, bundle.remoteSegmentsConfig);
    await _dao.markSetSynced(
      id: id,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<ExecutionSetSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final executionId = await _refs.executionLocalId(bundle.executionRemoteId);
    final exerciseId = await _refs.exerciseLocalId(bundle.exerciseRemoteId);
    if (executionId == null || exerciseId == null) {
      throw DatabaseException(
        'Cannot update execution set ${remote.remoteId}: missing FK',
      );
    }

    final set = bundle.set;
    await _dao.updateSet(
      localId,
      ExecutionSetsCompanion(
        executionId: Value(executionId),
        exerciseId: Value(exerciseId),
        setNumber: Value(set.setNumber),
        plannedReps: Value(set.plannedReps),
        plannedWeight: Value(set.plannedWeight),
        reps: Value(set.reps),
        weight: Value(set.weight),
        duration: Value(set.duration),
        distance: Value(set.distance),
        isCompleted: Value(set.isCompleted),
        isWarmup: Value(set.isWarmup),
        rpe: Value(set.rpe),
        bodyWeightSnapshot: Value(set.bodyWeightSnapshot),
        loadModeOverride: Value(set.loadModeOverride),
        leftReps: Value(set.leftReps),
        leftWeight: Value(set.leftWeight),
        rightReps: Value(set.rightReps),
        rightWeight: Value(set.rightWeight),
        isUnilateral: Value(set.isUnilateral),
        remoteId: Value(remote.remoteId),
        lastSyncedAt: Value(remote.remoteUpdatedAt),
        localUpdatedAt: Value(remote.remoteUpdatedAt),
      ),
    );
    await _applySegments(localId, bundle.remoteSegmentsConfig);
    await _dao.markSetSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required ExecutionSetSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException(
        'User must be signed in to sync execution sets.',
      );
    }

    final set = entity.set;
    final executionRemoteId = requireRemoteId(
      await _refs.executionRemoteId(set.executionId),
      'Execution not synced yet for set $localId',
    );
    final exerciseRemoteId = requireRemoteId(
      await _refs.exerciseRemoteId(set.exerciseId),
      'Exercise not synced yet for set $localId',
    );

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      {
        'id': remoteId,
        'user_id': userId,
        'execution_remote_id': executionRemoteId,
        'exercise_remote_id': exerciseRemoteId,
        'set_number': set.setNumber,
        'planned_reps': set.plannedReps,
        'planned_weight': set.plannedWeight,
        'reps': set.reps,
        'weight': set.weight,
        'duration': set.duration,
        'distance': set.distance,
        'is_completed': set.isCompleted,
        'is_warmup': set.isWarmup,
        'rpe': set.rpe,
        'body_weight_snapshot': set.bodyWeightSnapshot,
        'load_mode_override': set.loadModeOverride?.name,
        'left_reps': set.leftReps,
        'left_weight': set.leftWeight,
        'right_reps': set.rightReps,
        'right_weight': set.rightWeight,
        'is_unilateral': set.isUnilateral,
        'segments_config': _segmentsToJson(entity.segments),
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
      _dao.markSetSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);

  @override
  Future<void> markLocalDirty(int localId) => _dao.markSetLocalDirty(localId);

  @override
  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  }) =>
      existingSyncId ?? entityRemoteId ?? generateSyncUuid();

  Future<void> _applySegments(
    int setId,
    List<Map<String, dynamic>> config,
  ) async {
    final companions = config
        .map(
          (item) => ExecutionSetSegmentsCompanion.insert(
            executionSetId: setId,
            segmentOrder: item['segment_order'] as int? ?? 0,
            reps: item['reps'] as int? ?? 0,
            weight: Value(_asDouble(item['weight'])),
          ),
        )
        .toList(growable: false);
    await _dao.replaceSegments(setId, companions);
  }

  List<Map<String, dynamic>> _segmentsToJson(List<ExecutionSetSegment> segments) =>
      segments
          .map(
            (s) => {
              'segment_order': s.segmentOrder,
              'reps': s.reps,
              'weight': s.weight,
            },
          )
          .toList(growable: false);

  UserOwnedSyncRemoteRow<ExecutionSetSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    final set = ExecutionSet(
      id: 0,
      executionId: 0,
      exerciseId: 0,
      setNumber: json['set_number'] as int? ?? 1,
      plannedReps: json['planned_reps'] as int?,
      plannedWeight: _asDouble(json['planned_weight']),
      reps: json['reps'] as int?,
      weight: _asDouble(json['weight']),
      duration: json['duration'] as int?,
      distance: _asDouble(json['distance']),
      isCompleted: json['is_completed'] as bool? ?? false,
      isWarmup: json['is_warmup'] as bool? ?? false,
      rpe: json['rpe'] as int?,
      bodyWeightSnapshot: _asDouble(json['body_weight_snapshot']),
      loadModeOverride: json['load_mode_override'] == null
          ? null
          : LoadMode.values.byName(json['load_mode_override'] as String),
      leftReps: json['left_reps'] as int?,
      leftWeight: _asDouble(json['left_weight']),
      rightReps: json['right_reps'] as int?,
      rightWeight: _asDouble(json['right_weight']),
      isUnilateral: json['is_unilateral'] as bool?,
      remoteId: remoteId,
      lastSyncedAt: updatedAt,
      localUpdatedAt: updatedAt,
    );
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: ExecutionSetSyncBundle(
        set: set,
        executionRemoteId: json['execution_remote_id'] as String?,
        exerciseRemoteId: json['exercise_remote_id'] as String?,
        remoteSegmentsConfig: _parseSegmentsConfig(json['segments_config']),
      ),
      remoteUpdatedAt: updatedAt,
    );
  }

  List<Map<String, dynamic>> _parseSegmentsConfig(Object? raw) {
    if (raw is String) {
      final decoded = jsonDecode(raw);
      return _parseSegmentsConfig(decoded);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
