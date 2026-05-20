import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/sync/user_owned_collection_sync_adapter.dart';
import '../../../../core/utils/sync_id.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';
import '../datasources/daos/exercise_dao.dart';
import 'training_remote_client.dart';
import 'training_sync_table_names.dart';

class ExerciseSyncBundle {
  const ExerciseSyncBundle({
    required this.row,
    required this.muscles,
  });

  final Exercise row;
  final List<ExerciseTargetMuscle> muscles;
}

class UserExerciseSyncAdapter
    implements UserOwnedCollectionSyncAdapter<ExerciseSyncBundle> {
  UserExerciseSyncAdapter(this._dao, {TrainingRemoteClient? remoteClient})
    : _remote = remoteClient ?? TrainingRemoteClient();

  final ExerciseDao _dao;
  final TrainingRemoteClient _remote;

  @override
  String get tableName => TrainingSyncTableNames.userExercises;

  @override
  String? get currentRemoteUserId => _remote.currentUserId;

  @override
  Future<List<UserOwnedSyncLocalRow<ExerciseSyncBundle>>> loadLocalRows() async {
    final rows = await _dao.getUserCreated();
    final results = <UserOwnedSyncLocalRow<ExerciseSyncBundle>>[];
    for (final row in rows) {
      final muscles = await _dao.getMuscleFoci(row.id);
      results.add(
        UserOwnedSyncLocalRow(
          localId: row.id,
          entity: ExerciseSyncBundle(row: row, muscles: muscles),
          remoteId: row.remoteId,
          localUpdatedAt: row.localUpdatedAt,
          lastSyncedAt: row.lastSyncedAt,
        ),
      );
    }
    return results;
  }

  @override
  Future<List<UserOwnedSyncRemoteRow<ExerciseSyncBundle>>> fetchRemoteRows() async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) return const [];

    final rows = await client.from(tableName).select().eq('user_id', userId);
    return rows
        .where((row) => row['deleted_at'] == null)
        .map(_remoteRowFromJson)
        .whereType<UserOwnedSyncRemoteRow<ExerciseSyncBundle>>()
        .toList(growable: false);
  }

  @override
  Future<int> insertFromRemote(
    UserOwnedSyncRemoteRow<ExerciseSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    final id = await _dao.create(_toInsertCompanion(bundle));
    await _dao.setMuscleFoci(
      id,
      bundle.muscles
          .map(
            (m) => (
              muscle: m.targetMuscle,
              region: m.muscleRegion,
              role: m.role,
            ),
          )
          .toList(),
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
    UserOwnedSyncRemoteRow<ExerciseSyncBundle> remote,
    String remoteUserId,
  ) async {
    final bundle = remote.entity;
    await _dao.updateById(localId, _toUpdateCompanion(bundle.row));
    await _dao.setMuscleFoci(
      localId,
      bundle.muscles
          .map(
            (m) => (
              muscle: m.targetMuscle,
              region: m.muscleRegion,
              role: m.role,
            ),
          )
          .toList(),
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
    required ExerciseSyncBundle entity,
    required String remoteId,
  }) async {
    final client = _remote.client;
    final userId = currentRemoteUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync exercises.');
    }

    final syncedAt = DateTime.now().toUtc();
    await client.from(tableName).upsert(
      _toRemoteJson(
        entity,
        userId: userId,
        remoteId: remoteId,
        syncedAt: syncedAt,
      ),
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

  UserOwnedSyncRemoteRow<ExerciseSyncBundle>? _remoteRowFromJson(
    Map<String, dynamic> json,
  ) {
    final remoteId = json['id'] as String?;
    if (remoteId == null) return null;
    final updatedAt = _parseDate(json['updated_at']) ?? DateTime.now().toUtc();
    final muscles = _parseMuscles(json['target_muscles']);
    final row = Exercise(
      id: 0,
      catalogRemoteId: json['catalog_remote_id'] as String?,
      name: json['name'] as String? ?? '',
      muscleGroup: MuscleGroup.values.byName(json['muscle_group'] as String),
      type: ExerciseType.values.byName(json['type'] as String),
      movementPattern: json['movement_pattern'] == null
          ? null
          : MovementPattern.values.byName(json['movement_pattern'] as String),
      description: json['description'] as String?,
      isVerified: false,
      defaultLoadMode: LoadMode.values.byName(
        json['default_load_mode'] as String,
      ),
      bodyweightLoadFactor: _asDouble(json['bodyweight_load_factor']),
      isIsometric: json['is_isometric'] as bool? ?? false,
      remoteId: remoteId,
      lastSyncedAt: updatedAt,
      localUpdatedAt: updatedAt,
    );
    return UserOwnedSyncRemoteRow(
      remoteId: remoteId,
      entity: ExerciseSyncBundle(row: row, muscles: muscles),
      remoteUpdatedAt: updatedAt,
    );
  }

  List<ExerciseTargetMuscle> _parseMuscles(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
            (m) => ExerciseTargetMuscle(
            exerciseId: 0,
            targetMuscle: TargetMuscle.values.byName(
              m['muscle'] as String? ?? m['target_muscle'] as String,
            ),
            muscleRegion: m['region'] == null
                ? null
                : MuscleRegion.values.byName(m['region'] as String),
            role: MuscleRole.values.byName(m['role'] as String? ?? 'primary'),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _toRemoteJson(
    ExerciseSyncBundle bundle, {
    required String userId,
    required String remoteId,
    required DateTime syncedAt,
  }) {
    final row = bundle.row;
    return {
      'id': remoteId,
      'user_id': userId,
      'catalog_remote_id': row.catalogRemoteId,
      'name': row.name,
      'muscle_group': row.muscleGroup.name,
      'type': row.type.name,
      'movement_pattern': row.movementPattern?.name,
      'description': row.description,
      'default_load_mode': row.defaultLoadMode.name,
      'bodyweight_load_factor': row.bodyweightLoadFactor,
      'is_isometric': row.isIsometric,
      'target_muscles': bundle.muscles
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
    };
  }

  ExercisesCompanion _toInsertCompanion(ExerciseSyncBundle bundle) {
    final row = bundle.row;
    return ExercisesCompanion.insert(
      catalogRemoteId: Value(row.catalogRemoteId),
      name: row.name,
      muscleGroup: row.muscleGroup,
      type: Value(row.type),
      movementPattern: Value(row.movementPattern),
      description: Value(row.description),
      isVerified: const Value(false),
      defaultLoadMode: Value(row.defaultLoadMode),
      bodyweightLoadFactor: Value(row.bodyweightLoadFactor),
      isIsometric: Value(row.isIsometric),
      remoteId: Value(row.remoteId),
      lastSyncedAt: Value(row.lastSyncedAt),
      localUpdatedAt: Value(row.localUpdatedAt ?? DateTime.now().toUtc()),
    );
  }

  ExercisesCompanion _toUpdateCompanion(Exercise row) => ExercisesCompanion(
    catalogRemoteId: Value(row.catalogRemoteId),
    name: Value(row.name),
    muscleGroup: Value(row.muscleGroup),
    type: Value(row.type),
    movementPattern: Value(row.movementPattern),
    description: Value(row.description),
    defaultLoadMode: Value(row.defaultLoadMode),
    bodyweightLoadFactor: Value(row.bodyweightLoadFactor),
    isIsometric: Value(row.isIsometric),
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
