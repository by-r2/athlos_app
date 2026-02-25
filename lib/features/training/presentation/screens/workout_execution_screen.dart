import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout_exercise.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/rep_performance.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../helpers/duration_format.dart';
import '../providers/cardio_timer_notifier.dart';
import '../providers/rest_timer_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/workout_exercise_tile.dart' show supersetColorFor;

enum _ViewMode { overview, focused, timer, cardioTimer }

class WorkoutExecutionScreen extends ConsumerStatefulWidget {
  final int workoutId;

  const WorkoutExecutionScreen({super.key, required this.workoutId});

  @override
  ConsumerState<WorkoutExecutionScreen> createState() =>
      _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState
    extends ConsumerState<WorkoutExecutionScreen> {
  bool _isInitialized = false;
  _ViewMode _viewMode = _ViewMode.overview;

  int _focusedExerciseIndex = 0;
  int _focusedSetNumber = 1;
  double _currentWeight = 0;
  int _currentReps = 0;
  int _currentDuration = 0;
  double _currentDistance = 0;
  List<_DropSegmentInput> _dropSegments = [];

  @override
  Widget build(BuildContext context) {
    final exercisesAsync =
        ref.watch(workoutExercisesProvider(widget.workoutId));
    final execState = ref.watch(activeExecutionProvider);
    final timerState = ref.watch(restTimerProvider);
    final cardioState = ref.watch(cardioTimerProvider);
    ref.watch(exerciseListProvider);

    if (!_isInitialized &&
        exercisesAsync is AsyncData<List<WorkoutExercise>> &&
        execState == null) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        final router = GoRouter.of(context);
        try {
          await ref
              .read(activeExecutionProvider.notifier)
              .startExecution(widget.workoutId, exercisesAsync.value);
        } on Exception catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.genericError)),
          );
          router.pop();
        }
      });
    }

    // No auto-transition — the timer view shows a "rest complete" state
    // with explicit buttons for the user to proceed.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_viewMode == _ViewMode.focused ||
            _viewMode == _ViewMode.cardioTimer) {
          ref.read(cardioTimerProvider.notifier).reset();
          setState(() => _viewMode = _ViewMode.overview);
        } else {
          _showCancelDialog(context);
        }
      },
      child: execState == null
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : switch (_viewMode) {
              _ViewMode.overview => _buildOverview(context, execState),
              _ViewMode.focused => _buildFocused(context, execState),
              _ViewMode.timer =>
                _buildTimer(context, execState, timerState),
              _ViewMode.cardioTimer =>
                _buildCardioTimer(context, execState, cardioState),
            },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _exerciseName(int exerciseId) {
    final l10n = AppLocalizations.of(context)!;
    final allExercises = ref.read(exerciseListProvider).value;
    final entity = allExercises?.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => throw StateError('Exercise $exerciseId not found'),
    );
    if (entity == null) return l10n.unknownExerciseId(exerciseId);
    return localizedExerciseName(
      entity.name,
      isVerified: entity.isVerified,
      l10n: l10n,
    );
  }

  String _muscleGroupName(int exerciseId) {
    final l10n = AppLocalizations.of(context)!;
    final allExercises = ref.read(exerciseListProvider).value;
    final entity = allExercises?.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => throw StateError('Exercise $exerciseId not found'),
    );
    if (entity == null) return '';
    return localizedMuscleGroupName(entity.muscleGroup, l10n);
  }

  int get _totalSetCount {
    final exec = ref.read(activeExecutionProvider);
    if (exec == null) return 0;
    return exec.exerciseSets.values.expand((s) => s).length;
  }

  /// Returns the next incomplete (exerciseIndex, setNumber), or null if all done.
  (int exerciseIndex, int setNumber)? _findNextPendingSet(
      ActiveExecutionState exec) {
    for (var i = 0; i < exec.exercises.length; i++) {
      final exId = exec.exercises[i].exerciseId;
      final sets = exec.exerciseSets[exId] ?? [];
      for (final s in sets) {
        if (!s.isCompleted) return (i, s.setNumber);
      }
    }
    return null;
  }

  /// Returns the indices of exercises that share the same superset group
  /// with the exercise at [exerciseIndex].
  List<int> _getSupersetGroupIndices(
      ActiveExecutionState exec, int exerciseIndex) {
    final gid = exec.exercises[exerciseIndex].groupId;
    if (gid == null) return [exerciseIndex];
    return [
      for (var i = 0; i < exec.exercises.length; i++)
        if (exec.exercises[i].groupId == gid) i,
    ];
  }

  /// Returns the next exercise index in the superset group that has a pending
  /// set with [setNumber], or null if all done for this set round.
  int? _nextInSupersetGroup(
      ActiveExecutionState exec, int currentIndex, int setNumber) {
    final group = _getSupersetGroupIndices(exec, currentIndex);
    final currentPosInGroup = group.indexOf(currentIndex);
    for (var offset = 1; offset < group.length; offset++) {
      final nextIdx = group[(currentPosInGroup + offset) % group.length];
      final exId = exec.exercises[nextIdx].exerciseId;
      final sets = exec.exerciseSets[exId] ?? [];
      final match = sets.where(
          (s) => s.setNumber == setNumber && !s.isCompleted);
      if (match.isNotEmpty) return nextIdx;
    }
    return null;
  }


  bool _isFocusedCardio(ActiveExecutionState exec) =>
      exec.exercises[_focusedExerciseIndex].duration != null;

  void _goToFocused(ActiveExecutionState exec, int exerciseIndex,
      [int? setNumber]) {
    final exId = exec.exercises[exerciseIndex].exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];

    final targetSet = setNumber ??
        sets
            .where((s) => !s.isCompleted)
            .map((s) => s.setNumber)
            .firstOrNull ??
        1;

    final entry = sets.firstWhere(
      (s) => s.setNumber == targetSet,
      orElse: () => sets.first,
    );

    final prevCompleted = sets
        .where((s) => s.isCompleted && s.setNumber < targetSet)
        .toList();

    final isCardio = exec.exercises[exerciseIndex].duration != null;

    setState(() {
      _focusedExerciseIndex = exerciseIndex;
      _focusedSetNumber = targetSet;

      if (isCardio) {
        _viewMode = _ViewMode.cardioTimer;
        _currentDuration = entry.duration ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.duration ?? 0
                : exec.exercises[exerciseIndex].duration ?? 0);
        _currentDistance = entry.distance ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.distance ?? 0
                : 0);
        ref.read(cardioTimerProvider.notifier).reset();
      } else {
        _viewMode = _ViewMode.focused;
        _currentWeight = entry.weight ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.weight ?? 0
                : entry.plannedWeight ?? 0);
        _currentReps = prevCompleted.isNotEmpty
            ? prevCompleted.last.reps ?? entry.reps ?? 0
            : entry.reps ?? 0;
      }
      _dropSegments = entry.segments
          .skip(1)
          .map((s) => _DropSegmentInput(reps: s.reps, weight: s.weight ?? 0))
          .toList();
    });
  }

  void _goToNextSetFromTimer(ActiveExecutionState exec) {
    ref.read(restTimerProvider.notifier).reset();
    final exId = exec.exercises[_focusedExerciseIndex].exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];
    final nextInExercise = sets
        .where((s) => !s.isCompleted && s.setNumber > _focusedSetNumber)
        .toList();

    if (nextInExercise.isNotEmpty) {
      _goToFocused(
          exec, _focusedExerciseIndex, nextInExercise.first.setNumber);
    } else {
      final globalNext = _findNextPendingSet(exec);
      if (globalNext != null) {
        _goToFocused(exec, globalNext.$1, globalNext.$2);
      } else {
        setState(() => _viewMode = _ViewMode.overview);
      }
    }
  }

  void _returnToOverviewFromTimer() {
    ref.read(restTimerProvider.notifier).reset();
    setState(() => _viewMode = _ViewMode.overview);
  }

  // ---------------------------------------------------------------------------
  // View 1: Overview
  // ---------------------------------------------------------------------------

  Widget _buildOverview(BuildContext context, ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId));
    final workoutName = workoutAsync.value?.name ?? '';
    final completed = exec.completedSetCount;
    final total = _totalSetCount;
    final next = _findNextPendingSet(exec);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.executionTitle(workoutName)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _showCancelDialog(context),
            child: Text(
              l10n.cancelExecution,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.md,
              vertical: AthlosSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.overallProgress(completed, total),
                      style: textTheme.labelLarge,
                    ),
                    if (completed == total && total > 0)
                      Icon(Icons.check_circle,
                          color: colorScheme.primary, size: 20),
                  ],
                ),
                const SizedBox(height: AthlosSpacing.xs),
                LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  borderRadius: AthlosRadius.fullAll,
                ),
              ],
            ),
          ),

          // Exercise list
          Expanded(
            child: Builder(builder: (context) {
              final groupColorMap = <int, int>{};
              var nextColorIdx = 0;
              for (final ex in exec.exercises) {
                if (ex.groupId != null &&
                    !groupColorMap.containsKey(ex.groupId)) {
                  groupColorMap[ex.groupId!] = nextColorIdx++;
                }
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                ),
                itemCount: exec.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exec.exercises[index];
                  final sets =
                      exec.exerciseSets[exercise.exerciseId] ?? [];
                  final completedSets =
                      sets.where((s) => s.isCompleted).length;
                  final totalSets = sets.length;
                  final isAllDone = completedSets == totalSets;
                  final isActive = next != null && next.$1 == index;

                  final gid = exercise.groupId;
                  final isGroupedWithPrev = index > 0 &&
                      gid != null &&
                      exec.exercises[index - 1].groupId == gid;
                  final isGroupedWithNext =
                      index < exec.exercises.length - 1 &&
                          gid != null &&
                          exec.exercises[index + 1].groupId == gid;

                  return _OverviewExerciseCard(
                    exerciseName: _exerciseName(exercise.exerciseId),
                    muscleGroup: _muscleGroupName(exercise.exerciseId),
                    completedSets: completedSets,
                    totalSets: totalSets,
                    isAllDone: isAllDone,
                    isActive: isActive,
                    isGroupedWithPrevious: isGroupedWithPrev,
                    isGroupedWithNext: isGroupedWithNext,
                    groupColorIndex: gid != null
                        ? groupColorMap[gid]
                        : null,
                    onTap: () => _goToFocused(exec, index),
                  );
                },
              );
            }),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (next != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () =>
                            _goToFocused(exec, next.$1, next.$2),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.nextSetButton(
                          _exerciseName(
                              exec.exercises[next.$1].exerciseId),
                          next.$2,
                        )),
                      ),
                    ),
                    const SizedBox(height: AthlosSpacing.sm),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: exec.hasCompletedSets &&
                              !exec.isFinishing
                          ? () => _onFinish(context)
                          : null,
                      icon: exec.isFinishing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(l10n.finishWorkout),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 2: Focused
  // ---------------------------------------------------------------------------

  Widget _buildFocused(BuildContext context, ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final totalSets = sets.length;
    final name = _exerciseName(exercise.exerciseId);
    final group = _muscleGroupName(exercise.exerciseId);

    // Find previous completed set for reference
    final prevCompleted = sets
        .where(
            (s) => s.isCompleted && s.setNumber < _focusedSetNumber)
        .toList();
    final prevSet = prevCompleted.isNotEmpty ? prevCompleted.last : null;

    final currentSetEntry = sets.firstWhere(
      (s) => s.setNumber == _focusedSetNumber,
      orElse: () => sets.first,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _viewMode = _ViewMode.overview),
        ),
        title: Text(name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            child: Text(
              l10n.setOf(_focusedSetNumber, totalSets),
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AthlosSpacing.lg),
            if (group.isNotEmpty)
              Text(
                group,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const Spacer(),

            if (_isFocusedCardio(exec)) ...[
              // Duration input
              _NumberInput(
                value: _currentDuration.toDouble(),
                suffix: l10n.durationSecondsSuffix,
                step: 30,
                onChanged: (v) =>
                    setState(() => _currentDuration = v.toInt()),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: AthlosSpacing.xl),

              // Distance input
              _NumberInput(
                value: _currentDistance,
                suffix: l10n.distanceMetersSuffix,
                step: 100,
                onChanged: (v) =>
                    setState(() => _currentDistance = v),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            ] else ...[
              // Weight input
              _NumberInput(
                value: _currentWeight,
                suffix: l10n.weightKgSuffix,
                step: 2.5,
                onChanged: (v) => setState(() => _currentWeight = v),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: AthlosSpacing.xl),

              // Reps input
              _NumberInput(
                value: _currentReps.toDouble(),
                suffix: l10n.repsShort,
                step: 1,
                onChanged: (v) =>
                    setState(() => _currentReps = v.toInt()),
                textTheme: textTheme,
                colorScheme: colorScheme,
                valueColor: repsDeviationColor(
                    colorScheme,
                    Theme.of(context).extension<AthlosCustomColors>()!,
                    _currentReps,
                    exercise.reps ?? 0),
              ),

              const SizedBox(height: AthlosSpacing.md),

              // Drop set segments
              if (_dropSegments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: AthlosSpacing.xs),
                  padding: const EdgeInsets.all(AthlosSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer
                        .withValues(alpha: 0.2),
                    borderRadius: AthlosRadius.mdAll,
                    border: Border.all(
                      color:
                          colorScheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var idx = 0;
                          idx < _dropSegments.length;
                          idx++)
                        _DropSegmentRow(
                          index: idx,
                          segment: _dropSegments[idx],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          l10n: l10n,
                          onWeightChanged: (w) => setState(
                              () => _dropSegments[idx] =
                                  _dropSegments[idx]
                                      .copyWith(weight: w)),
                          onRepsChanged: (r) => setState(
                              () => _dropSegments[idx] =
                                  _dropSegments[idx]
                                      .copyWith(reps: r)),
                          onRemove: () => setState(
                              () => _dropSegments.removeAt(idx)),
                        ),
                    ],
                  ),
                ),

              // Add drop set button
              if (!currentSetEntry.isCompleted)
                Padding(
                  padding:
                      const EdgeInsets.only(top: AthlosSpacing.xs),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _dropSegments.add(_DropSegmentInput(
                          reps: (_currentReps * 0.5).ceil(),
                          weight: _currentWeight * 0.8,
                        ));
                      });
                    },
                    icon: Icon(Icons.arrow_downward,
                        size: 16, color: colorScheme.tertiary),
                    label: Text(l10n.addDropSet),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.tertiary,
                      side: BorderSide(
                          color: colorScheme.tertiary
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                ),
            ],

            const Spacer(),

            // Previous set reference (strength only)
            if (prevSet != null && !_isFocusedCardio(exec))
              Padding(
                padding:
                    const EdgeInsets.only(bottom: AthlosSpacing.md),
                child: Text(
                  l10n.previousSetRef(
                    prevSet.weight?.toStringAsFixed(
                            prevSet.weight! % 1 == 0 ? 0 : 1) ??
                        '0',
                    prevSet.reps ?? 0,
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // Complete button
            if (!currentSetEntry.isCompleted)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _onCompleteSet(exec),
                  icon: const Icon(Icons.check),
                  label: Text(
                    l10n.completeSetButton,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    // Move to next set or back to overview
                    final nextInExercise = sets
                        .where((s) =>
                            !s.isCompleted &&
                            s.setNumber > _focusedSetNumber)
                        .toList();
                    if (nextInExercise.isNotEmpty) {
                      _goToFocused(exec, _focusedExerciseIndex,
                          nextInExercise.first.setNumber);
                    } else {
                      setState(() => _viewMode = _ViewMode.overview);
                    }
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.next),
                ),
              ),

            const SizedBox(height: AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 3: Timer
  // ---------------------------------------------------------------------------

  Widget _buildTimer(
    BuildContext context,
    ActiveExecutionState exec,
    RestTimerState timerState,
  ) {
    final isFinished =
        timerState.totalSeconds > 0 && timerState.remainingSeconds == 0;

    if (isFinished) {
      return _buildTimerDone(context, exec);
    }
    return _buildTimerCounting(context, exec, timerState);
  }

  Widget _buildTimerCounting(
    BuildContext context,
    ActiveExecutionState exec,
    RestTimerState timerState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final next = _findNextPendingSet(exec);
    final nextLabel = next != null
        ? l10n.nextUpLabel(
            _exerciseName(exec.exercises[next.$1].exerciseId),
            next.$2,
          )
        : l10n.allSetsComplete;

    final minutes = timerState.remainingSeconds ~/ 60;
    final seconds = timerState.remainingSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Text(
              timeText,
              style: textTheme.displayLarge?.copyWith(
                fontSize: 80,
                fontWeight: FontWeight.w300,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AthlosSpacing.lg),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.xxl),
              child: LinearProgressIndicator(
                value: timerState.progress,
                borderRadius: AthlosRadius.fullAll,
                minHeight: 6,
              ),
            ),

            const SizedBox(height: AthlosSpacing.xl),

            Icon(
              Icons.timer_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),

            const SizedBox(height: AthlosSpacing.sm),

            Text(
              nextLabel,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            ?_buildLoadFeedback(exec, context),

            const Spacer(flex: 3),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ref.read(restTimerProvider.notifier).addTime(15);
                    },
                    child: Text(l10n.addTimeButton),
                  ),
                  const SizedBox(width: AthlosSpacing.lg),
                  FilledButton(
                    onPressed: () {
                      ref.read(restTimerProvider.notifier).skip();
                    },
                    child: Text(l10n.skipTimer),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDone(BuildContext context, ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exId = exec.exercises[_focusedExerciseIndex].exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];
    final hasMoreSetsInExercise =
        sets.any((s) => !s.isCompleted && s.setNumber > _focusedSetNumber);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: colorScheme.primary,
            ),

            const SizedBox(height: AthlosSpacing.lg),

            Text(
              l10n.restComplete,
              style: textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (!hasMoreSetsInExercise) ...[
              const SizedBox(height: AthlosSpacing.md),
              Text(
                l10n.exerciseCompleteMessage,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            ?_buildLoadFeedback(exec, context),

            const Spacer(flex: 3),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: hasMoreSetsInExercise
                    ? FilledButton.icon(
                        onPressed: () => _goToNextSetFromTimer(exec),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.nextSetLabel),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _returnToOverviewFromTimer(),
                        icon: const Icon(Icons.list_alt),
                        label: Text(l10n.backToOverview),
                      ),
              ),
            ),

            const SizedBox(height: AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget? _buildLoadFeedback(ActiveExecutionState exec, BuildContext context) {
    if (_isFocusedCardio(exec)) return null;

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final completedReps = sets
        .where((s) => s.isCompleted && s.reps != null)
        .map((s) => s.reps!)
        .toList();

    final feedback = loadFeedback(
      cs: colorScheme,
      custom: Theme.of(context).extension<AthlosCustomColors>()!,
      l10n: l10n,
      completedReps: completedReps,
      plannedReps: exercise.reps ?? 0,
    );
    if (feedback == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: AthlosSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: feedback.color),
          const SizedBox(width: AthlosSpacing.xs),
          Flexible(
            child: Text(
              feedback.message,
              style: textTheme.bodySmall?.copyWith(color: feedback.color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 4: Cardio Timer
  // ---------------------------------------------------------------------------

  void _exitCardioTimer() {
    ref.read(cardioTimerProvider.notifier).reset();
    setState(() => _viewMode = _ViewMode.overview);
  }

  PreferredSizeWidget _cardioAppBar(String name, int totalSets,
      {VoidCallback? onBack}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack ?? _exitCardioTimer,
      ),
      title: Text(name),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(24),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
          child: Text(
            l10n.setOf(_focusedSetNumber, totalSets),
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalReachedBadge({double bottomMargin = AthlosSpacing.md}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AthlosRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
              size: 18, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: AthlosSpacing.xs),
          Text(
            l10n.cardioGoalReached,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardioTimer(
    BuildContext context,
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final goalSeconds = exercise.duration ?? 0;

    final currentSetEntry = sets.firstWhere(
      (s) => s.setNumber == _focusedSetNumber,
      orElse: () => sets.first,
    );

    if (currentSetEntry.isCompleted) {
      return _buildCardioCompleted(exec, sets);
    }
    if (cardioState.isStopped) {
      return _buildCardioFinishing(exec, cardioState);
    }
    if (cardioState.isReady) {
      return _buildCardioReady(exec, goalSeconds);
    }
    return _buildCardioRunning(exec, cardioState);
  }

  Widget _buildCardioReady(ActiveExecutionState exec, int goalSeconds) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return Scaffold(
      appBar: _cardioAppBar(name, sets.length),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              if (goalSeconds > 0) ...[
                Text(
                  l10n.cardioGoalLabel(formatDuration(goalSeconds)),
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AthlosSpacing.xl),
              ],

              SizedBox(
                width: 120,
                height: 120,
                child: FilledButton(
                  onPressed: () =>
                      ref.read(cardioTimerProvider.notifier).start(goalSeconds),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Icon(Icons.play_arrow, size: 56),
                ),
              ),

              const SizedBox(height: AthlosSpacing.xl),

              TextButton(
                onPressed: () => setState(() => _viewMode = _ViewMode.focused),
                child: Text(l10n.cardioManualEntry),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardioRunning(
      ActiveExecutionState exec, CardioTimerState cardioState) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final hasReachedGoal = cardioState.hasReachedGoal;
    final isPaused = cardioState.isPaused;

    final timerColor = isPaused
        ? colorScheme.onSurfaceVariant
        : hasReachedGoal
            ? colorScheme.primary
            : colorScheme.onSurface;

    return Scaffold(
      backgroundColor:
          isPaused ? colorScheme.surfaceContainerHighest : null,
      appBar: _cardioAppBar(name, sets.length),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),

            if (hasReachedGoal) _goalReachedBadge(),

            if (isPaused)
              Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                child: Text(
                  l10n.cardioPaused,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            Text(
              formatDuration(cardioState.elapsedSeconds),
              style: textTheme.displayLarge?.copyWith(
                fontSize: 72,
                fontWeight: FontWeight.w300,
                color: timerColor,
              ),
            ),

            if (hasReachedGoal && cardioState.overtimeSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: AthlosSpacing.xs),
                child: Text(
                  '+${formatDuration(cardioState.overtimeSeconds)}',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: AthlosSpacing.lg),

            if (cardioState.goalSeconds > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.xxl),
                child: LinearProgressIndicator(
                  value: cardioState.progress,
                  borderRadius: AthlosRadius.fullAll,
                  minHeight: 6,
                  color: hasReachedGoal ? colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: AthlosSpacing.sm),
              Text(
                l10n.cardioGoalLabel(
                    formatDuration(cardioState.goalSeconds)),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const Spacer(flex: 3),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPaused)
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(cardioTimerProvider.notifier).resume(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.cardioResume),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.read(cardioTimerProvider.notifier).pause(),
                    icon: const Icon(Icons.pause),
                    label: Text(l10n.cardioPause),
                  ),
                const SizedBox(width: AthlosSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(cardioTimerProvider.notifier).stop();
                    setState(() {
                      _currentDuration = cardioState.elapsedSeconds;
                    });
                  },
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.cardioStop),
                ),
              ],
            ),

            const SizedBox(height: AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioFinishing(
      ActiveExecutionState exec, CardioTimerState cardioState) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return Scaffold(
      appBar: _cardioAppBar(name, sets.length),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),

            if (cardioState.hasReachedGoal)
              _goalReachedBadge(bottomMargin: AthlosSpacing.lg),

            _NumberInput(
              value: _currentDuration.toDouble(),
              suffix: l10n.cardioDurationLabel,
              step: 30,
              onChanged: (v) =>
                  setState(() => _currentDuration = v.toInt()),
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),

            const SizedBox(height: AthlosSpacing.sm),

            Text(
              formatDuration(_currentDuration),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: AthlosSpacing.xl),

            _NumberInput(
              value: _currentDistance,
              suffix: l10n.cardioDistanceOptional,
              step: 100,
              onChanged: (v) =>
                  setState(() => _currentDistance = v),
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),

            const Spacer(flex: 3),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _onCompleteCardioSet(exec),
                icon: const Icon(Icons.check),
                label: Text(
                  l10n.cardioSaveSet,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioCompleted(
      ActiveExecutionState exec, List<SetEntry> sets) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final name = _exerciseName(exercise.exerciseId);
    final nextInExercise = sets
        .where(
            (s) => !s.isCompleted && s.setNumber > _focusedSetNumber)
        .toList();

    return Scaffold(
      appBar: _cardioAppBar(name, sets.length,
          onBack: () => setState(() => _viewMode = _ViewMode.overview)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle,
                size: 64, color: colorScheme.primary),
            const SizedBox(height: AthlosSpacing.lg),
            Text(
              l10n.restComplete,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: AthlosSpacing.xl),
            if (nextInExercise.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _goToFocused(exec, _focusedExerciseIndex,
                    nextInExercise.first.setNumber),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.nextSetLabel),
              )
            else
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _viewMode = _ViewMode.overview),
                icon: const Icon(Icons.list_alt),
                label: Text(l10n.backToOverview),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onCompleteSet(ActiveExecutionState exec) async {
    final exercise = exec.exercises[_focusedExerciseIndex];
    final isCardio = _isFocusedCardio(exec);

    if (!isCardio && _currentReps <= 0) return;

    final segments = isCardio || _dropSegments.isEmpty
        ? <SegmentEntry>[]
        : [
            SegmentEntry(
              reps: _currentReps,
              weight: _currentWeight > 0 ? _currentWeight : null,
            ),
            ..._dropSegments
                .map((d) => SegmentEntry(reps: d.reps, weight: d.weight)),
          ];

    final int rest;
    try {
      rest = await ref.read(activeExecutionProvider.notifier).completeSet(
            exercise.exerciseId,
            _focusedSetNumber,
            reps: isCardio ? null : _currentReps,
            weight:
                isCardio ? null : (_currentWeight > 0 ? _currentWeight : null),
            duration: isCardio ? _currentDuration : null,
            distance:
                isCardio ? (_currentDistance > 0 ? _currentDistance : null) : null,
            segments: segments.isEmpty ? null : segments,
          );
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final updatedExec = ref.read(activeExecutionProvider);
    if (updatedExec == null) return;

    final nextInGroup = _nextInSupersetGroup(
        updatedExec, _focusedExerciseIndex, _focusedSetNumber);
    if (nextInGroup != null) {
      _goToFocused(updatedExec, nextInGroup, _focusedSetNumber);
      return;
    }

    if (rest > 0) {
      ref.read(restTimerProvider.notifier).start(rest);
      setState(() => _viewMode = _ViewMode.timer);
    } else {
      final next = _findNextPendingSet(updatedExec);
      if (next != null) {
        _goToFocused(updatedExec, next.$1, next.$2);
      } else {
        setState(() => _viewMode = _ViewMode.overview);
      }
    }
  }

  Future<void> _onCompleteCardioSet(ActiveExecutionState exec) async {
    final exercise = exec.exercises[_focusedExerciseIndex];

    final int rest;
    try {
      rest = await ref.read(activeExecutionProvider.notifier).completeSet(
            exercise.exerciseId,
            _focusedSetNumber,
            duration: _currentDuration > 0 ? _currentDuration : null,
            distance:
                _currentDistance > 0 ? _currentDistance : null,
          );
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    ref.read(cardioTimerProvider.notifier).reset();

    final updatedExec = ref.read(activeExecutionProvider);
    if (updatedExec == null) return;

    if (rest > 0) {
      ref.read(restTimerProvider.notifier).start(rest);
      setState(() => _viewMode = _ViewMode.timer);
    } else {
      final next = _findNextPendingSet(updatedExec);
      if (next != null) {
        _goToFocused(updatedExec, next.$1, next.$2);
      } else {
        setState(() => _viewMode = _ViewMode.overview);
      }
    }
  }

  Future<void> _onFinish(BuildContext context) async {
    try {
      await ref.read(activeExecutionProvider.notifier).finishExecution();
      ref.read(restTimerProvider.notifier).reset();
      ref.read(cardioTimerProvider.notifier).reset();
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workoutFinished)),
        );
        context.pop();
      }
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelExecution),
        content: Text(l10n.cancelExecutionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.back),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(activeExecutionProvider.notifier)
                    .cancelExecution();
                ref.read(restTimerProvider.notifier).reset();
                ref.read(cardioTimerProvider.notifier).reset();
                if (context.mounted) context.pop();
              } on Exception catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.genericError),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.cancelExecution),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Overview Exercise Card
// =============================================================================

class _OverviewExerciseCard extends StatelessWidget {
  final String exerciseName;
  final String muscleGroup;
  final int completedSets;
  final int totalSets;
  final bool isAllDone;
  final bool isActive;
  final bool isGroupedWithPrevious;
  final bool isGroupedWithNext;
  final int? groupColorIndex;
  final VoidCallback onTap;

  const _OverviewExerciseCard({
    required this.exerciseName,
    required this.muscleGroup,
    required this.completedSets,
    required this.totalSets,
    required this.isAllDone,
    required this.isActive,
    this.isGroupedWithPrevious = false,
    this.isGroupedWithNext = false,
    this.groupColorIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isInGroup = isGroupedWithPrevious || isGroupedWithNext;

    final groupColor =
        isInGroup && groupColorIndex != null
            ? supersetColorFor(groupColorIndex!, colorScheme)
            : null;

    final IconData statusIcon;
    final Color statusColor;
    if (isAllDone) {
      statusIcon = Icons.check_circle;
      statusColor = colorScheme.primary;
    } else if (isActive) {
      statusIcon = Icons.play_circle_filled;
      statusColor = colorScheme.tertiary;
    } else {
      statusIcon = Icons.radio_button_unchecked;
      statusColor = colorScheme.onSurfaceVariant;
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: AthlosSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isInGroup &&
                        !isGroupedWithPrevious &&
                        groupColor != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: AthlosSpacing.xs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.xs,
                            vertical: AthlosSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.15),
                            borderRadius: AthlosRadius.xsAll,
                            border: Border.all(
                              color: groupColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link,
                                  size: 10, color: groupColor),
                              const SizedBox(width: AthlosSpacing.xs),
                              Text(
                                l10n.supersetLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: groupColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        exerciseName,
                        style: textTheme.titleSmall?.copyWith(
                          decoration:
                              isAllDone ? TextDecoration.lineThrough : null,
                          color:
                              isAllDone ? colorScheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (muscleGroup.isNotEmpty)
                  Text(
                    muscleGroup,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.sm,
              vertical: AthlosSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isAllDone
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: AthlosRadius.fullAll,
            ),
            child: Text(
              l10n.exerciseProgress(completedSets, totalSets),
              style: textTheme.labelSmall?.copyWith(
                color: isAllDone
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AthlosSpacing.xs),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    BorderSide? cardBorder;
    if (isActive) {
      cardBorder = BorderSide(color: colorScheme.tertiary, width: 1.5);
    } else if (groupColor != null) {
      cardBorder = BorderSide(color: groupColor.withValues(alpha: 0.4));
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      shape: cardBorder != null
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: cardBorder,
            )
          : null,
      child: Container(
        decoration: groupColor != null
            ? BoxDecoration(
                borderRadius: AthlosRadius.mdAll,
                border: Border(
                  left: BorderSide(color: groupColor, width: 4),
                ),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AthlosRadius.mdAll,
          child: content,
        ),
      ),
    );
  }
}

// =============================================================================
// Number Input with +/- buttons
// =============================================================================

class _NumberInput extends StatelessWidget {
  final double value;
  final String suffix;
  final double step;
  final ValueChanged<double> onChanged;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Color? valueColor;

  const _NumberInput({
    required this.value,
    required this.suffix,
    required this.step,
    required this.onChanged,
    required this.textTheme,
    required this.colorScheme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue =
        value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: Icons.remove,
          onPressed: value > 0
              ? () => onChanged((value - step).clamp(0, 9999))
              : null,
          colorScheme: colorScheme,
        ),
        const SizedBox(width: AthlosSpacing.lg),
        GestureDetector(
          onTap: () => _showEditDialog(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayValue,
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
              Text(
                suffix,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AthlosSpacing.lg),
        _CircleButton(
          icon: Icons.add,
          onPressed: () => onChanged(value + step),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: value % 1 == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(1),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suffix),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final parsed = double.tryParse(v);
            Navigator.pop(ctx, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              Navigator.pop(ctx, parsed);
            },
            child: Text(AppLocalizations.of(ctx)!.okButton),
          ),
        ],
      ),
    );

    if (result != null) onChanged(result.clamp(0, 9999));
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: onPressed != null
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerHighest.withAlpha(100),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Icon(
            icon,
            color: onPressed != null
                ? colorScheme.onSurface
                : colorScheme.onSurface.withAlpha(80),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _DropSegmentInput {
  final int reps;
  final double weight;

  const _DropSegmentInput({required this.reps, required this.weight});

  _DropSegmentInput copyWith({int? reps, double? weight}) =>
      _DropSegmentInput(
        reps: reps ?? this.reps,
        weight: weight ?? this.weight,
      );
}

class _DropSegmentRow extends StatefulWidget {
  final int index;
  final _DropSegmentInput segment;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onRemove;

  const _DropSegmentRow({
    required this.index,
    required this.segment,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onRemove,
  });

  @override
  State<_DropSegmentRow> createState() => _DropSegmentRowState();
}

class _DropSegmentRowState extends State<_DropSegmentRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.segment.weight > 0
          ? widget.segment.weight
              .toStringAsFixed(widget.segment.weight % 1 == 0 ? 0 : 1)
          : '',
    );
    _repsController = TextEditingController(
      text: widget.segment.reps.toString(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.arrow_downward,
              size: 18, color: widget.colorScheme.tertiary),
          const SizedBox(width: AthlosSpacing.xs),
          Text(
            widget.l10n.dropSetSegment(widget.index + 2),
            style: widget.textTheme.labelMedium?.copyWith(
              color: widget.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AthlosSpacing.sm),
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                labelText: widget.l10n.weightKgSuffix,
                labelStyle: widget.textTheme.labelSmall,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                  vertical: AthlosSpacing.sm,
                ),
              ),
              onChanged: (v) =>
                  widget.onWeightChanged(double.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: AthlosSpacing.sm),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                labelText: widget.l10n.repsShort,
                labelStyle: widget.textTheme.labelSmall,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                  vertical: AthlosSpacing.sm,
                ),
              ),
              onChanged: (v) =>
                  widget.onRepsChanged(int.tryParse(v) ?? widget.segment.reps),
            ),
          ),
          const SizedBox(width: AthlosSpacing.xs),
          IconButton(
            icon: Icon(Icons.close,
                size: 20, color: widget.colorScheme.error),
            onPressed: widget.onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
