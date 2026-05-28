import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/execution_context_fallback.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../helpers/exercise_l10n.dart';
import 'exercise_notifier.dart';
import 'program_notifier.dart';
import 'workout_execution_notifier.dart';
import 'workout_notifier.dart';

part 'execution_session_context.g.dart';

/// Resolved display context for a past execution (live-first, snapshot fallback).
class ExecutionSessionContext {
  final WorkoutExecution execution;
  final String? workoutName;
  final String? programName;
  final Map<String, Exercise> liveExercisesById;
  final Map<String, WorkoutExercise> liveWorkoutExercisesById;
  final ExecutionContextFallback? fallback;

  String resolveWorkoutName(AppLocalizations l10n) {
    final name = workoutName;
    if (name != null && name.isNotEmpty) return name;
    return l10n.unknownWorkout;
  }

  const ExecutionSessionContext({
    required this.execution,
    this.workoutName,
    this.programName,
    this.liveExercisesById = const {},
    this.liveWorkoutExercisesById = const {},
    this.fallback,
  });

  String exerciseDisplayName(String exerciseId, AppLocalizations l10n) {
    final live = liveExercisesById[exerciseId];
    if (live != null) {
      return localizedExerciseName(
        live.name,
        isVerified: live.isVerified,
        l10n: l10n,
      );
    }
    final snap = fallback?.forExercise(exerciseId);
    if (snap != null) {
      return localizedExerciseName(
        snap.displayName,
        isVerified: snap.isVerified,
        l10n: l10n,
      );
    }
    return l10n.unknownExerciseId(exerciseId);
  }

  String muscleGroupLabel(String exerciseId, AppLocalizations l10n) {
    final live = liveExercisesById[exerciseId];
    if (live != null) {
      return localizedMuscleGroupName(live.muscleGroup, l10n);
    }
    final snap = fallback?.forExercise(exerciseId);
    if (snap != null) {
      return localizedMuscleGroupName(snap.muscleGroup, l10n);
    }
    return '';
  }

  bool isExerciseIsometric(String exerciseId) =>
      liveExercisesById[exerciseId]?.isIsometric ?? false;

  bool isUnilateralForExercise(String exerciseId) {
    final live = liveWorkoutExercisesById[exerciseId];
    if (live != null) return live.isUnilateral;
    return fallback?.forExercise(exerciseId)?.isUnilateral ?? false;
  }

  WorkoutExercise? workoutExerciseFor(String exerciseId) {
    final live = liveWorkoutExercisesById[exerciseId];
    if (live != null) return live;
    final snap = fallback?.forExercise(exerciseId);
    if (snap == null) return null;
    return WorkoutExercise(
      id: '',
      workoutId: execution.workoutId,
      exerciseId: exerciseId,
      sortOrder: snap.sortOrder,
      sets: 1,
      restSeconds: 0,
      isUnilateral: snap.isUnilateral,
      loadModeOverride: snap.loadModeOverride,
      groupId: snap.groupId,
    );
  }

  Exercise? catalogExerciseFor(String exerciseId) {
    final live = liveExercisesById[exerciseId];
    if (live != null) return live;
    final snap = fallback?.forExercise(exerciseId);
    if (snap == null) return null;
    return Exercise(
      id: exerciseId,
      name: snap.displayName,
      muscleGroup: snap.muscleGroup,
      isVerified: snap.isVerified,
      defaultLoadMode: snap.defaultLoadMode,
      bodyweightLoadFactor: snap.bodyweightLoadFactor,
    );
  }

  LoadMode? workoutLoadModeOverride(String exerciseId) {
    final live = liveWorkoutExercisesById[exerciseId]?.loadModeOverride;
    if (live != null) return live;
    return fallback?.forExercise(exerciseId)?.loadModeOverride;
  }

  int? supersetGroupId(String exerciseId) {
    final live = liveWorkoutExercisesById[exerciseId]?.groupId;
    if (live != null) return live;
    return fallback?.forExercise(exerciseId)?.groupId;
  }
}

@riverpod
Future<ExecutionSessionContext> executionSessionContext(
  Ref ref,
  WorkoutExecution execution,
) async {
  final workoutAsync = ref.watch(workoutByIdProvider(execution.workoutId));
  final workoutName =
      workoutAsync.value?.name ?? execution.workoutNameSnapshot;

  String? programName;
  final programId = execution.programId;
  if (programId != null && programId.isNotEmpty) {
    final programs = ref.watch(programListProvider).value;
    programName =
        programs?.where((p) => p.id == programId).map((p) => p.name).firstOrNull ??
        execution.programNameSnapshot;
  }

  final exerciseList = ref.watch(exerciseListProvider).value ?? const <Exercise>[];
  final liveExercisesById = {for (final e in exerciseList) e.id: e};

  final templateAsync = ref.watch(executionExerciseConfigProvider(execution));
  final liveWorkoutExercisesById = <String, WorkoutExercise>{};
  if (templateAsync.value case final List<WorkoutExercise> wes) {
    for (final we in wes) {
      liveWorkoutExercisesById[we.exerciseId] = we;
    }
  }

  return ExecutionSessionContext(
    execution: execution,
    workoutName: workoutName,
    programName: programName,
    liveExercisesById: liveExercisesById,
    liveWorkoutExercisesById: liveWorkoutExercisesById,
    fallback: execution.contextFallback,
  );
}
