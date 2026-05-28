import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_adapter.dart';
import '../../../../core/sync/sync_user_id.dart';
import 'training_remote_client.dart';
import 'training_sync_json.dart';
import 'training_sync_store.dart';
import 'training_sync_table_names.dart';

List<SyncAdapter<dynamic>> buildTrainingSyncAdapters({
  required TrainingSyncStore store,
  required TrainingRemoteClient remote,
  required String userId,
}) =>
    [
      ExerciseSyncAdapter(store: store, remote: remote, userId: userId),
      WorkoutSyncAdapter(store: store, remote: remote, userId: userId),
      WorkoutExerciseSyncAdapter(store: store, remote: remote, userId: userId),
      ProgramSyncAdapter(store: store, remote: remote, userId: userId),
      ProgressionRuleSyncAdapter(store: store, remote: remote, userId: userId),
      CycleStepSyncAdapter(store: store, remote: remote, userId: userId),
      WorkoutExecutionSyncAdapter(store: store, remote: remote, userId: userId),
      ExecutionSetSyncAdapter(store: store, remote: remote, userId: userId),
    ];

abstract class _TrainingRowSyncAdapter<Row> implements SyncAdapter<Row> {
  _TrainingRowSyncAdapter({
    required this.store,
    required this.remote,
    required this.userId,
  });

  final TrainingSyncStore store;
  final TrainingRemoteClient remote;
  final String userId;

  @override
  Future<void> pushToRemote(List<Row> rows) async {
    if (!isValidSyncUserId(userId)) return;

    for (final row in rows) {
      final payload = Map<String, dynamic>.from(toJson(row));
      final rowUserId = payload['user_id'] as String?;
      if (!isValidSyncUserId(rowUserId)) {
        payload['user_id'] = userId;
      }
      final id = payload['id'] as String?;
      if (id == null || id.trim().isEmpty || !isValidSyncUserId(id)) {
        debugPrint('[SyncV2] skip push $tableName: missing row id');
        continue;
      }
      await remote.upsert(table: tableName, row: payload);
    }
  }

  @override
  Future<void> pushDeletes(List<Row> rows) async {
    if (!isValidSyncUserId(userId)) return;

    for (final row in rows) {
      final id = rowId(row);
      if (!isValidSyncUserId(id)) continue;
      await remote.deleteRow(
        table: tableName,
        id: id,
        userId: deleteUserId,
        ownerColumn: deleteOwnerColumn,
        ownerId: deleteOwnerId,
      );
    }
  }

  @override
  Future<List<Row>> pullFromRemote(DateTime lastPullAt) async {
    if (!isValidSyncUserId(userId) &&
        (pullOwnerColumn == null || !isValidSyncUserId(pullOwnerId))) {
      return const [];
    }

    final jsonRows = await remote.fetchUpdatedSince(
      table: tableName,
      userId: userId,
      lastPullAt: lastPullAt,
      ownerColumn: pullOwnerColumn,
      ownerId: pullOwnerId,
    );
    return jsonRows.map(fromJson).toList(growable: false);
  }

  @override
  Future<void> applyRemoteRows(List<Row> rows) async {
    for (final row in rows) {
      final id = getId(row);
      final local = await getLocal(id);
      if (local != null && localIsDirty(local)) continue;
      await upsertRemote(row);
    }
  }

  @override
  Future<void> markClean(List<String> ids) async {
    for (final id in ids) {
      await markLocalClean(id);
    }
  }

  @override
  Future<void> hardDelete(List<String> ids) async {
    for (final id in ids) {
      await hardDeleteLocal(id);
    }
  }

  @override
  String getId(Row row) => rowId(row);

  Map<String, dynamic> toJson(Row row);
  Row fromJson(Map<String, dynamic> json);
  String rowId(Row row);
  Future<Row?> getLocal(String id);
  bool localIsDirty(Row local);
  Future<void> upsertRemote(Row row);
  Future<void> markLocalClean(String id);
  Future<void> hardDeleteLocal(String id);

