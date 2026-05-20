import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_record_store.dart';
import '../../../../core/utils/sync_id.dart';
import '../datasources/daos/exercise_dao.dart';
import '../datasources/daos/program_dao.dart';
import '../datasources/daos/workout_dao.dart';
import '../datasources/daos/workout_execution_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

/// Resolves local integer IDs to remote UUIDs for training sync.
class TrainingSyncRefs {
  TrainingSyncRefs({
    required SyncRecordStore store,
    required ExerciseDao exerciseDao,
    required WorkoutDao workoutDao,
    required ProgramDao programDao,
    required WorkoutExecutionDao executionDao,
    TrainingRemoteClient? remoteClient,
  }) : _store = store,
       _exerciseDao = exerciseDao,
       _workoutDao = workoutDao,
       _programDao = programDao,
       _executionDao = executionDao,
       _remote = remoteClient ?? TrainingRemoteClient();

  final SyncRecordStore _store;
  final ExerciseDao _exerciseDao;
  final WorkoutDao _workoutDao;
  final ProgramDao _programDao;
  final WorkoutExecutionDao _executionDao;
  final TrainingRemoteClient _remote;

  Future<String?> exerciseRemoteId(int localId) async {
    final row = await _exerciseDao.getById(localId);
    if (row == null) return null;

    final resolved = await _remoteId(
      tableName: TrainingSyncTableNames.userExercises,
      localId: localId,
      rowRemoteId: row.remoteId,
    );
    if (resolved != null) return resolved;

    if (row.isVerified) {
      return _ensureExerciseOnRemote(row);
    }

    return _ensureUserExerciseOnRemote(row);
  }

  Future<String?> workoutRemoteId(int localId) async => _remoteId(
    tableName: TrainingSyncTableNames.userWorkouts,
    localId: localId,
    rowRemoteId: (await _workoutDao.getById(localId))?.remoteId,
  );

  Future<String?> programRemoteId(int localId) async => _remoteId(
    tableName: TrainingSyncTableNames.userPrograms,
    localId: localId,
    rowRemoteId: (await _programDao.getById(localId))?.remoteId,
  );

  Future<String?> executionRemoteId(int localId) async => _remoteId(
    tableName: TrainingSyncTableNames.userWorkoutExecutions,
    localId: localId,
    rowRemoteId: (await _executionDao.getById(localId))?.remoteId,
  );

  Future<int?> exerciseLocalId(String? remoteId) async {
    if (remoteId == null) return null;
    final row = await _exerciseDao.getFirstByRemoteId(remoteId);
    if (row != null) return row.id;
    return _store
        .getByRemoteId(
          tableName: TrainingSyncTableNames.userExercises,
          remoteId: remoteId,
        )
        .then((r) => r?.localId);
  }

  Future<int?> workoutLocalId(String? remoteId) async {
    if (remoteId == null) return null;
    final row = await _workoutDao.getByRemoteId(remoteId);
    if (row != null) return row.id;
    return _store
        .getByRemoteId(
          tableName: TrainingSyncTableNames.userWorkouts,
          remoteId: remoteId,
        )
        .then((r) => r?.localId);
  }

  Future<int?> programLocalId(String? remoteId) async {
    if (remoteId == null) return null;
    final row = await _programDao.getByRemoteId(remoteId);
    if (row != null) return row.id;
    return _store
        .getByRemoteId(
          tableName: TrainingSyncTableNames.userPrograms,
          remoteId: remoteId,
        )
        .then((r) => r?.localId);
  }

  Future<int?> executionLocalId(String? remoteId) async {
    if (remoteId == null) return null;
    final row = await _executionDao.getExecutionByRemoteId(remoteId);
    if (row != null) return row.id;
    return _store
        .getByRemoteId(
          tableName: TrainingSyncTableNames.userWorkoutExecutions,
          remoteId: remoteId,
        )
        .then((r) => r?.localId);
  }

  Future<String?> _ensureExerciseOnRemote(Exercise row) async {
    final catalogKey = row.catalogRemoteId ?? 'legacy-local-${row.id}';
    return _upsertExerciseOnRemote(row, catalogRemoteId: catalogKey);
  }

  Future<String?> _ensureUserExerciseOnRemote(Exercise row) async {
    if (row.remoteId != null) return row.remoteId;
    return _upsertExerciseOnRemote(row, catalogRemoteId: row.catalogRemoteId);
  }

  Future<String?> _upsertExerciseOnRemote(
    Exercise row, {
    String? catalogRemoteId,
  }) async {
    final client = _remote.client;
    final userId = _remote.currentUserId;
    if (client == null || userId == null) return null;

    try {
      if (catalogRemoteId != null && catalogRemoteId.isNotEmpty) {
        final existing = await client
            .from(TrainingSyncTableNames.userExercises)
            .select('id')
            .eq('user_id', userId)
            .eq('catalog_remote_id', catalogRemoteId)
            .maybeSingle();
        if (existing != null) {
          final remoteId = existing['id'] as String?;
          if (remoteId != null) {
            await _markExerciseSyncedLocally(
              row: row,
              catalogRemoteId: catalogRemoteId,
              remoteId: remoteId,
            );
            return remoteId;
          }
        }
      }

      final remoteId = generateSyncUuid();
      final muscles = await _exerciseDao.getMuscleFoci(row.id);
      final syncedAt = DateTime.now().toUtc();
      await client.from(TrainingSyncTableNames.userExercises).upsert(
        {
          'id': remoteId,
          'user_id': userId,
          'catalog_remote_id': catalogRemoteId,
          'name': row.name,
          'muscle_group': row.muscleGroup.name,
          'type': row.type.name,
          'movement_pattern': row.movementPattern?.name,
          'description': row.description,
          'default_load_mode': row.defaultLoadMode.name,
          'bodyweight_load_factor': row.bodyweightLoadFactor,
          'is_isometric': row.isIsometric,
          'target_muscles': muscles
              .map(
                (m) => {
                  'muscle': m.targetMuscle.name,
                  'region': m.muscleRegion?.name,
                  'role': m.role.name,
                },
              )
              .toList(growable: false),
          'updated_at': syncedAt.toIso8601String(),
          'deleted_at': null,
        },
        onConflict: 'id',
      );
      await _markExerciseSyncedLocally(
        row: row,
        catalogRemoteId: catalogRemoteId,
        remoteId: remoteId,
        syncedAt: syncedAt,
      );
      return remoteId;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Sync] ensure exercise on remote failed for #${row.id}: $e',
        );
      }
      return null;
    }
  }

  Future<void> _markExerciseSyncedLocally({
    required Exercise row,
    required String remoteId,
    String? catalogRemoteId,
    DateTime? syncedAt,
  }) async {
    final at = syncedAt ?? DateTime.now().toUtc();
    var targets = catalogRemoteId == null || catalogRemoteId.isEmpty
        ? <Exercise>[row]
        : await _exerciseDao.getAllByCatalogRemoteId(catalogRemoteId);
    if (targets.isEmpty) {
      targets = [row];
    }

    for (final target in targets) {
      await _exerciseDao.markSynced(
        id: target.id,
        remoteId: remoteId,
        syncedAt: at,
      );
    }
  }

  Future<String?> _remoteId({
    required String tableName,
    required int localId,
    required String? rowRemoteId,
  }) async {
    final record = await _store.getByLocalId(
      tableName: tableName,
      localId: localId,
    );
    return record?.remoteId ?? record?.syncId ?? rowRemoteId;
  }
}
