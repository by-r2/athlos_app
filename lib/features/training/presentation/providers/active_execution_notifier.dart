import 'dart:async';
import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/progression_rule.dart';
import '../../domain/helpers/load_progression_rules.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/enums/progression_condition.dart';
import '../../domain/enums/progression_type.dart';
import '../../domain/usecases/complete_set_use_case.dart';
import '../../domain/usecases/finish_workout_execution.dart';
import 'active_execution_state.dart';
export 'active_execution_state.dart';
import 'program_notifier.dart';
import 'workout_execution_notifier.dart';
import 'workout_notifier.dart';

import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../helpers/rep_performance.dart';
import 'recalculate_training_streaks.dart';
import 'training_analytics_provider.dart';

part 'active_execution_notifier.g.dart';

@Riverpod(keepAlive: true)
class ActiveExecution extends _$ActiveExecution {
  @override
  ActiveExecutionState? build() {
    ref.onDispose(() {
      for (final t in _draftPersistTimers.values) {
        t.cancel();
      }
      _draftPersistTimers.clear();
    });
    return null;
  }

  static const Duration _draftPersistDebounce = Duration(milliseconds: 600);
  final Map<String, Timer> _draftPersistTimers = {};

  /// Start a new execution, creating the DB record and pre-populating sets
  /// from the workout template. Applies deload and progression adjustments.
  Future<void> startExecution(
    String workoutId,
    List<WorkoutExercise> exercises, {
    required String programId,
    DeloadConfig? deloadConfig,
    List<ProgressionRule> progressionRules = const [],
    int defaultRestSeconds = 0,
    Set<String> isometricExerciseIds = const {},
  }) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final result = await repo.start(
      workoutId,
      programId: programId,
    );
    final executionId = result.getOrThrow();

    final exerciseIds = exercises.map((e) => e.exerciseId).toList();
    final weightsResult = await repo.getLastWeightsForExercises(exerciseIds);
    final lastWeights = weightsResult.getOrThrow();

    final reduceVol =
        deloadConfig != null &&
        (deloadConfig.strategy == DeloadStrategy.reduceVolume ||
            deloadConfig.strategy == DeloadStrategy.reduceBoth);
    final reduceInt =
        deloadConfig != null &&
        (deloadConfig.strategy == DeloadStrategy.reduceIntensity ||
            deloadConfig.strategy == DeloadStrategy.reduceBoth);

    final rulesByExercise = {for (final r in progressionRules) r.exerciseId: r};