  String? get deleteUserId => userId;
  String? get deleteOwnerColumn => pullOwnerColumn;
  String? get deleteOwnerId => pullOwnerId;

  String? get pullOwnerColumn => null;
  String? get pullOwnerId => null;
}

class ExerciseSyncAdapter extends _TrainingRowSyncAdapter<Exercise> {
  ExerciseSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.exercises;

  @override
  String? get deleteUserId => null;

  @override
  String? get deleteOwnerColumn => 'created_by';

  @override
  String? get deleteOwnerId => userId;

  @override
  String? get pullOwnerColumn => 'created_by';

  @override
  String? get pullOwnerId => userId;

  @override
  Future<List<Exercise>> loadDirty() => store.getDirtyExercises(userId);

  @override
  Future<List<Exercise>> loadDirtyTombstones() =>
      store.getDirtyTombstonesExercises(userId);

  @override
  Map<String, dynamic> toJson(Exercise row) =>
      exerciseToJson(row, userId: userId);

  @override
  Exercise fromJson(Map<String, dynamic> json) {
    final companion = exerciseFromJson(json);
    return Exercise(
      id: companion.id.value,
      createdBy: companion.createdBy.value,
      isVerified: companion.isVerified.value,
      name: companion.name.value,
      muscleGroup: companion.muscleGroup.value,
      type: companion.type.value,
      movementPattern: companion.movementPattern.value,
      description: companion.description.value,
      defaultLoadMode: companion.defaultLoadMode.value,
      bodyweightLoadFactor: companion.bodyweightLoadFactor.value,
      isIsometric: companion.isIsometric.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(Exercise row) => row.id;

  @override
  Future<Exercise?> getLocal(String id) => store.getExerciseById(id);

  @override
  bool localIsDirty(Exercise local) => local.isDirty;

  @override
  Future<void> upsertRemote(Exercise row) =>
      store.upsertExerciseFromRemote(exerciseFromJson(toJson(row)));

  @override
  Future<void> markLocalClean(String id) => store.markExerciseClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteExercise(id);
}

class WorkoutSyncAdapter extends _TrainingRowSyncAdapter<Workout> {
  WorkoutSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.workouts;

  @override
  Future<List<Workout>> loadDirty() => store.getDirtyWorkouts(userId);

  @override
  Future<List<Workout>> loadDirtyTombstones() =>
      store.getDirtyTombstonesWorkouts(userId);

  @override
  Map<String, dynamic> toJson(Workout row) => workoutToJson(row);

  @override
  Workout fromJson(Map<String, dynamic> json) {
    final companion = workoutFromJson(json);
    return Workout(
      id: companion.id.value,
      userId: companion.userId.value,
      name: companion.name.value,
      description: companion.description.value,
      sortOrder: companion.sortOrder.value,
      isArchived: companion.isArchived.value,
      createdAt: companion.createdAt.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(Workout row) => row.id;

  @override
  Future<Workout?> getLocal(String id) => store.getWorkoutById(id);

  @override
  bool localIsDirty(Workout local) => local.isDirty;

  @override
  Future<void> upsertRemote(Workout row) =>
      store.upsertWorkoutFromRemote(workoutFromJson(toJson(row)));

  @override
  Future<void> markLocalClean(String id) => store.markWorkoutClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteWorkout(id);
}

class WorkoutExerciseSyncAdapter extends _TrainingRowSyncAdapter<WorkoutExercise> {
  WorkoutExerciseSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.workoutExercises;

  @override
  Future<List<WorkoutExercise>> loadDirty() =>
      store.getDirtyWorkoutExercises(userId);

  @override
  Future<List<WorkoutExercise>> loadDirtyTombstones() =>
      store.getDirtyTombstonesWorkoutExercises(userId);

  @override
  Map<String, dynamic> toJson(WorkoutExercise row) => workoutExerciseToJson(row);

  @override
  WorkoutExercise fromJson(Map<String, dynamic> json) {
    final companion = workoutExerciseFromJson(json);
    return WorkoutExercise(
      id: companion.id.value,
      userId: companion.userId.value,
      workoutId: companion.workoutId.value,
      exerciseId: companion.exerciseId.value,
      sortOrder: companion.sortOrder.value,
      sets: companion.sets.value,
      minReps: companion.minReps.value,
      maxReps: companion.maxReps.value,
      isAmrap: companion.isAmrap.value,
      restSeconds: companion.restSeconds.value,
      durationSeconds: companion.durationSeconds.value,
      groupId: companion.groupId.value,
      isUnilateral: companion.isUnilateral.value,
      loadModeOverride: companion.loadModeOverride.value,
      notes: companion.notes.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(WorkoutExercise row) => row.id;

  @override
  Future<WorkoutExercise?> getLocal(String id) => store.getWorkoutExerciseById(id);

  @override
  bool localIsDirty(WorkoutExercise local) => local.isDirty;

  @override
  Future<void> upsertRemote(WorkoutExercise row) => store.upsertWorkoutExerciseFromRemote(
    workoutExerciseFromJson(toJson(row)),
  );

  @override
  Future<void> markLocalClean(String id) => store.markWorkoutExerciseClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteWorkoutExercise(id);
}

class ProgramSyncAdapter extends _TrainingRowSyncAdapter<Program> {
  ProgramSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.programs;

  @override
  Future<List<Program>> loadDirty() => store.getDirtyPrograms(userId);

  @override
  Future<List<Program>> loadDirtyTombstones() =>
      store.getDirtyTombstonesPrograms(userId);

  @override
  Map<String, dynamic> toJson(Program row) => programToJson(row);

  @override
  Program fromJson(Map<String, dynamic> json) {
    final companion = programFromJson(json);
    return Program(
      id: companion.id.value,
      userId: companion.userId.value,
      name: companion.name.value,
      focus: companion.focus.value,
      durationMode: companion.durationMode.value,
      durationValue: companion.durationValue.value,
      defaultRestSeconds: companion.defaultRestSeconds.value,
      isActive: companion.isActive.value,
      isInDeload: companion.isInDeload.value,
      deloadFrequency: companion.deloadFrequency.value,
      deloadStrategy: companion.deloadStrategy.value,
      deloadVolumeMultiplier: companion.deloadVolumeMultiplier.value,
      deloadIntensityMultiplier: companion.deloadIntensityMultiplier.value,
      createdAt: companion.createdAt.value,
      archivedAt: companion.archivedAt.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(Program row) => row.id;

  @override
  Future<Program?> getLocal(String id) => store.getProgramById(id);

  @override
  bool localIsDirty(Program local) => local.isDirty;

  @override
  Future<void> upsertRemote(Program row) =>
      store.upsertProgramFromRemote(programFromJson(toJson(row)));

  @override
  Future<void> markLocalClean(String id) => store.markProgramClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteProgram(id);
}

class ProgressionRuleSyncAdapter extends _TrainingRowSyncAdapter<ProgressionRule> {
  ProgressionRuleSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.progressionRules;

  @override
  Future<List<ProgressionRule>> loadDirty() =>
      store.getDirtyProgressionRules(userId);

  @override
  Future<List<ProgressionRule>> loadDirtyTombstones() =>
      store.getDirtyTombstonesProgressionRules(userId);

  @override
  Map<String, dynamic> toJson(ProgressionRule row) => progressionRuleToJson(row);

  @override
  ProgressionRule fromJson(Map<String, dynamic> json) {
    final companion = progressionRuleFromJson(json);
    return ProgressionRule(
      id: companion.id.value,
      userId: companion.userId.value,
      programId: companion.programId.value,
      exerciseId: companion.exerciseId.value,
      type: companion.type.value,
      value: companion.value.value,
      frequency: companion.frequency.value,
      condition: companion.condition.value,
      conditionValue: companion.conditionValue.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(ProgressionRule row) => row.id;

  @override
  Future<ProgressionRule?> getLocal(String id) => store.getProgressionRuleById(id);

  @override
  bool localIsDirty(ProgressionRule local) => local.isDirty;

  @override
  Future<void> upsertRemote(ProgressionRule row) => store.upsertProgressionRuleFromRemote(
    progressionRuleFromJson(toJson(row)),
  );

  @override
  Future<void> markLocalClean(String id) => store.markProgressionRuleClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteProgressionRule(id);
}

class CycleStepSyncAdapter extends _TrainingRowSyncAdapter<CycleStep> {
  CycleStepSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.cycleSteps;

  @override
  Future<List<CycleStep>> loadDirty() => store.getDirtyCycleSteps(userId);

  @override
  Future<List<CycleStep>> loadDirtyTombstones() =>
      store.getDirtyTombstonesCycleSteps(userId);

  @override
  Map<String, dynamic> toJson(CycleStep row) => cycleStepToJson(row);

  @override
  CycleStep fromJson(Map<String, dynamic> json) {
    final companion = cycleStepFromJson(json);
    return CycleStep(
      id: companion.id.value,
      userId: companion.userId.value,
      programId: companion.programId.value,
      orderIndex: companion.orderIndex.value,
      workoutId: companion.workoutId.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(CycleStep row) => row.id;

  @override
  Future<CycleStep?> getLocal(String id) => store.getCycleStepById(id);

  @override
  bool localIsDirty(CycleStep local) => local.isDirty;

  @override
  Future<void> upsertRemote(CycleStep row) =>
      store.upsertCycleStepFromRemote(cycleStepFromJson(toJson(row)));

  @override
  Future<void> markLocalClean(String id) => store.markCycleStepClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteCycleStep(id);
}

class WorkoutExecutionSyncAdapter extends _TrainingRowSyncAdapter<WorkoutExecution> {
  WorkoutExecutionSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.workoutExecutions;

  @override
  Future<List<WorkoutExecution>> loadDirty() =>
      store.getDirtyWorkoutExecutions(userId);

  @override
  Future<List<WorkoutExecution>> loadDirtyTombstones() =>
      store.getDirtyTombstonesWorkoutExecutions(userId);

  @override
  Map<String, dynamic> toJson(WorkoutExecution row) => workoutExecutionToJson(row);

  @override
  WorkoutExecution fromJson(Map<String, dynamic> json) {
    final companion = workoutExecutionFromJson(json);
    return WorkoutExecution(
      id: companion.id.value,
      userId: companion.userId.value,
      workoutId: companion.workoutId.value,
      programId: companion.programId.value,
      startedAt: companion.startedAt.value,
      finishedAt: companion.finishedAt.value,
      workoutNameSnapshot: companion.workoutNameSnapshot.value,
      programNameSnapshot: companion.programNameSnapshot.value,
      contextFallback: companion.contextFallback.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(WorkoutExecution row) => row.id;

  @override
  Future<WorkoutExecution?> getLocal(String id) => store.getWorkoutExecutionById(id);

  @override
  bool localIsDirty(WorkoutExecution local) => local.isDirty;

  @override
  Future<void> upsertRemote(WorkoutExecution row) => store.upsertWorkoutExecutionFromRemote(
    workoutExecutionFromJson(toJson(row)),
  );

  @override
  Future<void> markLocalClean(String id) => store.markWorkoutExecutionClean(id);

  @override
  Future<void> hardDeleteLocal(String id) => store.hardDeleteWorkoutExecution(id);
}

/// Syncs execution sets and their segments (segments have no is_dirty flag).
class ExecutionSetSyncAdapter extends _TrainingRowSyncAdapter<ExecutionSet> {
  ExecutionSetSyncAdapter({
    required super.store,
    required super.remote,
    required super.userId,
  });

  @override
  String get tableName => TrainingSyncTableNames.executionSets;

  @override
  Future<List<ExecutionSet>> loadDirty() => store.getDirtyExecutionSets(userId);

  @override
  Future<List<ExecutionSet>> loadDirtyTombstones() =>
      store.getDirtyTombstonesExecutionSets(userId);

  @override
  Future<void> pushToRemote(List<ExecutionSet> rows) async {
    for (final row in rows) {
      await remote.upsert(table: tableName, row: toJson(row));
      final segments = await store.getSegmentsForSet(row.id);
      await remote.replaceSegmentsForSet(
        setId: row.id,
        segments: segments.map(executionSetSegmentToJson).toList(),
      );
    }
  }

  @override
  Future<void> pushDeletes(List<ExecutionSet> rows) async {
    for (final row in rows) {
      await remote.deleteSegmentsForSet(row.id);
      await remote.deleteRow(
        table: tableName,
        id: row.id,
        userId: userId,
      );
    }
  }

  @override
  Future<void> applyRemoteRows(List<ExecutionSet> rows) async {
    if (rows.isEmpty) return;

    final applicableIds = <String>[];
    for (final row in rows) {
      final local = await getLocal(row.id);
      if (local != null && localIsDirty(local)) continue;
      await store.upsertExecutionSetFromRemote(executionSetFromJson(toJson(row)));
      applicableIds.add(row.id);
    }

    if (applicableIds.isEmpty) return;

    final segmentJson = await remote.fetchSegmentsForSets(applicableIds);
    final segmentsBySet = <String, List<Map<String, dynamic>>>{};
    for (final json in segmentJson) {
      final setId = json['execution_set_id'] as String;
      segmentsBySet.putIfAbsent(setId, () => []).add(json);
    }

    for (final id in applicableIds) {
      final segmentRows = segmentsBySet[id] ?? const [];
      await store.replaceSegmentsForSet(
        id,
        segmentRows.map(executionSetSegmentFromJson).toList(),
      );
    }
  }

  @override
  Map<String, dynamic> toJson(ExecutionSet row) => executionSetToJson(row);

  @override
  ExecutionSet fromJson(Map<String, dynamic> json) {
    final companion = executionSetFromJson(json);
    return ExecutionSet(
      id: companion.id.value,
      userId: companion.userId.value,
      executionId: companion.executionId.value,
      exerciseId: companion.exerciseId.value,
      setNumber: companion.setNumber.value,
      plannedReps: companion.plannedReps.value,
      plannedWeight: companion.plannedWeight.value,
      reps: companion.reps.value,
      weight: companion.weight.value,
      durationSeconds: companion.durationSeconds.value,
      distanceMeters: companion.distanceMeters.value,
      isCompleted: companion.isCompleted.value,
      isWarmup: companion.isWarmup.value,
      rpe: companion.rpe.value,
      bodyWeightSnapshot: companion.bodyWeightSnapshot.value,
      loadModeOverride: companion.loadModeOverride.value,
      leftReps: companion.leftReps.value,
      leftWeight: companion.leftWeight.value,
      rightReps: companion.rightReps.value,
      rightWeight: companion.rightWeight.value,
      isUnilateral: companion.isUnilateral.value,
      updatedAt: companion.updatedAt.value,
      deletedAt: companion.deletedAt.value,
      isDirty: false,
    );
  }

  @override
  String rowId(ExecutionSet row) => row.id;

  @override
  Future<ExecutionSet?> getLocal(String id) => store.getExecutionSetById(id);

  @override
  bool localIsDirty(ExecutionSet local) => local.isDirty;

  @override
  Future<void> upsertRemote(ExecutionSet row) =>
      store.upsertExecutionSetFromRemote(executionSetFromJson(toJson(row)));

  @override
  Future<void> markLocalClean(String id) => store.markExecutionSetClean(id);

  @override
  Future<void> hardDeleteLocal(String id) async {
    await store.deleteSegmentsForSet(id);
    await store.hardDeleteExecutionSet(id);
  }
}
