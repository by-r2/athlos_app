import 'dart:convert';
import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/progression_rule.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/enums/progression_condition.dart';
import '../../domain/enums/progression_type.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import 'active_execution_state.dart';
export 'active_execution_state.dart';
import 'program_notifier.dart';
import 'workout_execution_notifier.dart';
import 'workout_notifier.dart';

import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import 'recalculate_training_streaks.dart';

part 'active_execution_notifier.g.dart';

@Riverpod(keepAlive: true)
class ActiveExecution extends _$ActiveExecution {
  @override
  ActiveExecutionState? build() => null;

  /// Start a new execution, creating the DB record and pre-populating sets
  /// from the workout template. Applies deload and progression adjustments.
  /// Snapshots the exercise configuration as JSON for robust history.
  Future<void> startExecution(
    int workoutId,
    List<WorkoutExercise> exercises, {
    required int programId,
    DeloadConfig? deloadConfig,
    List<ProgressionRule> progressionRules = const [],
    int defaultRestSeconds = 0,
    Set<int> isometricExerciseIds = const {},
  }) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final snapshot = _buildExerciseConfigSnapshot(exercises);
    final result = await repo.start(
      workoutId,
      programId: programId,
      exerciseConfigSnapshot: snapshot,
    );
    final executionId = result.getOrThrow();

    final exerciseIds = exercises.map((e) => e.exerciseId).toList();
    final weightsResult =
        await repo.getLastWeightsForExercises(exerciseIds);
    final lastWeights = weightsResult.getOrThrow();

    final reduceVol = deloadConfig != null &&
        (deloadConfig.strategy == DeloadStrategy.reduceVolume ||
            deloadConfig.strategy == DeloadStrategy.reduceBoth);
    final reduceInt = deloadConfig != null &&
        (deloadConfig.strategy == DeloadStrategy.reduceIntensity ||
            deloadConfig.strategy == DeloadStrategy.reduceBoth);

    final rulesByExercise = {
      for (final r in progressionRules) r.exerciseId: r,
    };

    final exerciseSets = <int, List<SetEntry>>{};
    for (final ex in exercises) {
      var lastWeight = lastWeights[ex.exerciseId];
      final isCardio = ex.duration != null &&
          !isometricExerciseIds.contains(ex.exerciseId);
      final isIsometric = isometricExerciseIds.contains(ex.exerciseId);
      final usesDuration = isCardio || isIsometric;
      var repsTarget = usesDuration ? null : ex.targetReps;
      var sets = ex.sets;

      if (deloadConfig == null) {
        final rule = rulesByExercise[ex.exerciseId];
        if (rule != null && lastWeight != null) {
          final shouldApply =
              await _evaluateCondition(repo, rule, ex);
          if (shouldApply) {
            switch (rule.type) {
              case ProgressionType.incrementWeight:
                lastWeight = lastWeight + rule.value;
              case ProgressionType.incrementReps:
                if (repsTarget != null) {
                  repsTarget = repsTarget + rule.value.toInt();
                }
              case ProgressionType.incrementSets:
                sets = sets + rule.value.toInt();
            }
          }
        }
      }

      final effectiveSets = reduceVol
          ? math.max(1, (sets * deloadConfig.volumeMultiplier).ceil())
          : sets;

      final effectiveWeight = (reduceInt && lastWeight != null)
          ? lastWeight * deloadConfig.intensityMultiplier
          : lastWeight;

      exerciseSets[ex.exerciseId] = List.generate(
        effectiveSets,
        (i) => SetEntry(
          setNumber: i + 1,
          plannedReps: repsTarget,
          plannedWeight: isCardio ? null : effectiveWeight,
          plannedDuration: usesDuration ? ex.duration : null,
          reps: repsTarget,
          duration: usesDuration ? ex.duration : null,
        ),
      );
    }