    final exerciseSets = <String, List<SetEntry>>{};
    for (final ex in exercises) {
      var lastWeight = lastWeights[ex.exerciseId];
      final isCardio =
          ex.durationSeconds != null && !isometricExerciseIds.contains(ex.exerciseId);
      final isIsometric = isometricExerciseIds.contains(ex.exerciseId);
      final usesDuration = isCardio || isIsometric;
      var repsTarget = usesDuration ? null : ex.targetReps;
      var sets = ex.sets;

      if (deloadConfig == null) {
        final rule = rulesByExercise[ex.exerciseId];
        if (rule != null && lastWeight != null) {
          final shouldApply = await _evaluateCondition(repo, rule, ex);
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
          plannedDuration: usesDuration ? ex.durationSeconds : null,
          reps: repsTarget,
          duration: usesDuration ? ex.durationSeconds : null,
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

    final setsResult = await repo.getLastCompletedSetsForExercise(
      rule.exerciseId,
    );
    final lastSets = setsResult.isSuccess
        ? setsResult.getOrThrow()
        : <ExecutionSet>[];
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
        final rpeSets = lastSets.where((s) => s.rpe != null).toList();
        if (rpeSets.isEmpty) return false;
        final avgRpe =
            rpeSets.map((s) => s.rpe!).reduce((a, b) => a + b) / rpeSets.length;
        return avgRpe < threshold;
    }
  }

  /// Update local set values (weight/reps or duration/distance) without
  /// persisting yet.
  void updateSet(
    String exerciseId,
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

    _scheduleDraftPersist(exerciseId: exerciseId, setNumber: setNumber);
  }

  /// Add a drop segment to a set (in-memory only, persisted on complete).
  void addDropSegment(
    String exerciseId,
    int setNumber, {
    required int reps,
    double? weight,
  }) {
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

    _scheduleDraftPersist(exerciseId: exerciseId, setNumber: setNumber);
  }

  /// Remove a drop segment by index.
  /// Overrides how load is interpreted for one set (persisted when completed).
  void updateSetLoadModeOverride(
    String exerciseId,
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

  void removeDropSegment(String exerciseId, int setNumber, int segmentIndex) {
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

    _scheduleDraftPersist(exerciseId: exerciseId, setNumber: setNumber);
  }

  void _scheduleDraftPersist({
    required String exerciseId,
    required int setNumber,
  }) {
    final current = state;
    if (current == null) return;

    final key = '${current.executionId}:$exerciseId:$setNumber';
    _draftPersistTimers.remove(key)?.cancel();
    _draftPersistTimers[key] = Timer(
      _draftPersistDebounce,
      () => unawaited(
        _persistDraftSet(exerciseId: exerciseId, setNumber: setNumber),
      ),
    );
  }

  Future<void> _persistDraftSet({
    required String exerciseId,
    required int setNumber,
  }) async {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[exerciseId];
    if (sets == null) return;

    final entry = sets.where((s) => s.setNumber == setNumber).firstOrNull;
    if (entry == null) return;

    // Avoid writing empty drafts (keeps DB cleaner and reduces IO).
    final hasAnyValue =
        entry.reps != null ||
        entry.weight != null ||
        entry.duration != null ||
        entry.distance != null ||
        entry.rpe != null ||
        entry.leftReps != null ||
        entry.leftWeight != null ||
        entry.rightReps != null ||
        entry.rightWeight != null ||
        entry.loadModeOverride != null ||
        entry.segments.isNotEmpty;
    if (!hasAnyValue) return;

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final set = ExecutionSet(
      id: entry.id ?? '',
      executionId: current.executionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      plannedReps: entry.plannedReps,
      plannedWeight: entry.plannedWeight,
      reps: entry.reps,
      weight: entry.weight,
      durationSeconds: entry.duration,
      distanceMeters: entry.distance,
      isCompleted: entry.isCompleted,
      isWarmup: entry.isWarmup,
      rpe: entry.rpe,
      bodyWeightSnapshot: null,
      loadModeOverride: entry.loadModeOverride,
      leftReps: entry.leftReps,
      leftWeight: entry.leftWeight,
      rightReps: entry.rightReps,
      rightWeight: entry.rightWeight,
      isUnilateral: (entry.leftReps != null ||
          entry.leftWeight != null ||
          entry.rightReps != null ||
          entry.rightWeight != null),
    );

    final String persistedId;
    if ((entry.id ?? '').isEmpty) {
      persistedId = (await repo.logSet(set)).getOrThrow();
    } else {
      await repo.updateSet(set).then((r) => r.getOrThrow());
      persistedId = entry.id!;
    }

    if (entry.segments.length > 1) {
      final segments = entry.segments
          .asMap()
          .entries
          .map(
            (e) => ExecutionSetSegment(
              id: '',
              executionSetId: persistedId,
              segmentOrder: e.key + 1,
              reps: e.value.reps,
              weight: e.value.weight,
            ),
          )
          .toList();
      await repo.saveSegments(persistedId, segments).then((r) => r.getOrThrow());
    }

    // Ensure the in-memory entry is linked to the persisted row.
    final latest = state;
    if (latest == null) return;
    final latestSets = latest.exerciseSets[exerciseId];
    if (latestSets == null) return;
    final linked = [
      for (final s in latestSets)
        if (s.setNumber == setNumber) s.copyWith(id: persistedId) else s,
    ];
    state = latest.copyWith(
      exerciseSets: {...latest.exerciseSets, exerciseId: linked},
    );
  }

  /// Mark a set as completed and persist it to the database.
  /// Returns the rest time (seconds) for the exercise so the caller can start
  /// the timer.
  /// Returns (restSeconds, suggestedNextWeight) — suggestedNextWeight is non-null
  /// only when **every planned work set** (excluding warm-ups) hit at least `maxReps`.
  Future<(int, double?)> completeSet(
    String exerciseId,
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
      id: entry.id ?? '',
      executionId: current.executionId,
      exerciseId: exerciseId,
      setNumber: setNumber,
      plannedReps: entry.plannedReps,
      plannedWeight: entry.plannedWeight,
      reps: reps,
      weight: weight,
      durationSeconds: duration,
      distanceMeters: distance,
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
        .map(
          (s) => ExecutionSetSegment(
            id: '',
            executionSetId: '',
            segmentOrder: 0,
            reps: s.reps,
            weight: s.weight,
          ),
        )
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
    final rest = exercise.restSeconds > 0 ? exercise.restSeconds : current.defaultRestSeconds;

    double? suggestedWeight;
    final maxReps = exercise.maxReps;
    final latestExerciseSets = state!.exerciseSets[exerciseId] ?? [];
    if (maxReps != null &&
        maxReps > 0 &&
        workSetsQualifyForSuggestedWeightIncrease(
          latestSetsForExercise: latestExerciseSets,
          maxReps: maxReps,
        )) {
      final catalogResult = await ref
          .read(exerciseRepositoryProvider)
          .getById(exerciseId);
      final fraction = switch (catalogResult) {
        Success(:final value) when value != null =>
          progressionLoadIncreaseFraction(value),
        _ => 0.025,
      };
      suggestedWeight = nextRoundedSuggestedWorkingWeightKg(
        latestSetsForExercise: latestExerciseSets,
        loadIncreaseFraction: fraction,
      );
    }

    return (rest, suggestedWeight);
  }

  /// Finish the active execution, persisting finishedAt.
  Future<void> finishExecution() async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(isFinishing: true);

    final programId = ref.read(activeProgramProvider).value?.id;
    final finishUseCase = ref.read(finishWorkoutExecutionProvider);
    final result = await finishUseCase(
      FinishWorkoutExecutionParams(
        executionId: current.executionId,
        workoutId: current.workoutId,
        programId: programId,
        templateExercises: current.exercises,
      ),
    );
    result.getOrThrow();

    state = null;
    await ref.read(userDataSyncCoordinatorProvider).syncWorkoutSessionToCloud();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);
    ref.invalidate(programSessionCountProvider);

    await ref.read(recalculateTrainingStreaksProvider.notifier).run();
    ref.invalidate(profileProvider);
    ref.invalidate(finishedSessionCountProvider);
    ref.invalidate(trainingHomeAnalyticsProvider);
  }

