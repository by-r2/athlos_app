import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/execution_set_segment.dart';
import '../../domain/entities/progression_rule.dart';
import '../../domain/helpers/load_progression_rules.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/session_kind.dart';
import '../../domain/repositories/workout_execution_repository.dart';
import '../../../../core/utils/uuid.dart';
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
import '../helpers/superset_grouping.dart';
import '../helpers/workout_exercise_structure.dart';
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
      _draftTemplatePersistTimer?.cancel();
    });
    return null;
  }

  static const Duration _draftPersistDebounce = Duration(milliseconds: 600);
  final Map<String, Timer> _draftPersistTimers = {};
  Timer? _draftTemplatePersistTimer;

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
      sessionKind: SessionKind.planned,
    );
    final executionId = result.getOrThrow();

    final exerciseSets = await _buildInitialExerciseSets(
      repo: repo,
      exercises: exercises,
      deloadConfig: deloadConfig,
      progressionRules: progressionRules,
      isometricExerciseIds: isometricExerciseIds,
    );

    state = ActiveExecutionState(
      executionId: executionId,
      workoutId: workoutId,
      exerciseSets: exerciseSets,
      exercises: exercises,
      isDeload: deloadConfig != null,
      defaultRestSeconds: defaultRestSeconds,
    );

    _structuralEditDeloadConfig = deloadConfig;
    _structuralEditProgressionRules = progressionRules;
    _structuralEditIsometricExerciseIds = isometricExerciseIds;
  }

  /// Starts an ad-hoc session on a draft workout with no template exercises.
  Future<void> startAdHocExecution(
    String workoutId, {
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
      sessionKind: SessionKind.adHoc,
    );
    final executionId = result.getOrThrow();

    state = ActiveExecutionState(
      executionId: executionId,
      workoutId: workoutId,
      exerciseSets: const {},
      exercises: const [],
      isDeload: deloadConfig != null,
      defaultRestSeconds: defaultRestSeconds,
      isAdHoc: true,
    );

    // Stash deload/progression context for in-session structural edits.
    _structuralEditDeloadConfig = deloadConfig;
    _structuralEditProgressionRules = progressionRules;
    _structuralEditIsometricExerciseIds = isometricExerciseIds;
  }

  DeloadConfig? _structuralEditDeloadConfig;
  List<ProgressionRule> _structuralEditProgressionRules = const [];
  Set<String> _structuralEditIsometricExerciseIds = const {};

  /// Enters structural edit mode for a planned session (in-memory overlay).
  void enterStructuralEditing() {
    final current = state;
    if (current == null || current.isAdHoc || current.isStructuralEditing) {
      return;
    }

    state = current.copyWith(
      isStructuralEditing: true,
      baselineExercises: cloneWorkoutExercises(current.exercises),
    );
  }

  /// Restores the session template to the baseline; completed sets are kept.
  Future<void> discardStructuralEdits() async {
    final current = state;
    if (current == null ||
        !current.isStructuralEditing ||
        current.baselineExercises == null) {
      return;
    }

    final baseline = cloneWorkoutExercises(current.baselineExercises!);
    final exerciseSets = await _rebuildExerciseSetsForTemplate(
      baseline,
      current.exerciseSets,
    );

    state = current.copyWith(
      exercises: baseline,
      exerciseSets: exerciseSets,
      isStructuralEditing: false,
      clearBaselineExercises: true,
    );
  }

  /// Adds an exercise during structural editing (ad-hoc or planned overlay).
  /// Returns false when the catalog exercise is already in the workout.
  Future<bool> addExercise(Exercise exercise) async {
    final current = state;
    if (current == null || !current.canEditStructure) return false;
    if (workoutAlreadyContainsExercise(current.exercises, exercise.id)) {
      return false;
    }

    final restSeconds = current.defaultRestSeconds > 0
        ? current.defaultRestSeconds
        : 60;
    final isCardio = exercise.type == ExerciseType.cardio;
    final workoutExercise = WorkoutExercise(
      id: generateUuidV4(),
      workoutId: current.workoutId,
      exerciseId: exercise.id,
      sortOrder: current.exercises.length,
      sets: 3,
      minReps: isCardio ? null : 12,
      maxReps: isCardio ? null : 12,
      restSeconds: restSeconds,
      durationSeconds: isCardio ? 300 : null,
    );

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final newSets = await _buildInitialExerciseSets(
      repo: repo,
      exercises: [workoutExercise],
      deloadConfig: _structuralEditDeloadConfig,
      progressionRules: _structuralEditProgressionRules,
      isometricExerciseIds: _structuralEditIsometricExerciseIds,
    );

    state = current.copyWith(
      exercises: [...current.exercises, workoutExercise],
      exerciseSets: {...current.exerciseSets, ...newSets},
    );
    _scheduleDraftTemplatePersist();
    return true;
  }

  /// Updates prescription during structural editing and rebuilds pending sets.
  Future<void> updateAdHocExercise(WorkoutExercise updated) async {
    final current = state;
    if (current == null || !current.canEditStructure) return;

    final index = current.exercises.indexWhere(
      (e) => e.id == updated.id,
    );
    if (index < 0) return;

    final oldSets = current.exerciseSets[updated.id] ?? [];
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final freshSets = await _buildInitialExerciseSets(
      repo: repo,
      exercises: [updated],
      deloadConfig: _structuralEditDeloadConfig,
      progressionRules: _structuralEditProgressionRules,
      isometricExerciseIds: _structuralEditIsometricExerciseIds,
    );
    final template = freshSets[updated.id] ?? [];

    final merged = <SetEntry>[];
    for (var setNum = 1; setNum <= updated.sets; setNum++) {
      final existing =
          oldSets.where((s) => s.setNumber == setNum).firstOrNull;
      if (existing != null && existing.isCompleted) {
        merged.add(existing);
      } else {
        final planned =
            template.where((s) => s.setNumber == setNum).firstOrNull;
        if (planned != null) merged.add(planned);
      }
    }

    final updatedExercises = syncSupersetRestInList(current.exercises, updated);
    final resolved = updatedExercises.firstWhere(
      (e) => e.id == updated.id,
    );

    state = current.copyWith(
      exercises: updatedExercises,
      exerciseSets: {...current.exerciseSets, resolved.id: merged},
    );
    _scheduleDraftTemplatePersist();
  }

  /// Reorders exercises during structural editing (moves whole superset blocks).
  /// Returns false when the block has completed sets and cannot move.
  bool reorderAdHocExercises(int oldIndex, int newIndex) {
    final current = state;
    if (current == null || !current.canEditStructure) return false;
    if (oldIndex < 0 ||
        oldIndex >= current.exercises.length ||
        newIndex < 0 ||
        newIndex > current.exercises.length) {
      return false;
    }

    var blockStart = oldIndex;
    final gid = current.exercises[oldIndex].groupId;
    if (gid != null) {
      while (blockStart > 0 &&
          current.exercises[blockStart - 1].groupId == gid) {
        blockStart--;
      }
    }

    if (blockHasCompletedSets(
      exercises: current.exercises,
      blockStartIndex: blockStart,
      hasCompletedSet: (rowId) =>
          (current.exerciseSets[rowId] ?? [])
              .any((s) => s.isCompleted),
    )) {
      return false;
    }

    state = current.copyWith(
      exercises: reorderExercisesInList(
        current.exercises,
        oldIndex,
        newIndex,
      ),
    );
    _scheduleDraftTemplatePersist();
    return true;
  }

  /// Sets superset membership from overview selection during structural editing.
  void commitSupersetSelection(
    Set<String> linkedExerciseIds, {
    int? editingGroupId,
  }) {
    final current = state;
    if (current == null || !current.canEditStructure) return;

    state = current.copyWith(
      exercises: applySupersetSelection(
        current.exercises,
        linkedExerciseIds,
        editingGroupId: editingGroupId,
      ),
    );
    _scheduleDraftTemplatePersist();
  }

  /// Removes an exercise during structural editing (keeps completed sets as orphans).
  void removeExercise(String rowId) {
    final current = state;
    if (current == null || !current.canEditStructure) return;

    final updatedExercises = normalizeLonelySupersetGroups([
      for (final e in current.exercises)
        if (e.id != rowId) e,
    ]);
    final updatedSets = Map<String, List<SetEntry>>.from(current.exerciseSets);
    final existing = updatedSets[rowId] ?? [];
    final completedOnly = existing.where((s) => s.isCompleted).toList();
    if (completedOnly.isEmpty) {
      updatedSets.remove(rowId);
    } else {
      updatedSets[rowId] = completedOnly;
    }

    state = current.copyWith(
      exercises: updatedExercises,
      exerciseSets: updatedSets,
    );
    _scheduleDraftTemplatePersist();
  }

  Future<Map<String, List<SetEntry>>> _rebuildExerciseSetsForTemplate(
    List<WorkoutExercise> template,
    Map<String, List<SetEntry>> currentSets,
  ) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final freshSets = await _buildInitialExerciseSets(
      repo: repo,
      exercises: template,
      deloadConfig: _structuralEditDeloadConfig,
      progressionRules: _structuralEditProgressionRules,
      isometricExerciseIds: _structuralEditIsometricExerciseIds,
    );

    final baselineRowIds = template.map((e) => e.id).toSet();
    final result = <String, List<SetEntry>>{};

    for (final ex in template) {
      final oldSets = currentSets[ex.id] ?? [];
      final planned = freshSets[ex.id] ?? [];
      final merged = <SetEntry>[];
      for (var setNum = 1; setNum <= ex.sets; setNum++) {
        final existing =
            oldSets.where((s) => s.setNumber == setNum).firstOrNull;
        if (existing != null && existing.isCompleted) {
          merged.add(existing);
        } else {
          final plannedSet =
              planned.where((s) => s.setNumber == setNum).firstOrNull;
          if (plannedSet != null) merged.add(plannedSet);
        }
      }
      result[ex.id] = merged;
    }

    for (final entry in currentSets.entries) {
      if (baselineRowIds.contains(entry.key)) continue;
      final completedOnly =
          entry.value.where((s) => s.isCompleted).toList();
      if (completedOnly.isNotEmpty) {
        result[entry.key] = completedOnly;
      }
    }

    return result;
  }

  void _scheduleDraftTemplatePersist() {
    final current = state;
    if (current == null || !current.isAdHoc) return;

    _draftTemplatePersistTimer?.cancel();
    _draftTemplatePersistTimer = Timer(
      _draftPersistDebounce,
      () => unawaited(_persistDraftTemplate()),
    );
  }

  Future<void> _persistDraftTemplate() async {
    final current = state;
    if (current == null || !current.isAdHoc) return;

    final result = await ref.read(workoutRepositoryProvider).persistDraftExercises(
      current.workoutId,
      current.exercises,
    );
    result.getOrThrow();
  }

  Future<Map<String, List<SetEntry>>> _buildInitialExerciseSets({
    required WorkoutExecutionRepository repo,
    required List<WorkoutExercise> exercises,
    DeloadConfig? deloadConfig,
    List<ProgressionRule> progressionRules = const [],
    Set<String> isometricExerciseIds = const {},
  }) async {
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
          ex.durationSeconds != null &&
          !isometricExerciseIds.contains(ex.exerciseId);
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

      exerciseSets[ex.id] = List.generate(
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
    return exerciseSets;
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
    String rowId,
    int setNumber, {
    int? reps,
    double? weight,
    int? duration,
    double? distance,
  }) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[rowId];
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
      exerciseSets: {...current.exerciseSets, rowId: updated},
    );

    _scheduleDraftPersist(rowId: rowId, setNumber: setNumber);
  }

  /// Add a drop segment to a set (in-memory only, persisted on complete).
  void addDropSegment(
    String rowId,
    int setNumber, {
    required int reps,
    double? weight,
  }) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[rowId];
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
      exerciseSets: {...current.exerciseSets, rowId: updated},
    );

    _scheduleDraftPersist(rowId: rowId, setNumber: setNumber);
  }

  /// Remove a drop segment by index.
  /// Overrides how load is interpreted for one set (persisted when completed).
  void updateSetLoadModeOverride(
    String rowId,
    int setNumber,
    LoadMode? loadModeOverride,
  ) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[rowId];
    if (sets == null) return;

    final updated = [
      for (final s in sets)
        if (s.setNumber == setNumber)
          s.copyWith(loadModeOverride: () => loadModeOverride)
        else
          s,
    ];

    state = current.copyWith(
      exerciseSets: {...current.exerciseSets, rowId: updated},
    );
  }

  void removeDropSegment(String rowId, int setNumber, int segmentIndex) {
    final current = state;
    if (current == null) return;

    final sets = current.exerciseSets[rowId];
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
      exerciseSets: {...current.exerciseSets, rowId: updated},
    );

    _scheduleDraftPersist(rowId: rowId, setNumber: setNumber);
  }

  void _scheduleDraftPersist({
    required String rowId,
    required int setNumber,
  }) {
    final current = state;
    if (current == null) return;

    final key = '${current.executionId}:$rowId:$setNumber';
    _draftPersistTimers.remove(key)?.cancel();
    _draftPersistTimers[key] = Timer(
      _draftPersistDebounce,
      () => unawaited(
        _persistDraftSet(rowId: rowId, setNumber: setNumber),
      ),
    );
  }

  Future<void> _persistDraftSet({
    required String rowId,
    required int setNumber,
  }) async {
    final current = state;
    if (current == null) return;

    final catalogExerciseId = current.exerciseByRowId(rowId)?.exerciseId;
    if (catalogExerciseId == null) return;

    final sets = current.exerciseSets[rowId];
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
      exerciseId: catalogExerciseId,
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
    final latestSets = latest.exerciseSets[rowId];
    if (latestSets == null) return;
    final linked = [
      for (final s in latestSets)
        if (s.setNumber == setNumber) s.copyWith(id: persistedId) else s,
    ];
    state = latest.copyWith(
      exerciseSets: {...latest.exerciseSets, rowId: linked},
    );
  }

  /// Mark a set as completed and persist it to the database.
  /// Returns the rest time (seconds) for the exercise so the caller can start
  /// the timer.
  /// Returns (restSeconds, suggestedNextWeight) — suggestedNextWeight is non-null
  /// only when **every planned work set** (excluding warm-ups) hit at least `maxReps`.
  Future<(int, double?)> completeSet(
    String rowId,
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

    final exercise = current.exerciseByRowId(rowId);
    if (exercise == null) return (0, null);

    final sets = current.exerciseSets[rowId];
    if (sets == null) return (0, null);

    final entry = sets.firstWhere((s) => s.setNumber == setNumber);
    final effectiveSegments = segments ?? entry.segments;
    final bodyWeightSnapshot = await ref.read(latestBodyWeightProvider.future);
    final catalogExerciseId = exercise.exerciseId;

    final executionSet = ExecutionSet(
      id: entry.id ?? '',
      executionId: current.executionId,
      exerciseId: catalogExerciseId,
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
      exerciseSets: {...current.exerciseSets, rowId: updated},
    );

    final rest = exercise.restSeconds > 0
        ? exercise.restSeconds
        : current.defaultRestSeconds;

    double? suggestedWeight;
    final maxReps = exercise.maxReps;
    final latestExerciseSets = state!.exerciseSets[rowId] ?? [];
    if (maxReps != null &&
        maxReps > 0 &&
        workSetsQualifyForSuggestedWeightIncrease(
          latestSetsForExercise: latestExerciseSets,
          maxReps: maxReps,
        )) {
      final catalogResult = await ref
          .read(exerciseRepositoryProvider)
          .getById(catalogExerciseId);
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

    if (current.isAdHoc) {
      _draftTemplatePersistTimer?.cancel();
      await _persistDraftTemplate();
    }

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
    _structuralEditDeloadConfig = null;
    _structuralEditProgressionRules = const [];
    _structuralEditIsometricExerciseIds = const {};
    await ref.read(userDataSyncCoordinatorProvider).syncWorkoutSessionToCloud();

    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(lastFinishedCycleWorkoutIdProvider);
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
    bool isAdHoc = false,
  }) async {
    final repo = ref.read(workoutExecutionRepositoryProvider);

    final setsResult = await repo.getSets(executionId);
    final dbSets = setsResult.getOrThrow();

    var templateExercises = exercises;
    if (isAdHoc && exercises.isEmpty && dbSets.isNotEmpty) {
      templateExercises = _rebuildAdHocTemplateFromSets(
        workoutId: workoutId,
        dbSets: dbSets,
        defaultRestSeconds: defaultRestSeconds,
      );
    }

    final exerciseIds = templateExercises.map((e) => e.exerciseId).toList();
    final lastWeights = (await repo.getLastWeightsForExercises(exerciseIds))
        .getOrThrow();

    final dbSetsByCatalogId = <String, List<ExecutionSet>>{};
    for (final set in dbSets) {
      (dbSetsByCatalogId[set.exerciseId] ??= []).add(set);
    }
    for (final list in dbSetsByCatalogId.values) {
      list.sort((a, b) {
        final bySet = a.setNumber.compareTo(b.setNumber);
        if (bySet != 0) return bySet;
        return a.id.compareTo(b.id);
      });
    }

    ExecutionSet? takeDbSet(String catalogExerciseId, int setNumber) {
      final queue = dbSetsByCatalogId[catalogExerciseId];
      if (queue == null || queue.isEmpty) return null;
      final index = queue.indexWhere((s) => s.setNumber == setNumber);
      if (index < 0) return null;
      return queue.removeAt(index);
    }

    final exerciseSets = <String, List<SetEntry>>{};
    for (final ex in templateExercises) {
      final allocated = <int, ExecutionSet>{};
      for (var setNum = 1; setNum <= ex.sets; setNum++) {
        final taken = takeDbSet(ex.exerciseId, setNum);
        if (taken != null) allocated[setNum] = taken;
      }
      var nextExtra = ex.sets + 1;
      while (true) {
        final taken = takeDbSet(ex.exerciseId, nextExtra);
        if (taken == null) break;
        allocated[nextExtra] = taken;
        nextExtra++;
      }
      final totalSets = allocated.isEmpty
          ? ex.sets
          : math.max(ex.sets, allocated.keys.reduce(math.max));

      exerciseSets[ex.id] = List.generate(totalSets, (i) {
        final setNum = i + 1;
        final existing = allocated[setNum];
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
      exercises: templateExercises,
      defaultRestSeconds: defaultRestSeconds,
      isAdHoc: isAdHoc,
    );
  }

  List<WorkoutExercise> _rebuildAdHocTemplateFromSets({
    required String workoutId,
    required List<ExecutionSet> dbSets,
    required int defaultRestSeconds,
  }) {
    final orderedIds = <String>[];
    for (final set in dbSets) {
      if (!orderedIds.contains(set.exerciseId)) {
        orderedIds.add(set.exerciseId);
      }
    }

    final restSeconds = defaultRestSeconds > 0 ? defaultRestSeconds : 60;
    return [
      for (var i = 0; i < orderedIds.length; i++)
        WorkoutExercise(
          id: generateUuidV4(),
          workoutId: workoutId,
          exerciseId: orderedIds[i],
          sortOrder: i,
          sets: dbSets.where((s) => s.exerciseId == orderedIds[i]).length,
          minReps: 12,
          maxReps: 12,
          restSeconds: restSeconds,
        ),
    ];
  }

  void _clearActiveSessionIfMatch(String executionId) {
    if (state?.executionId != executionId) return;
    state = null;
    _structuralEditDeloadConfig = null;
    _structuralEditProgressionRules = const [];
    _structuralEditIsometricExerciseIds = const {};
  }

  /// Soft-deletes an unfinished execution, clears in-memory session when it
  /// matches, syncs tombstones, and refreshes dangling/list providers.
  Future<void> discardExecution(String executionId) async {
    _clearActiveSessionIfMatch(executionId);
    await _persistDiscardedExecution(executionId);
  }

  /// Cancel the active execution, deleting the DB record.
  Future<void> cancelExecution() async {
    final current = state;
    if (current == null) return;
    final executionId = current.executionId;
    _clearActiveSessionIfMatch(executionId);
    try {
      await _persistDiscardedExecution(executionId);
    } on Exception catch (e, st) {
      debugPrint('[ActiveExecution] cancelExecution failed: $e\n$st');
      ref.invalidate(danglingExecutionProvider);
    }
  }

  Future<void> _persistDiscardedExecution(String executionId) async {
    final execRepo = ref.read(workoutExecutionRepositoryProvider);
    final execution = (await execRepo.getById(executionId)).getOrThrow();

    (await execRepo.delete(executionId)).getOrThrow();

    if (execution != null) {
      final workout = (await ref
              .read(workoutRepositoryProvider)
              .getById(execution.workoutId))
          .getOrThrow();
      if (workout?.isDraft == true) {
        await ref.read(workoutRepositoryProvider).deleteDraft(execution.workoutId);
      }
    }

    ref.invalidate(danglingExecutionProvider);
    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);

    unawaited(
      ref.read(userDataSyncCoordinatorProvider).syncWorkoutSessionToCloud(),
    );
  }
}