    state = ActiveExecutionState(
      executionId: executionId,
      workoutId: workoutId,
      exerciseSets: exerciseSets,
      exercises: exercises,
      isDeload: deloadConfig != null,
      defaultRestSeconds: defaultRestSeconds,
    );
  }

  Future<bool> _evaluateCondition(
    WorkoutExecutionRepository repo,
    ProgressionRule rule,
    WorkoutExercise exercise,
  ) async {
    if (rule.condition == null) return true;

    final setsResult =
        await repo.getLastCompletedSetsForExercise(rule.exerciseId);
    final lastSets =
        setsResult.isSuccess ? setsResult.getOrThrow() : <ExecutionSet>[];
    if (lastSets.isEmpty) return false;

    switch (rule.condition!) {
      case ProgressionCondition.hitsMaxReps:
        final maxReps = exercise.maxReps;
        if (maxReps == null) return false;
        return lastSets.every((s) => (s.reps ?? 0) >= maxReps);

      case ProgressionCondition.completesAllSets:
        return lastSets.length >= exercise.sets;

      case ProgressionCondition.rpeBelow:
        final threshold = rule.conditionValue ?? 8;
        final rpeSets =
            lastSets.where((s) => s.rpe != null).toList();
        if (rpeSets.isEmpty) return false;
        final avgRpe =
            rpeSets.map((s) => s.rpe!).reduce((a, b) => a + b) /
                rpeSets.length;
        return avgRpe < threshold;
    }
  }

  /// Update local set values (weight/reps or duration/distance) without
  /// persisting yet.
  void updateSet(
    int exerciseId,
    int setNumber, {
    int? reps,
    double? weight,
    int? duration,
    double? distance,
  }) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            reps: reps != null ? () => reps : null,
            weight: weight != null ? () => weight : null,
            duration: duration != null ? () => duration : null,
            distance: distance != null ? () => distance : null,
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Add a drop segment to a set (in-memory only, persisted on complete).
  void addDropSegment(int exerciseId, int setNumber,
      {required int reps, double? weight}) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            segments: [
              ...s.segments,
              SegmentEntry(reps: reps, weight: weight),
            ],
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Remove a drop segment by index.
  /// Overrides how load is interpreted for one set (persisted when completed).
  void updateSetLoadModeOverride(
    int exerciseId,
    int setNumber,
    LoadMode? loadModeOverride,
  ) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(loadModeOverride: () => loadModeOverride)
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  void removeDropSegment(int exerciseId, int setNumber, int segmentIndex) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            segments: [
              for (var i = 0; i < s.segments.length; i++)
                if (i != segmentIndex) s.segments[i],
            ],
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );
  }

  /// Mark a set as completed and persist it to the database.
  /// Returns the rest time (seconds) for the exercise so the caller can start
  /// the timer.
  /// Returns (restSeconds, suggestedNextWeight) — suggestedNextWeight is non-null
  /// when all working sets hit maxReps and no progression rule is defined.
  Future<(int, double?)> completeSet(
    int exerciseId,
    int setNumber, {
    int? reps,
    double? weight,
    int? duration,
    double? distance,
    int? rpe,
    List<SegmentEntry>? segments,
    int? leftReps,
    double? leftWeight,
    int? rightReps,
    double? rightWeight,
    bool isUnilateral = false,
  }) async {
    final current = state;
    if (current == null) return (0, null);

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return (0, null);

    final entry = sets.firstWhere((s) => s.setNumber == setNumber);
    final effectiveSegments = segments ?? entry.segments;
    final bodyWeightSnapshot = await ref.read(latestBodyWeightProvider.future);

    final executionSet = ExecutionSet(
      id: entry.id ?? 0,
      executionId: current.executionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      plannedReps: entry.plannedReps,
      plannedWeight: entry.plannedWeight,
      reps: reps,
      weight: weight,
      duration: duration,
      distance: distance,
      isCompleted: true,
      isWarmup: false,
      rpe: rpe,
      bodyWeightSnapshot: bodyWeightSnapshot,
      loadModeOverride: entry.loadModeOverride,
      leftReps: leftReps,
      leftWeight: leftWeight,
      rightReps: rightReps,
      rightWeight: rightWeight,
      isUnilateral: isUnilateral,
    );

    final domainSegments = effectiveSegments
        .map((s) => ExecutionSetSegment(
              id: 0,
              executionSetId: 0,
              segmentOrder: 0,
              reps: s.reps,
              weight: s.weight,
            ))
        .toList();

    final useCase = ref.read(completeSetUseCaseProvider);
    final result = await useCase(
      CompleteSetParams(set: executionSet, segments: domainSegments),
    );
    final setId = result.getOrThrow();

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(
            id: setId,
            reps: reps != null ? () => reps : null,
            weight: () => weight,
            duration: duration != null ? () => duration : null,
            distance: distance != null ? () => distance : null,
            isCompleted: true,
            isWarmup: false,
            rpe: () => rpe,
            leftReps: () => leftReps,
            leftWeight: () => leftWeight,
            rightReps: () => rightReps,
            rightWeight: () => rightWeight,
            segments: effectiveSegments,
          )
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, exerciseId: updated},
    );

    final exercise = current.exercises.firstWhere(
      (e) => e.exerciseId == exerciseId,
    );
    final rest = exercise.rest > 0 ? exercise.rest : current.defaultRestSeconds;

    double? suggestedWeight;
    final maxReps = exercise.maxReps;
    if (maxReps != null && maxReps > 0) {
      final latestSets = state!.exerciseSets[exerciseId] ?? [];
      final workingSets = latestSets.where((s) => s.isCompleted);
      final allComplete = workingSets.every((s) => s.isCompleted);
      final allHitMax =
          workingSets.every((s) => s.reps != null && s.reps! >= maxReps);
      if (allComplete && allHitMax && workingSets.isNotEmpty) {
        final currentWeight = workingSets
            .map((s) => s.weight ?? 0.0)
            .reduce((a, b) => a > b ? a : b);
        if (currentWeight > 0) {
          suggestedWeight =
              (currentWeight * 1.025 * 4).roundToDouble() / 4;
        }
      }
    }

    return (rest, suggestedWeight);
  }

  /// Finish the active execution, persisting finishedAt.
  Future<void> finishExecution() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(isFinishing: true);

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.finish(current.executionId);
    result.getOrThrow();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);
    ref.invalidate(programSessionCountProvider);

    await ref.read(recalculateTrainingStreaksProvider.notifier).run();
    ref.invalidate(profileProvider);

    state = null;
  }

  /// Resume a previously started but unfinished execution.
  /// Reconstructs in-memory state from the DB.
  Future<void> resumeExecution(
    int executionId,
    int workoutId,
    List<WorkoutExercise> exercises, {
    required int programId,
    int defaultRestSeconds = 0,
    Set<int> isometricExerciseIds = const {},
  }) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);

    final setsResult = await repo.getSets(executionId);
    final dbSets = setsResult.getOrThrow();

    final exerciseSets = <int, List<SetEntry>>{};
    for (final ex in exercises) {
      final completed = dbSets
          .where((s) => s.exerciseId == ex.exerciseId)
          .toList();
      final maxCompleted = completed.isEmpty
          ? 0
          : completed.map((s) => s.setNumber).reduce((a, b) => a > b ? a : b);
      final totalSets = ex.sets < maxCompleted ? maxCompleted : ex.sets;

      exerciseSets[ex.exerciseId] = List.generate(totalSets, (i) {
        final setNum = i + 1;
        final existing = completed.where((s) => s.setNumber == setNum).firstOrNull;
        if (existing != null) {
          final isIso = isometricExerciseIds.contains(ex.exerciseId);
          final usesDur = (ex.duration != null) || isIso;
          return SetEntry(
            id: existing.id,
            setNumber: setNum,
            plannedReps: existing.plannedReps,
            plannedWeight: existing.plannedWeight,
            plannedDuration: usesDur ? ex.duration : null,
            reps: existing.reps,
            weight: existing.weight,
            duration: existing.duration,
            distance: existing.distance,
            isCompleted: existing.isCompleted,
            isWarmup: existing.isWarmup,
            rpe: existing.rpe,
            loadModeOverride: existing.loadModeOverride,
            leftReps: existing.leftReps,
            leftWeight: existing.leftWeight,
            rightReps: existing.rightReps,
            rightWeight: existing.rightWeight,
          );
        }
        final isIso = isometricExerciseIds.contains(ex.exerciseId);
        final isCardio = ex.duration != null && !isIso;
        final usesDuration = isCardio || isIso;
        return SetEntry(
          setNumber: setNum,
          plannedReps: usesDuration ? null : ex.targetReps,
          plannedDuration: usesDuration ? ex.duration : null,
          reps: usesDuration ? null : ex.targetReps,
          duration: usesDuration ? ex.duration : null,
        );
      });
    }

    state = ActiveExecutionState(
      executionId: executionId,
      workoutId: workoutId,
      exerciseSets: exerciseSets,
      exercises: exercises,
      defaultRestSeconds: defaultRestSeconds,
    );
  }

  /// Cancel the active execution, deleting the DB record.
  Future<void> cancelExecution() async {
    final current = state;
    if (current == null) return;

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.delete(current.executionId);
    result.getOrThrow();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);

    state = null;
  }

  String _buildExerciseConfigSnapshot(List<WorkoutExercise> exercises) {
    final list = exercises.map((e) => {
      'exerciseId': e.exerciseId,
      'sets': e.sets,
      'minReps': e.minReps,
      'maxReps': e.maxReps,
      'rest': e.rest,
      'duration': e.duration,
      'order': e.order,
      'groupId': e.groupId,
      'isAmrap': e.isAmrap,
      'isUnilateral': e.isUnilateral,
      if (e.notes != null) 'notes': e.notes,
    }).toList();
    return jsonEncode(list);
  }
}
