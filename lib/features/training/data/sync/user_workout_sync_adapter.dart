import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/sync_record_store.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/enums/load_mode.dart';
import '../datasources/daos/exercise_dao.dart';
import '../datasources/daos/workout_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

class WorkoutSyncBundle {
  const WorkoutSyncBundle({
    required this.workout,
    this.exercises = const [],
    this.remoteExercisesConfig = const [],
  });

  final Workout workout;
  final List<WorkoutExercise> exercises;
  final List<Map<String, dynamic>> remoteExercisesConfig;
}

class UserWorkoutSyncAdapter
    implements UserOwnedCollectionSyncAdapter<WorkoutSyncBundle> {
  UserWorkoutSyncAdapter(
    this._workoutDao,
    this._exerciseDao,
    this._syncStore, {
    TrainingRemoteClient? remoteClient,
  }) : _remote = remoteClient ?? TrainingRemoteClient();

  final WorkoutDao _workoutDao;
  final ExerciseDao _exerciseDao;
  final SyncRecordStore _syncStore;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userWorkouts;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<WorkoutSyncBundle>>> loadLocalRows() async {
    final workouts = await _workoutDao.getAll();
    final results = <UserOwnedSyncLocalRow<WorkoutSyncBundle>>[];
    for (final workout in workouts) {
      final exercises = await _workoutDao.getExercises(workout.id);
      results.add(
        UserOwnedSyncLocalRow(
          localId: workout.id,
          entity: WorkoutSyncBundle(workout: workout, exercises: exercises),
          remoteId: workout.remoteId,
          localUpdatedAt: workout.localUpdatedAt,
          lastSyncedAt: workout.lastSyncedAt,
        ),
      );
    }
    return results;
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<WorkoutSyncBundle>>> fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<WorkoutSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<WorkoutSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final id = await _workoutDao.create(_toInsertCompanion(bundle.workout));
    if (bundle.remoteExercisesConfig.isNotEmpty) {
      await _applyRemoteExercisesConfig(id, bundle.remoteExercisesConfig);
    } else {
      await _applyLocalExercises(id, bundle.exercises);
    }
    await _workoutDao.markSynced(
      id: id,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
    return id;
  }

  @override
  Future<void> updateLocalFromRemote(
    int localId,
    UserOwnedSyncRemoteRow<WorkoutSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    await _workoutDao.updateById(localId, _toUpdateCompanion(bundle.workout));
    if (bundle.remoteExercisesConfig.isNotEmpty) {
      await _applyRemoteExercisesConfig(localId, bundle.remoteExercisesConfig);
    } else {
      await _applyLocalExercises(localId, bundle.exercises);
    }
    await _workoutDao.markSynced(
      id: localId,
      remoteId: remote.remoteId,
      syncedAt: remote.remoteUpdatedAt,
    );
  }

  @override
  Future<DateTime> pushUpsert({
    required int localId,
    required WorkoutSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync workouts.');
    }

    final config = await _buildExercisesConfig(entity.exercises);
    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      {
        'id': remoteId,
        'user_id': userId,
        'name': entity.workout.name,
        'description': entity.workout.description,
        'sort_order': entity.workout.sortOrder,
        'is_archived': entity.workout.isArchived,
        'created_at': entity.workout.createdAt.toUtc().toIso8601String(),
        'exercises_config': config,
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
      _workoutDao.markSynced(id: localId, remoteId: remoteId, syncedAt: syncedAt);

  @override
  Future<void> markLocalDirty(int localId) => _workoutDao.markLocalDirty(localId);

  @override
  String resolveStableSyncId({
    required int localId,
    String? existingSyncId,
    String? entityRemoteId,
  }) =>
      existingSyncId ?? entityRemoteId ?? generateSyncUuid();

  Future<List<Map<String, dynamic>>> _buildExercisesConfig(
    List<WorkoutExercise> exercises,
  ) async {
    final config = <Map<String, dynamic>>[];
    for (final row in exercises) {
      final exercise = await _exerciseDao.getById(row.exerciseId);
      final record = exercise == null
          ? null
          : await _syncStore.getByLocalId(
              tableName: TrainingSyncTableNames.userExercises,
              localId: exercise.id,
            );
      final isCatalog = exercise?.isVerified ?? false;
      config.add({
        'exercise_remote_id': isCatalog
            ? exercise?.catalogRemoteId
            : (record?.remoteId ?? exercise?.remoteId),
        'is_catalog_reference': isCatalog,
        'order': row.order,
        'sets': row.sets,
        'min_reps': row.minReps,
        'max_reps': row.maxReps,
        'is_amrap': row.isAmrap,
        'rest': row.rest,
        'duration': row.duration,
        'group_id': row.groupId,
        'is_unilateral': row.isUnilateral,
        'load_mode_override': row.loadModeOverride?.name,
        'notes': row.notes,
      });
    }
    return config;
  }

  Future<void> _applyRemoteExercisesConfig(
    int workoutId,
    List<Map<String, dynamic>> config,
  ) async {
    final companions = <WorkoutExercisesCompanion>[];
    for (final item in config) {
      final exerciseId = await _resolveExerciseFromRemoteConfig(item);
      if (exerciseId == null) continue;
      companions.add(
        WorkoutExercisesCompanion.insert(
          workoutId: workoutId,
          exerciseId: exerciseId,
          order: item['order'] as int? ?? 0,
          sets: item['sets'] as int? ?? 1,
          minReps: Value(item['min_reps'] as int?),
          maxReps: Value(item['max_reps'] as int?),
          isAmrap: Value(item['is_amrap'] as bool? ?? false),
          rest: Value(item['rest'] as int? ?? 60),
          duration: Value(item['duration'] as int?),
          groupId: Value(item['group_id'] as int?),
          isUnilateral: Value(item['is_unilateral'] as bool? ?? false),
          loadModeOverride: item['load_mode_override'] == null
              ? const Value.absent()
              : Value(
                  LoadMode.values.byName(
                    item['load_mode_override'] as String,
                  ),
                ),
          notes: Value(item['notes'] as String?),
        ),
      );
    }
    await _workoutDao.setExercises(workoutId, companions);
  }

  Future<void> _applyLocalExercises(
    int workoutId,
    List<WorkoutExercise> template,
  ) async {
    final companions = <WorkoutExercisesCompanion>[];
    for (final row in template) {
      final exerciseId = row.exerciseId;
      if (exerciseId == null) continue;
      companions.add(
        WorkoutExercisesCompanion.insert(
          workoutId: workoutId,
          exerciseId: exerciseId,
          order: row.order,
          sets: row.sets,
          minReps: Value(row.minReps),
          maxReps: Value(row.maxReps),
          isAmrap: Value(row.isAmrap),
          rest: Value(row.rest),
          duration: Value(row.duration),
          groupId: Value(row.groupId),
          isUnilateral: Value(row.isUnilateral),
          loadModeOverride: Value(row.loadModeOverride),
          notes: Value(row.notes),
        ),
      );
    }
    await _workoutDao.setExercises(workoutId, companions);
  }

  Future<int?> _resolveExerciseFromRemoteConfig(Map<String, dynamic> item) async {
    if (item['is_catalog_reference'] == true) {
      final catalogId = item['exercise_remote_id'] as String?;
      if (catalogId != null) {
        final row = await _exerciseDao.getFirstByCatalogRemoteId(catalogId);
        if (row != null) return row.id;
      }
      return null;
    }

    final remoteId = item['exercise_remote_id'] as String?;
    if (remoteId != null) {
      final byRemote = await _exerciseDao.getFirstByRemoteId(remoteId);
      if (byRemote != null) return byRemote.id;
      final record = await _syncStore.getByRemoteId(
        tableName: TrainingSyncTableNames.userExercises,
        remoteId: remoteId,
      );
      if (record != null) {
        return record.localId;
      }
    }
    return null;
  }

  UserOwnedSyncRemoteRow<WorkoutSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    final workout = Workout(
      id: 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
      remoteId: remoteId,
      lastSyncedAt: updatedAt,
      localUpdatedAt: updatedAt,
    );
    final config = _parseConfigMaps(json['exercises_config']);
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: WorkoutSyncBundle(
        workout: workout,
        remoteExercisesConfig: config,
      ),
      remoteUpdatedAt: updatedAt,
    );
  }

  List<Map<String, dynamic>> _parseConfigMaps(Object? raw) {
    if (raw is String) {
      final decoded = jsonDecode(raw);
      return _parseConfigMaps(decoded);
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  WorkoutsCompanion _toInsertCompanion(Workout workout) =>
      WorkoutsCompanion.insert(
        name: workout.name,
        description: Value(workout.description),
        sortOrder: Value(workout.sortOrder),
        isArchived: Value(workout.isArchived),
        createdAt: Value(workout.createdAt),
        remoteId: Value(workout.remoteId),
        lastSyncedAt: Value(workout.lastSyncedAt),
        localUpdatedAt: Value(workout.localUpdatedAt ?? DateTime.now().toUtc()),
      );

  WorkoutsCompanion _toUpdateCompanion(Workout workout) => WorkoutsCompanion(
    name: Value(workout.name),
    description: Value(workout.description),
    sortOrder: Value(workout.sortOrder),
    isArchived: Value(workout.isArchived),
    remoteId: Value(workout.remoteId),
    lastSyncedAt: Value(workout.lastSyncedAt),
    localUpdatedAt: Value(workout.localUpdatedAt),
  );

  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