  /// Resume a previously started but unfinished execution.
  /// Reconstructs in-memory state from the DB.
  Future<void> resumeExecution(
    String executionId,
    String workoutId,
    List<WorkoutExercise> exercises, {
    String? programId,
    int defaultRestSeconds = 0,
    Set<String> isometricExerciseIds = const {},
  }) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);

    final setsResult = await repo.getSets(executionId);
    final dbSets = setsResult.getOrThrow();

    final exerciseIds = exercises.map((e) => e.exerciseId).toList();
    final lastWeights = (await repo.getLastWeightsForExercises(exerciseIds))
        .getOrThrow();

    final exerciseSets = <String, List<SetEntry>>{};
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
        final existing = completed
            .where((s) => s.setNumber == setNum)
            .firstOrNull;
        if (existing != null) {
          final isIso = isometricExerciseIds.contains(ex.exerciseId);
          final usesDur = (ex.durationSeconds != null) || isIso;
          return SetEntry(
            id: existing.id,
            setNumber: setNum,
            plannedReps: existing.plannedReps,
            plannedWeight: existing.plannedWeight,
            plannedDuration: usesDur ? ex.durationSeconds : null,
            reps: existing.reps,
            weight: existing.weight,
            duration: existing.durationSeconds,
            distance: existing.distanceMeters,
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
        final isCardio = ex.durationSeconds != null && !isIso;
        final usesDuration = isCardio || isIso;
        final lastWeight = lastWeights[ex.exerciseId];
        return SetEntry(
          setNumber: setNum,
          plannedReps: usesDuration ? null : ex.targetReps,
          plannedWeight: usesDuration ? null : lastWeight,
          plannedDuration: usesDuration ? ex.durationSeconds : null,
          reps: usesDuration ? null : ex.targetReps,
          weight: usesDuration ? null : lastWeight,
          duration: usesDuration ? ex.durationSeconds : null,
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

    state = null;
    await ref.read(userDataSyncCoordinatorProvider).syncWorkoutSessionToCloud();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);
  }

}
