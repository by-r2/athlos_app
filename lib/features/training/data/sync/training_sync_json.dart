import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/execution_context_fallback.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/enums/session_kind.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';

DateTime _utcNow() => DateTime.now().toUtc();

DateTime? parseUtcDateTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

String? isoOrNull(DateTime? value) => value?.toUtc().toIso8601String();

Map<String, dynamic> exerciseToJson(Exercise row, {required String userId}) =>
    <String, dynamic>{
      'id': row.id,
      'created_by': userId,
      'is_verified': false,
      'name': row.name,
      'muscle_group': row.muscleGroup.name,
      'type': row.type.name,
      'movement_pattern': row.movementPattern?.name,
      'description': row.description,
      'default_load_mode': row.defaultLoadMode.name,
      'bodyweight_load_factor': row.bodyweightLoadFactor,
      'is_isometric': row.isIsometric,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': isoOrNull(row.deletedAt),
    };

ExercisesCompanion exerciseFromJson(Map<String, dynamic> json) =>
    ExercisesCompanion(
      id: Value(json['id'] as String),
      createdBy: Value(json['created_by'] as String?),
      isVerified: Value(json['is_verified'] as bool? ?? false),
      name: Value(json['name'] as String),
      muscleGroup: Value(
        MuscleGroup.values.byName(json['muscle_group'] as String),
      ),
      type: Value(ExerciseType.values.byName(json['type'] as String? ?? 'strength')),
      movementPattern: Value(
        json['movement_pattern'] == null
            ? null
            : MovementPattern.values.byName(json['movement_pattern'] as String),
      ),
      description: Value(json['description'] as String?),
      defaultLoadMode: Value(
        LoadMode.values.byName(
          json['default_load_mode'] as String? ?? LoadMode.weighted.name,
        ),
      ),
      bodyweightLoadFactor: Value(_asDouble(json['bodyweight_load_factor'])),
      isIsometric: Value(json['is_isometric'] as bool? ?? false),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> workoutToJson(Workout row) => <String, dynamic>{
  'id': row.id,
  'user_id': row.userId,
  'name': row.name,
  'description': row.description,
  'sort_order': row.sortOrder,
  'is_archived': row.isArchived,
  'is_draft': row.isDraft,
  'created_at': row.createdAt.toUtc().toIso8601String(),
  'updated_at': row.updatedAt.toUtc().toIso8601String(),
  'deleted_at': isoOrNull(row.deletedAt),
};

WorkoutsCompanion workoutFromJson(Map<String, dynamic> json) =>
    WorkoutsCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      name: Value(json['name'] as String),
      description: Value(json['description'] as String?),
      sortOrder: Value(json['sort_order'] as int?),
      isArchived: Value(json['is_archived'] as bool? ?? false),
      isDraft: Value(json['is_draft'] as bool? ?? false),
      createdAt: Value(parseUtcDateTime(json['created_at']) ?? _utcNow()),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> workoutExerciseToJson(WorkoutExercise row) =>
    <String, dynamic>{
      'id': row.id,
      'user_id': row.userId,
      'workout_id': row.workoutId,
      'exercise_id': row.exerciseId,
      'sort_order': row.sortOrder,
      'sets': row.sets,
      'min_reps': row.minReps,
      'max_reps': row.maxReps,
      'is_amrap': row.isAmrap,
      'rest_seconds': row.restSeconds,
      'duration_seconds': row.durationSeconds,
      'group_id': row.groupId,
      'is_unilateral': row.isUnilateral,
      'load_mode_override': row.loadModeOverride?.name,
      'notes': row.notes,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': isoOrNull(row.deletedAt),
    };

WorkoutExercisesCompanion workoutExerciseFromJson(Map<String, dynamic> json) =>
    WorkoutExercisesCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      workoutId: Value(json['workout_id'] as String),
      exerciseId: Value(json['exercise_id'] as String),
      sortOrder: Value(json['sort_order'] as int),
      sets: Value(json['sets'] as int? ?? 1),
      minReps: Value(json['min_reps'] as int?),
      maxReps: Value(json['max_reps'] as int?),
      isAmrap: Value(json['is_amrap'] as bool? ?? false),
      restSeconds: Value(json['rest_seconds'] as int? ?? 60),
      durationSeconds: Value(json['duration_seconds'] as int?),
      groupId: Value(json['group_id'] as int?),
      isUnilateral: Value(json['is_unilateral'] as bool? ?? false),
      loadModeOverride: Value(
        json['load_mode_override'] == null
            ? null
            : LoadMode.values.byName(json['load_mode_override'] as String),
      ),
      notes: Value(json['notes'] as String?),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> programToJson(Program row) => <String, dynamic>{
  'id': row.id,
  'user_id': row.userId,
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
  'archived_at': isoOrNull(row.archivedAt),
  'updated_at': row.updatedAt.toUtc().toIso8601String(),
  'deleted_at': isoOrNull(row.deletedAt),
};

ProgramsCompanion programFromJson(Map<String, dynamic> json) =>
    ProgramsCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      name: Value(json['name'] as String),
      focus: Value(json['focus'] as String),
      durationMode: Value(json['duration_mode'] as String),
      durationValue: Value(json['duration_value'] as int),
      defaultRestSeconds: Value(json['default_rest_seconds'] as int?),
      isActive: Value(json['is_active'] as bool? ?? false),
      isInDeload: Value(json['is_in_deload'] as bool? ?? false),
      deloadFrequency: Value(json['deload_frequency'] as int?),
      deloadStrategy: Value(json['deload_strategy'] as String?),
      deloadVolumeMultiplier: Value(_asDouble(json['deload_volume_multiplier'])),
      deloadIntensityMultiplier: Value(_asDouble(json['deload_intensity_multiplier'])),
      createdAt: Value(parseUtcDateTime(json['created_at']) ?? _utcNow()),
      archivedAt: Value(parseUtcDateTime(json['archived_at'])),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> progressionRuleToJson(ProgressionRule row) =>
    <String, dynamic>{
      'id': row.id,
      'user_id': row.userId,
      'program_id': row.programId,
      'exercise_id': row.exerciseId,
      'type': row.type,
      'value': row.value,
      'frequency': row.frequency,
      'condition': row.condition,
      'condition_value': row.conditionValue,
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': isoOrNull(row.deletedAt),
    };

ProgressionRulesCompanion progressionRuleFromJson(Map<String, dynamic> json) =>
    ProgressionRulesCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      programId: Value(json['program_id'] as String),
      exerciseId: Value(json['exercise_id'] as String),
      type: Value(json['type'] as String),
      value: Value(_asDouble(json['value']) ?? 0),
      frequency: Value(json['frequency'] as String),
      condition: Value(json['condition'] as String?),
      conditionValue: Value(_asDouble(json['condition_value'])),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> cycleStepToJson(CycleStep row) => <String, dynamic>{
  'id': row.id,
  'user_id': row.userId,
  'program_id': row.programId,
  'order_index': row.orderIndex,
  'workout_id': row.workoutId,
  'updated_at': row.updatedAt.toUtc().toIso8601String(),
  'deleted_at': isoOrNull(row.deletedAt),
};

CycleStepsCompanion cycleStepFromJson(Map<String, dynamic> json) =>
    CycleStepsCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      programId: Value(json['program_id'] as String),
      orderIndex: Value(json['order_index'] as int),
      workoutId: Value(json['workout_id'] as String),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> workoutExecutionToJson(WorkoutExecution row) =>
    <String, dynamic>{
      'id': row.id,
      'user_id': row.userId,
      'workout_id': row.workoutId,
      'program_id': row.programId,
      'session_kind': row.sessionKind.name,
      'started_at': row.startedAt.toUtc().toIso8601String(),
      'finished_at': isoOrNull(row.finishedAt),
      'workout_name_snapshot': row.workoutNameSnapshot,
      'program_name_snapshot': row.programNameSnapshot,
      'context_fallback': row.contextFallback?.toJson(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'deleted_at': isoOrNull(row.deletedAt),
    };

WorkoutExecutionsCompanion workoutExecutionFromJson(Map<String, dynamic> json) =>
    WorkoutExecutionsCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      workoutId: Value(json['workout_id'] as String),
      programId: Value(json['program_id'] as String),
      sessionKind: Value(
        SessionKind.values.byName(
          json['session_kind'] as String? ?? SessionKind.planned.name,
        ),
      ),
      startedAt: Value(parseUtcDateTime(json['started_at']) ?? _utcNow()),
      finishedAt: Value(parseUtcDateTime(json['finished_at'])),
      workoutNameSnapshot: Value(json['workout_name_snapshot'] as String?),
      programNameSnapshot: Value(json['program_name_snapshot'] as String?),
      contextFallback: Value(_contextFallbackFromJson(json['context_fallback'])),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

ExecutionContextFallback? _contextFallbackFromJson(Object? raw) {
  if (raw == null) return null;
  if (raw is String && raw.isEmpty) return null;
  if (raw is String) {
    return ExecutionContextFallback.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
  if (raw is Map<String, dynamic>) {
    return ExecutionContextFallback.fromJson(raw);
  }
  if (raw is Map) {
    return ExecutionContextFallback.fromJson(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return null;
}

Map<String, dynamic> executionSetToJson(ExecutionSet row) => <String, dynamic>{
  'id': row.id,
  'user_id': row.userId,
  'execution_id': row.executionId,
  'exercise_id': row.exerciseId,
  'workout_exercise_id': row.workoutExerciseId,
  'set_number': row.setNumber,
  'planned_reps': row.plannedReps,
  'planned_weight': row.plannedWeight,
  'reps': row.reps,
  'weight': row.weight,
  'duration_seconds': row.durationSeconds,
  'distance_meters': row.distanceMeters,
  'is_completed': row.isCompleted,
  'is_warmup': row.isWarmup,
  'rpe': row.rpe,
  'body_weight_snapshot': row.bodyWeightSnapshot,
  'load_mode_override': row.loadModeOverride?.name,
  'left_reps': row.leftReps,
  'left_weight': row.leftWeight,
  'right_reps': row.rightReps,
  'right_weight': row.rightWeight,
  'is_unilateral': row.isUnilateral,
  'updated_at': row.updatedAt.toUtc().toIso8601String(),
  'deleted_at': isoOrNull(row.deletedAt),
};

ExecutionSetsCompanion executionSetFromJson(Map<String, dynamic> json) =>
    ExecutionSetsCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      executionId: Value(json['execution_id'] as String),
      exerciseId: Value(json['exercise_id'] as String),
      workoutExerciseId: Value(json['workout_exercise_id'] as String?),
      setNumber: Value(json['set_number'] as int),
      plannedReps: Value(json['planned_reps'] as int?),
      plannedWeight: Value(_asDouble(json['planned_weight'])),
      reps: Value(json['reps'] as int?),
      weight: Value(_asDouble(json['weight'])),
      durationSeconds: Value(json['duration_seconds'] as int?),
      distanceMeters: Value(_asDouble(json['distance_meters'])),
      isCompleted: Value(json['is_completed'] as bool? ?? false),
      isWarmup: Value(json['is_warmup'] as bool? ?? false),
      rpe: Value(json['rpe'] as int?),
      bodyWeightSnapshot: Value(_asDouble(json['body_weight_snapshot'])),
      loadModeOverride: Value(
        json['load_mode_override'] == null
            ? null
            : LoadMode.values.byName(json['load_mode_override'] as String),
      ),
      leftReps: Value(json['left_reps'] as int?),
      leftWeight: Value(_asDouble(json['left_weight'])),
      rightReps: Value(json['right_reps'] as int?),
      rightWeight: Value(_asDouble(json['right_weight'])),
      isUnilateral: Value(json['is_unilateral'] as bool?),
      updatedAt: Value(parseUtcDateTime(json['updated_at']) ?? _utcNow()),
      deletedAt: Value(parseUtcDateTime(json['deleted_at'])),
      isDirty: const Value(false),
    );

Map<String, dynamic> executionSetSegmentToJson(ExecutionSetSegment row) =>
    <String, dynamic>{
      'id': row.id,
      'execution_set_id': row.executionSetId,
      'segment_order': row.segmentOrder,
      'reps': row.reps,
      'weight': row.weight,
    };

ExecutionSetSegmentsCompanion executionSetSegmentFromJson(
  Map<String, dynamic> json,
) =>
    ExecutionSetSegmentsCompanion(
      id: Value(json['id'] as String),
      executionSetId: Value(json['execution_set_id'] as String),
      segmentOrder: Value(json['segment_order'] as int),
      reps: Value(json['reps'] as int),
      weight: Value(_asDouble(json['weight'])),
    );

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return null;
}
