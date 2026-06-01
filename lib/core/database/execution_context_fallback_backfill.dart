import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/training/domain/entities/exercise.dart' as domain_exercise;
import '../../features/training/domain/entities/workout_exercise.dart' as domain_we;
import '../../features/training/domain/enums/exercise_type.dart';
import '../../features/training/domain/enums/load_mode.dart';
import '../../features/training/domain/enums/muscle_group.dart';
import '../../features/training/domain/helpers/build_execution_context_fallback.dart';
import 'app_database.dart';

/// Backfills [context_fallback] for finished sessions where template still exists.
Future<void> backfillExecutionContextFallbackV42(AppDatabase db) async {
  final executions = await db.customSelect('''
      SELECT id, workout_id FROM workout_executions
      WHERE finished_at IS NOT NULL
        AND deleted_at IS NULL
        AND context_fallback IS NULL
    ''').get();
  if (executions.isEmpty) return;

  for (final row in executions) {
    final executionId = row.read<String>('id');
    final workoutId = row.read<String>('workout_id');

    final templateRows = await db.customSelect(
      'SELECT id, exercise_id, sort_order, sets, min_reps, max_reps, is_amrap, '
      'rest_seconds, duration_seconds, group_id, is_unilateral, load_mode_override '
      'FROM workout_exercises '
      'WHERE workout_id = ? AND deleted_at IS NULL '
      'ORDER BY sort_order ASC',
      variables: [Variable<String>(workoutId)],
    ).get();
    if (templateRows.isEmpty) continue;

    final setRows = await db.customSelect(
      'SELECT DISTINCT exercise_id FROM execution_sets '
      'WHERE execution_id = ? AND deleted_at IS NULL',
      variables: [Variable<String>(executionId)],
    ).get();
    final sessionExerciseIds = setRows
        .map((r) => r.read<String>('exercise_id'))
        .toSet();

    final templateExercises = <domain_we.WorkoutExercise>[];
    final allExerciseIds = <String>{...sessionExerciseIds};
    for (final t in templateRows) {
      final exerciseId = t.read<String>('exercise_id');
      allExerciseIds.add(exerciseId);
      templateExercises.add(
        domain_we.WorkoutExercise(
          id: t.read<String>('id'),
          workoutId: workoutId,
          exerciseId: exerciseId,
          sortOrder: t.read<int>('sort_order'),
          sets: t.read<int>('sets'),
          minReps: t.read<int?>('min_reps'),
          maxReps: t.read<int?>('max_reps'),
          isAmrap: t.read<bool>('is_amrap'),
          restSeconds: t.read<int>('rest_seconds'),
          durationSeconds: t.read<int?>('duration_seconds'),
          groupId: t.read<int?>('group_id'),
          isUnilateral: t.read<bool>('is_unilateral'),
          loadModeOverride: _parseLoadMode(t.read<String?>('load_mode_override')),
        ),
      );
    }

    final exercisesById = <String, domain_exercise.Exercise>{};
    for (final exerciseId in allExerciseIds) {
      final exerciseRow = await db.customSelect(
        'SELECT id, name, muscle_group, type, is_verified, default_load_mode, '
        'bodyweight_load_factor, is_isometric '
        'FROM exercises WHERE id = ? AND deleted_at IS NULL',
        variables: [Variable<String>(exerciseId)],
      ).getSingleOrNull();
      if (exerciseRow == null) continue;
      exercisesById[exerciseId] = domain_exercise.Exercise(
        id: exerciseRow.read<String>('id'),
        name: exerciseRow.read<String>('name'),
        muscleGroup: MuscleGroup.values.byName(
          exerciseRow.read<String>('muscle_group'),
        ),
        type: ExerciseType.values.byName(
          exerciseRow.read<String>('type'),
        ),
        isVerified: exerciseRow.read<bool>('is_verified'),
        defaultLoadMode: LoadMode.values.byName(
          exerciseRow.read<String>('default_load_mode'),
        ),
        bodyweightLoadFactor:
            exerciseRow.read<double?>('bodyweight_load_factor'),
        isIsometric: exerciseRow.read<bool>('is_isometric'),
      );
    }

    final fallback = buildExecutionContextFallback(
      templateExercises: templateExercises,
      exercisesById: exercisesById,
      sessionExerciseIds: sessionExerciseIds,
    );
    if (fallback.exercises.isEmpty) continue;

    await db.customUpdate(
      'UPDATE workout_executions SET context_fallback = ? WHERE id = ?',
      variables: [
        Variable<String>(jsonEncode(fallback.toJson())),
        Variable<String>(executionId),
      ],
    );
  }
}

LoadMode? _parseLoadMode(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return LoadMode.values.byName(raw);
}
