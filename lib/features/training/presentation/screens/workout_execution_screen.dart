import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/services/rest_timer_notification_service.dart';
import '../../../../core/theme/athlos_button_insets.dart';
import '../../../../core/theme/athlos_button_sizes.dart';
import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_markdown_notes_card.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/entities/workout_exercise.dart';
import '../helpers/duration_format.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/rep_performance.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/cardio_timer_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../providers/program_notifier.dart';
import '../providers/rest_timer_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/workout_exercise_tile.dart' show supersetColorFor;

enum _ViewMode {
  overview,
  focused,
  timer,
  cardioTimer,
  timedSet,
  exerciseTransition,
}

enum _TimedSubState { ready, countdown, running, finishing }

/// Formats a completed set as "Wkg x R", duration, or drop set chain.
String _formatSetSummary(SetEntry set) {
  if (set.duration != null && set.reps == null) {
    final dur = formatDuration(set.duration!);
    final w = set.weight;
    if (w != null && w > 0) {
      return '${w.toStringAsFixed(w % 1 == 0 ? 0 : 1)}kg x $dur';
    }
    return dur;
  }

  String part(double? w, int r) {
    final weight = w ?? 0.0;
    return '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)}kg x $r';
  }

  if (set.isDropSet) {
    return set.segments.map((s) => part(s.weight, s.reps)).join(' → ');
  }
  return part(set.weight, set.reps ?? 0);
}

class WorkoutExecutionScreen extends ConsumerStatefulWidget {
  final int workoutId;

  const WorkoutExecutionScreen({super.key, required this.workoutId});

  @override
  ConsumerState<WorkoutExecutionScreen> createState() =>
      _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends ConsumerState<WorkoutExecutionScreen>
    with WidgetsBindingObserver {
  bool _isInitialized = false;
  _ViewMode _viewMode = _ViewMode.overview;
  bool _isInBackground = false;

  final _restTimerNotificationService = RestTimerNotificationService.instance;

  int _focusedExerciseIndex = 0;
  int _focusedSetNumber = 1;
  double _currentWeight = 0;
  int _currentReps = 0;
  int _leftReps = 0;
  double _leftWeight = 0;
  int _rightReps = 0;
  double _rightWeight = 0;
  int _currentDuration = 0;
  double _currentDistance = 0;
  int? _selectedRpe;
  bool _isUnilateral = false;
  String? _setNotes;
  bool _showNotesField = false;
  List<_DropSegmentInput> _dropSegments = [];
  _TimedSubState _timedSubState = _TimedSubState.ready;
  int _countdownValue = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restTimerNotificationService.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimerNotificationService.cancelAllForRestTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasInBackground = _isInBackground;
    if (state == AppLifecycleState.resumed) {
      ref.read(restTimerProvider.notifier).syncWithClock();
    }
    _isInBackground = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.inactive => false,
      _ => true,
    };

    if (_isInBackground == wasInBackground) return;
    _syncRestTimerNotification(next: ref.read(restTimerProvider));
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      workoutExercisesProvider(widget.workoutId),
    );
    final execState = ref.watch(activeExecutionProvider);
    final timerState = ref.watch(restTimerProvider);
    final cardioState = ref.watch(cardioTimerProvider);
    ref.watch(exerciseListProvider);
    ref.listen<RestTimerState>(restTimerProvider, (previous, next) {
      _syncRestTimerNotification(previous: previous, next: next);
    });

    if (!_isInitialized &&
        exercisesAsync is AsyncData<List<WorkoutExercise>> &&
        execState == null) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        final router = GoRouter.of(context);
        try {
          final programRepo = ref.read(programRepositoryProvider);
          final activeProgram = (await programRepo.getActive()).getOrThrow();
          if (activeProgram == null) throw Exception('No active program');
          final deloadConfig = activeProgram.isInDeload
              ? activeProgram.deloadConfig
              : null;
          final progressionRules = await ref
              .read(progressionRuleRepositoryProvider)
              .getByProgram(activeProgram.id)
              .then((r) => r.getOrThrow());
          final allExercises = ref.read(exerciseListProvider).value ?? [];
          final isometricIds = {
            for (final e in allExercises)
              if (e.isIsometric) e.id,
          };
          await ref
              .read(activeExecutionProvider.notifier)
              .startExecution(
                widget.workoutId,
                exercisesAsync.value,
                programId: activeProgram.id,
                deloadConfig: deloadConfig,
                progressionRules: progressionRules,
                defaultRestSeconds: activeProgram.defaultRestSeconds ?? 0,
                isometricExerciseIds: isometricIds,
              );
        } on Exception catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.genericError)));
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
        if (_viewMode == _ViewMode.timer) {
          _showSkipRestTimerDialog(context);
          return;
        }
        if (_viewMode == _ViewMode.focused ||
            _viewMode == _ViewMode.cardioTimer ||
            _viewMode == _ViewMode.timedSet ||
            _viewMode == _ViewMode.exerciseTransition) {
          ref.read(cardioTimerProvider.notifier).reset();
          setState(() => _viewMode = _ViewMode.overview);
        } else {
          _showCancelDialog(context);
        }
      },
      child: execState == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : switch (_viewMode) {
              _ViewMode.overview => _buildOverview(context, execState),
              _ViewMode.focused => _buildFocused(context, execState),
              _ViewMode.timer => _buildTimer(context, execState, timerState),
              _ViewMode.cardioTimer => _buildCardioTimer(
                context,
                execState,
                cardioState,
              ),
              _ViewMode.timedSet => _buildTimedSet(
                context,
                execState,
                cardioState,
              ),
              _ViewMode.exerciseTransition => _buildExerciseCompleteTransition(
                context,
                execState,
              ),
            },
    );
  }

  Future<void> _syncRestTimerNotification({
    RestTimerState? previous,
    required RestTimerState next,
  }) async {
    if (!_isInBackground) {
      if ((previous?.isActive ?? false) || next.isActive) {
        await _restTimerNotificationService.cancelAllForRestTimer();
      }
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final hasJustFinished =
        (previous?.remainingSeconds ?? 0) > 0 && next.remainingSeconds == 0;
    if (hasJustFinished) {
      if (_restTimerNotificationService.usesScheduledFinishAlert) {
        await _restTimerNotificationService.cancelScheduledRestFinished();
      } else {
        await _restTimerNotificationService.showRestFinished(
          title: l10n.restTimerDone,
          body: l10n.restComplete,
        );
      }
      return;
    }

    if (next.isRunning && next.remainingSeconds > 0) {
      if (_restTimerNotificationService.supportsFrequentOngoingUpdates) {
        await _restTimerNotificationService.showOngoingRest(
          title: l10n.restTimerLabel(next.remainingSeconds),
          body: l10n.nextSetLabel,
        );
      } else {
        final previousRemaining = previous?.remainingSeconds ?? 0;
        final wasRunning = previous?.isRunning ?? false;
        final hasRemaining = previousRemaining > 0;
        final startedOrResumed = !wasRunning || !hasRemaining;
        final wasExtended = next.remainingSeconds > (previousRemaining + 1);
        if (startedOrResumed || wasExtended) {
          await _restTimerNotificationService.showOngoingRest(
            title: l10n.restTimerLabel(next.remainingSeconds),
            body: l10n.nextSetLabel,
          );
          await _restTimerNotificationService.scheduleRestFinished(
            title: l10n.restTimerDone,
            body: l10n.restComplete,
            afterSeconds: next.remainingSeconds,
          );
        }
      }
      return;
    }

    if (_restTimerNotificationService.usesScheduledFinishAlert &&
        !next.isRunning &&
        next.remainingSeconds > 0) {
      await _restTimerNotificationService.cancelScheduledRestFinished();
      return;
    }

    if (!next.isActive) {
      await _restTimerNotificationService.cancelAllForRestTimer();
    }
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
    ActiveExecutionState exec,
  ) {
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
    ActiveExecutionState exec,
    int exerciseIndex,
  ) {
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
    ActiveExecutionState exec,
    int currentIndex,
    int setNumber,
  ) {
    final group = _getSupersetGroupIndices(exec, currentIndex);
    final currentPosInGroup = group.indexOf(currentIndex);
    for (var offset = 1; offset < group.length; offset++) {
      final nextIdx = group[(currentPosInGroup + offset) % group.length];
      final exId = exec.exercises[nextIdx].exerciseId;
      final sets = exec.exerciseSets[exId] ?? [];
      final match = sets.where(
        (s) => s.setNumber == setNumber && !s.isCompleted,
      );
      if (match.isNotEmpty) return nextIdx;
    }
    return null;
  }

  bool _isExerciseIsometric(int exerciseId) {
    final allExercises = ref.read(exerciseListProvider).value;
    return allExercises?.any((e) => e.id == exerciseId && e.isIsometric) ??
        false;
  }

  bool _isFocusedIsometric(ActiveExecutionState exec) =>
      _isExerciseIsometric(exec.exercises[_focusedExerciseIndex].exerciseId);

  bool _isFocusedCardio(ActiveExecutionState exec) =>
      exec.exercises[_focusedExerciseIndex].duration != null &&
      !_isFocusedIsometric(exec);

  void _goToFocused(
    ActiveExecutionState exec,
    int exerciseIndex, [
    int? setNumber,
  ]) {
    final exId = exec.exercises[exerciseIndex].exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];

    final targetSet =
        setNumber ??
        sets.where((s) => !s.isCompleted).map((s) => s.setNumber).firstOrNull ??
        1;

    final entry = sets.firstWhere(
      (s) => s.setNumber == targetSet,
      orElse: () => sets.first,
    );

    final prevCompleted = sets
        .where((s) => s.isCompleted && s.setNumber < targetSet)
        .toList();

    final isIsometric = _isExerciseIsometric(exId);
    final isCardio =
        exec.exercises[exerciseIndex].duration != null && !isIsometric;

    setState(() {
      _focusedExerciseIndex = exerciseIndex;
      _focusedSetNumber = targetSet;

      if (isIsometric) {
        _viewMode = _ViewMode.timedSet;
        _timedSubState = _TimedSubState.ready;
        _currentDuration =
            entry.duration ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.duration ?? 0
                : exec.exercises[exerciseIndex].duration ?? 0);
        _currentWeight =
            entry.weight ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.weight ?? 0
                : entry.plannedWeight ?? 0);
        ref.read(cardioTimerProvider.notifier).reset();
      } else if (isCardio) {
        _viewMode = _ViewMode.cardioTimer;
        _currentDuration =
            entry.duration ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.duration ?? 0
                : exec.exercises[exerciseIndex].duration ?? 0);
        _currentDistance =
            entry.distance ??
            (prevCompleted.isNotEmpty ? prevCompleted.last.distance ?? 0 : 0);
        ref.read(cardioTimerProvider.notifier).reset();
      } else {
        _viewMode = _ViewMode.focused;
        _currentWeight =
            entry.weight ??
            (prevCompleted.isNotEmpty
                ? prevCompleted.last.weight ?? 0
                : entry.plannedWeight ?? 0);
        _currentReps = prevCompleted.isNotEmpty
            ? prevCompleted.last.reps ?? entry.reps ?? 0
            : entry.reps ?? 0;
      }
      _selectedRpe = entry.rpe;
      _setNotes = entry.notes;
      _showNotesField = entry.notes != null && entry.notes!.isNotEmpty;
      _dropSegments = entry.segments
          .skip(1)
          .map((s) => _DropSegmentInput(reps: s.reps, weight: s.weight ?? 0))
          .toList();

      _isUnilateral = exec.exercises[exerciseIndex].isUnilateral;
      _leftReps = entry.leftReps ?? _currentReps;
      _leftWeight = entry.leftWeight ?? _currentWeight;
      _rightReps = entry.rightReps ?? _currentReps;
      _rightWeight = entry.rightWeight ?? _currentWeight;
    });
  }

  void _goToNextSetFromTimer(ActiveExecutionState exec) {
    ref.read(restTimerProvider.notifier).reset();
    final currentExercise = exec.exercises[_focusedExerciseIndex];
    final groupId = currentExercise.groupId;

    if (groupId != null) {
      final groupIndices = _getSupersetGroupIndices(
        exec,
        _focusedExerciseIndex,
      );
      final groupNext = <(int exerciseIndex, int setNumber)>[];

      for (final index in groupIndices) {
        final exId = exec.exercises[index].exerciseId;
        final sets = exec.exerciseSets[exId] ?? [];
        final firstPending = sets.where((s) => !s.isCompleted).firstOrNull;
        if (firstPending != null) {
          groupNext.add((index, firstPending.setNumber));
        }
      }

      if (groupNext.isNotEmpty) {
        groupNext.sort((a, b) {
          final bySet = a.$2.compareTo(b.$2);
          if (bySet != 0) return bySet;
          return a.$1.compareTo(b.$1);
        });
        _goToFocused(exec, groupNext.first.$1, groupNext.first.$2);
        return;
      }
    }

    final exId = currentExercise.exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];
    final nextInExercise = sets
        .where((s) => !s.isCompleted && s.setNumber > _focusedSetNumber)
        .toList();

    if (nextInExercise.isNotEmpty) {
      _goToFocused(exec, _focusedExerciseIndex, nextInExercise.first.setNumber);
      return;
    }

    final globalNext = _findNextPendingSet(exec);
    if (globalNext != null) {
      _goToFocused(exec, globalNext.$1, globalNext.$2);
    } else {
      setState(() => _viewMode = _ViewMode.overview);
    }
  }

  void _returnToOverviewFromTimer() {
    ref.read(restTimerProvider.notifier).reset();
    setState(() => _viewMode = _ViewMode.overview);
  }

  void _goToNextExerciseOrOverview(ActiveExecutionState exec) {
    ref.read(restTimerProvider.notifier).reset();
    final next = _findNextPendingSet(exec);
    if (next != null) {
      _goToFocused(exec, next.$1, next.$2);
    } else {
      setState(() => _viewMode = _ViewMode.overview);
    }
  }

  bool _isExerciseComplete(ActiveExecutionState exec) {
    final exId = exec.exercises[_focusedExerciseIndex].exerciseId;
    final sets = exec.exerciseSets[exId] ?? [];
    return sets.every((s) => s.isCompleted);
  }

  void _navigateAfterSet(ActiveExecutionState exec, int rest) {
    final hasMoreWork = _findNextPendingSet(exec) != null;

    if (rest > 0 && hasMoreWork) {
      ref.read(restTimerProvider.notifier).start(rest);
      setState(() => _viewMode = _ViewMode.timer);
    } else if (_isExerciseComplete(exec)) {
      setState(() => _viewMode = _ViewMode.exerciseTransition);
    } else {
      final next = _findNextPendingSet(exec);
      if (next != null) {
        _goToFocused(exec, next.$1, next.$2);
      } else {
        setState(() => _viewMode = _ViewMode.overview);
      }
    }
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
    final workoutNotes = workoutAsync.value?.description?.trim();
    final completed = exec.completedSetCount;
    final total = _totalSetCount;
    final next = _findNextPendingSet(exec);

    return Scaffold(
      appBar: AppBar(
        title: AthlosTruncatedText(l10n.executionTitle(workoutName)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _showCancelDialog(context),
            child: Text(l10n.cancelExecution),
          ),
        ],
      ),
      body: Column(
        children: [
          if (exec.isDeload)
            Container(
              width: double.infinity,
              color: colorScheme.tertiaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AthlosSpacing.md,
                vertical: AthlosSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.spa,
                    size: 16,
                    color: colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: AthlosSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.deloadActiveChip,
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (workoutNotes != null && workoutNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AthlosSpacing.md,
                AthlosSpacing.sm,
                AthlosSpacing.md,
                AthlosSpacing.xs,
              ),
              child: AthlosMarkdownNotesCard(
                title: l10n.workoutNotesTitle,
                markdown: workoutNotes,
              ),
            ),

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
                      Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
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
            child: Builder(
              builder: (context) {
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
                    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
                    final completedSets = sets
                        .where((s) => s.isCompleted)
                        .length;
                    final totalSets = sets.length;
                    final isAllDone = completedSets == totalSets;
                    final isActive = next != null && next.$1 == index;

                    final gid = exercise.groupId;
                    final isGroupedWithPrev =
                        index > 0 &&
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
                      isUnilateral: exercise.isUnilateral,
                      isGroupedWithPrevious: isGroupedWithPrev,
                      isGroupedWithNext: isGroupedWithNext,
                      groupColorIndex: gid != null ? groupColorMap[gid] : null,
                      onTap: () => _goToFocused(exec, index),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (next != null) ...[
                    AthlosStackedActions(
                      spacing: AthlosSpacing.sm,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed:
                                exec.hasCompletedSets && !exec.isFinishing
                                ? () => _showFinishWorkoutIncompleteDialog(
                                    context,
                                  )
                                : null,
                            style:
                                TextButton.styleFrom(
                                  padding: AthlosButtonInsets.screen,
                                  minimumSize: const Size(
                                    AthlosButtonSizes.minWidth,
                                    AthlosButtonSizes.screenMinHeight,
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ).merge(
                                  Theme.of(context).textButtonTheme.style ??
                                      const ButtonStyle(),
                                ),
                            icon: exec.isFinishing
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(l10n.finishWorkout),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _goToFocused(exec, next.$1, next.$2),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              l10n.nextSetButton(
                                _exerciseName(
                                  exec.exercises[next.$1].exerciseId,
                                ),
                                next.$2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: exec.hasCompletedSets && !exec.isFinishing
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
        .where((s) => s.isCompleted && s.setNumber < _focusedSetNumber)
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
        title: AthlosTruncatedText(name),
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
            if (group.isNotEmpty || exercise.isUnilateral)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (group.isNotEmpty)
                    Text(
                      group,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (exercise.isUnilateral) ...[
                    if (group.isNotEmpty)
                      const SizedBox(width: AthlosSpacing.sm),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isUnilateral = !_isUnilateral;
                        if (_isUnilateral) {
                          _leftReps = _currentReps;
                          _leftWeight = _currentWeight;
                          _rightReps = _currentReps;
                          _rightWeight = _currentWeight;
                        } else {
                          _currentReps = _leftReps;
                          _currentWeight = _leftWeight;
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AthlosSpacing.sm,
                          vertical: AthlosSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: _isUnilateral
                              ? colorScheme.secondaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: AthlosRadius.fullAll,
                          border: Border.all(
                            color: _isUnilateral
                                ? colorScheme.secondary.withValues(alpha: 0.5)
                                : colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              size: 14,
                              color: _isUnilateral
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AthlosSpacing.xs),
                            Text(
                              l10n.unilateralLabel,
                              style: textTheme.labelMedium?.copyWith(
                                color: _isUnilateral
                                    ? colorScheme.onSecondaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (exercise.notes != null && exercise.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AthlosSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AthlosSpacing.xs),
                    Flexible(
                      child: AthlosTruncatedText(
                        exercise.notes!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),

            if (_isFocusedCardio(exec)) ...[
              // Duration input
              _NumberInput(
                value: _currentDuration.toDouble(),
                suffix: l10n.durationSecondsSuffix,
                step: 30,
                onChanged: (v) => setState(() => _currentDuration = v.toInt()),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: AthlosSpacing.xl),

              // Distance input
              _NumberInput(
                value: _currentDistance,
                suffix: l10n.distanceMetersSuffix,
                step: 100,
                onChanged: (v) => setState(() => _currentDistance = v),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            ] else if (!_isUnilateral) ...[
              // Bilateral: standard weight + reps inputs
              _NumberInput(
                value: _currentWeight,
                suffix: l10n.weightKgSuffix,
                step: 2.5,
                onChanged: (v) => setState(() => _currentWeight = v),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: AthlosSpacing.xl),

              _NumberInput(
                value: _currentReps.toDouble(),
                suffix: l10n.repsShort,
                step: 1,
                onChanged: (v) => setState(() => _currentReps = v.toInt()),
                textTheme: textTheme,
                colorScheme: colorScheme,
                valueColor: repsDeviationColor(
                  colorScheme,
                  Theme.of(context).extension<AthlosCustomColors>()!,
                  _currentReps,
                  exercise.minReps ?? 0,
                  exercise.maxReps ?? 0,
                  exercise.isAmrap,
                ),
              ),

              const SizedBox(height: AthlosSpacing.md),
            ] else ...[
              // Unilateral: shared weight, per-side reps
              _NumberInput(
                value: _leftWeight,
                suffix: l10n.weightKgSuffix,
                step: 2.5,
                onChanged: (v) => setState(() {
                  _leftWeight = v;
                  _rightWeight = v;
                }),
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),

              const SizedBox(height: AthlosSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l10n.leftSideLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AthlosSpacing.xs),
                        _NumberInput(
                          value: _leftReps.toDouble(),
                          suffix: l10n.repsShort,
                          step: 1,
                          compact: true,
                          onChanged: (v) =>
                              setState(() => _leftReps = v.toInt()),
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                          valueColor: repsDeviationColor(
                            colorScheme,
                            Theme.of(context).extension<AthlosCustomColors>()!,
                            _leftReps,
                            exercise.minReps ?? 0,
                            exercise.maxReps ?? 0,
                            exercise.isAmrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AthlosSpacing.sm),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l10n.rightSideLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AthlosSpacing.xs),
                        _NumberInput(
                          value: _rightReps.toDouble(),
                          suffix: l10n.repsShort,
                          step: 1,
                          compact: true,
                          onChanged: (v) =>
                              setState(() => _rightReps = v.toInt()),
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                          valueColor: repsDeviationColor(
                            colorScheme,
                            Theme.of(context).extension<AthlosCustomColors>()!,
                            _rightReps,
                            exercise.minReps ?? 0,
                            exercise.maxReps ?? 0,
                            exercise.isAmrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AthlosSpacing.md),

              // Drop set segments
              if (_dropSegments.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: AthlosSpacing.xs),
                  padding: const EdgeInsets.all(AthlosSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
                    borderRadius: AthlosRadius.mdAll,
                    border: Border.all(
                      color: colorScheme.tertiary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var idx = 0; idx < _dropSegments.length; idx++)
                        _DropSegmentRow(
                          index: idx,
                          segment: _dropSegments[idx],
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                          l10n: l10n,
                          onWeightChanged: (w) => setState(
                            () => _dropSegments[idx] = _dropSegments[idx]
                                .copyWith(weight: w),
                          ),
                          onRepsChanged: (r) => setState(
                            () => _dropSegments[idx] = _dropSegments[idx]
                                .copyWith(reps: r),
                          ),
                          onRemove: () =>
                              setState(() => _dropSegments.removeAt(idx)),
                        ),
                    ],
                  ),
                ),

              // Add drop set button
              if (!currentSetEntry.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: AthlosSpacing.xs),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _dropSegments.add(
                          _DropSegmentInput(
                            reps: (_currentReps * 0.5).ceil(),
                            weight: _currentWeight * 0.8,
                          ),
                        );
                      });
                    },
                    icon: Icon(
                      Icons.arrow_downward,
                      size: 16,
                      color: colorScheme.tertiary,
                    ),
                    label: Text(l10n.addDropSet),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.tertiary,
                      side: BorderSide(
                        color: colorScheme.tertiary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
            ],

            const Spacer(),

            // Previous set reference (strength only)
            if (prevSet != null && !_isFocusedCardio(exec))
              Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
                child: Text(
                  l10n.previousSetRef(_formatSetSummary(prevSet)),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // Notes toggle + RPE selector
            Padding(
              padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showNotesField = !_showNotesField),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.sm,
                        vertical: AthlosSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: _showNotesField
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: AthlosRadius.fullAll,
                        border: Border.all(
                          color: _showNotesField
                              ? colorScheme.secondary.withValues(alpha: 0.5)
                              : colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.note_alt_outlined,
                        size: 14,
                        color: _showNotesField
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!_isFocusedCardio(exec)) ...[
                    const SizedBox(width: AthlosSpacing.md),
                    Expanded(
                      child: _RpeSelector(
                        value: _selectedRpe,
                        onChanged: (v) => setState(() => _selectedRpe = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_showNotesField)
              Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.setNotesHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.sm,
                      vertical: AthlosSpacing.sm,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  controller: TextEditingController(text: _setNotes),
                  onChanged: (v) => _setNotes = v,
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
                    final nextInExercise = sets
                        .where(
                          (s) =>
                              !s.isCompleted && s.setNumber > _focusedSetNumber,
                        )
                        .toList();
                    if (nextInExercise.isNotEmpty) {
                      _goToFocused(
                        exec,
                        _focusedExerciseIndex,
                        nextInExercise.first.setNumber,
                      );
                    } else {
                      setState(() => _viewMode = _ViewMode.exerciseTransition);
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

    final focusedExId = exec.exercises[_focusedExerciseIndex].exerciseId;
    final focusedSets = exec.exerciseSets[focusedExId] ?? [];
    final nextInFocused = focusedSets.cast<SetEntry?>().firstWhere(
      (s) => !s!.isCompleted,
      orElse: () => null,
    );

    final String nextLabel;
    if (nextInFocused != null) {
      nextLabel = l10n.nextUpLabel(
        _exerciseName(focusedExId),
        nextInFocused.setNumber,
      );
    } else {
      final next = _findNextPendingSet(exec);
      nextLabel = next != null
          ? l10n.nextUpLabel(
              _exerciseName(exec.exercises[next.$1].exerciseId),
              next.$2,
            )
          : l10n.allSetsComplete;
    }

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
                horizontal: AthlosSpacing.xxl,
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.xl),
              child: AthlosStackedActions(
                spacing: AthlosSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ref.read(restTimerProvider.notifier).addTime(15);
                    },
                    child: Text(l10n.addTimeButton),
                  ),
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
    final hasMoreSetsInExercise = sets.any(
      (s) => !s.isCompleted && s.setNumber > _focusedSetNumber,
    );

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
              padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.xl),
              child: hasMoreSetsInExercise
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _goToNextSetFromTimer(exec),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l10n.nextSetLabel),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(restTimerProvider.notifier).reset();
                              _goToNextExerciseOrOverview(exec);
                            },
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(l10n.nextExerciseButton),
                          ),
                        ),
                        const SizedBox(height: AthlosSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _returnToOverviewFromTimer(),
                            icon: const Icon(Icons.list_alt),
                            label: Text(l10n.backToOverview),
                          ),
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
      minReps: exercise.minReps ?? 0,
      maxReps: exercise.maxReps ?? 0,
      isAmrap: exercise.isAmrap,
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
  // View: Exercise Complete Transition
  // ---------------------------------------------------------------------------

  Widget _buildExerciseCompleteTransition(
    BuildContext context,
    ActiveExecutionState exec,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              l10n.exerciseCompleteMessage,
              style: textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),

            ?_buildLoadFeedback(exec, context),

            const Spacer(flex: 3),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.xl),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _goToNextExerciseOrOverview(exec),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.nextExerciseButton),
                    ),
                  ),
                  const SizedBox(height: AthlosSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(restTimerProvider.notifier).reset();
                        setState(() => _viewMode = _ViewMode.overview);
                      },
                      icon: const Icon(Icons.list_alt),
                      label: Text(l10n.backToOverview),
                    ),
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

  // ---------------------------------------------------------------------------
  // View 4: Cardio Timer
  // ---------------------------------------------------------------------------

  void _exitCardioTimer() {
    ref.read(cardioTimerProvider.notifier).reset();
    setState(() => _viewMode = _ViewMode.overview);
  }

  PreferredSizeWidget _cardioAppBar(
    String name,
    int totalSets, {
    VoidCallback? onBack,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack ?? _exitCardioTimer,
      ),
      title: AthlosTruncatedText(name),
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
          Icon(
            Icons.check_circle,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
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
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
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
      backgroundColor: isPaused ? colorScheme.surfaceContainerHighest : null,
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
                  horizontal: AthlosSpacing.xxl,
                ),
                child: LinearProgressIndicator(
                  value: cardioState.progress,
                  borderRadius: AthlosRadius.fullAll,
                  minHeight: 6,
                  color: hasReachedGoal ? colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: AthlosSpacing.sm),
              Text(
                l10n.cardioGoalLabel(formatDuration(cardioState.goalSeconds)),
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
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
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
              onChanged: (v) => setState(() => _currentDuration = v.toInt()),
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
              onChanged: (v) => setState(() => _currentDistance = v),
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

  Widget _buildCardioCompleted(ActiveExecutionState exec, List<SetEntry> sets) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final name = _exerciseName(exercise.exerciseId);
    final nextInExercise = sets
        .where((s) => !s.isCompleted && s.setNumber > _focusedSetNumber)
        .toList();

    return Scaffold(
      appBar: _cardioAppBar(
        name,
        sets.length,
        onBack: () => setState(() => _viewMode = _ViewMode.overview),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: colorScheme.primary),
            const SizedBox(height: AthlosSpacing.lg),
            Text(l10n.restComplete, style: textTheme.headlineSmall),
            const SizedBox(height: AthlosSpacing.xl),
            if (nextInExercise.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _goToFocused(
                  exec,
                  _focusedExerciseIndex,
                  nextInExercise.first.setNumber,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.nextSetLabel),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _goToNextExerciseOrOverview(exec),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.nextExerciseButton),
              ),
              const SizedBox(height: AthlosSpacing.md),
              OutlinedButton.icon(
                onPressed: () => setState(() => _viewMode = _ViewMode.overview),
                icon: const Icon(Icons.list_alt),
                label: Text(l10n.backToOverview),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View: Timed Set (Isometric)
  // ---------------------------------------------------------------------------

  Widget _buildTimedSet(
    BuildContext context,
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final currentSetEntry = sets.firstWhere(
      (s) => s.setNumber == _focusedSetNumber,
      orElse: () => sets.first,
    );

    if (currentSetEntry.isCompleted) {
      return _buildTimedCompleted(exec, sets);
    }

    return switch (_timedSubState) {
      _TimedSubState.ready => _buildTimedReady(exec),
      _TimedSubState.countdown => _buildTimedCountdown(exec),
      _TimedSubState.running => _buildTimedRunning(exec, cardioState),
      _TimedSubState.finishing => _buildTimedFinishing(exec, cardioState),
    };
  }

  PreferredSizeWidget _timedAppBar(
    String name,
    int totalSets, {
    VoidCallback? onBack,
  }) => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed:
          onBack ??
          () {
            ref.read(cardioTimerProvider.notifier).reset();
            setState(() => _viewMode = _ViewMode.overview);
          },
    ),
    title: AthlosTruncatedText(name),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: AthlosSpacing.md),
        child: Center(
          child: Text(
            '$_focusedSetNumber / $totalSets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    ],
  );

  Widget _buildTimedReady(ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final goalSeconds = exercise.duration ?? 0;

    return Scaffold(
      appBar: _timedAppBar(name, sets.length),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              if (goalSeconds > 0) ...[
                Text(
                  l10n.isometricGoalLabel(formatDuration(goalSeconds)),
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
                  onPressed: () {
                    setState(() {
                      _timedSubState = _TimedSubState.countdown;
                      _countdownValue = 3;
                    });
                    _startCountdown(exec);
                  },
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    l10n.isometricStart,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),

              const SizedBox(height: AthlosSpacing.xl),

              TextButton(
                onPressed: () => setState(() => _viewMode = _ViewMode.focused),
                child: Text(l10n.isometricManualEntry),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  void _startCountdown(ActiveExecutionState exec) {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _viewMode != _ViewMode.timedSet) return;
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        _startCountdown(exec);
      } else {
        final exercise = exec.exercises[_focusedExerciseIndex];
        final goalSeconds = exercise.duration ?? 0;
        ref.read(cardioTimerProvider.notifier).start(goalSeconds);
        setState(() => _timedSubState = _TimedSubState.running);
      }
    });
  }

  Widget _buildTimedCountdown(ActiveExecutionState exec) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return Scaffold(
      appBar: _timedAppBar(name, sets.length),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_countdownValue',
              style: textTheme.displayLarge?.copyWith(
                fontSize: 120,
                fontWeight: FontWeight.w200,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimedRunning(
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final hasReachedGoal = cardioState.hasReachedGoal;

    final timerColor = hasReachedGoal
        ? colorScheme.primary
        : colorScheme.onSurface;

    return Scaffold(
      appBar: _timedAppBar(name, sets.length),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),

            if (hasReachedGoal) _goalReachedBadge(),

            Text(
              formatDuration(cardioState.elapsedSeconds),
              style: textTheme.displayLarge?.copyWith(
                fontSize: 72,
                fontWeight: FontWeight.w300,
                color: timerColor,
              ),
            ),

            const SizedBox(height: AthlosSpacing.lg),

            if (cardioState.goalSeconds > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.xxl,
                ),
                child: LinearProgressIndicator(
                  value: cardioState.progress,
                  borderRadius: AthlosRadius.fullAll,
                  minHeight: 6,
                  color: hasReachedGoal ? colorScheme.primary : null,
                ),
              ),
              const SizedBox(height: AthlosSpacing.sm),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.isometricGoalLabel(
                        formatDuration(cardioState.goalSeconds),
                      ),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasReachedGoal && cardioState.overtimeSeconds > 0) ...[
                      TextSpan(
                        text: ' · ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: l10n.isometricOverGoal(
                          formatDuration(cardioState.overtimeSeconds),
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const Spacer(flex: 3),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(cardioTimerProvider.notifier).stop();
                  setState(() {
                    _currentDuration = cardioState.elapsedSeconds;
                    _timedSubState = _TimedSubState.finishing;
                  });
                },
                icon: const Icon(Icons.stop),
                label: Text(
                  l10n.isometricFinish,
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

  Widget _buildTimedFinishing(
    ActiveExecutionState exec,
    CardioTimerState cardioState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>()!;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.exerciseId] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final goalSeconds = exercise.duration ?? 0;

    final diff = goalSeconds > 0 ? _currentDuration - goalSeconds : 0;
    final Color? diffColor;
    final String diffLabel;
    if (diff > 0) {
      diffColor = colorScheme.primary;
      diffLabel = l10n.isometricOverGoal(formatDuration(diff));
    } else if (diff < 0) {
      final absDiff = diff.abs();
      diffColor = absDiff >= 10 ? colorScheme.error : customColors.warning;
      diffLabel = l10n.isometricUnderGoal(formatDuration(absDiff));
    } else {
      diffColor = null;
      diffLabel = '';
    }

    return Scaffold(
      appBar: _timedAppBar(name, sets.length),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),

            Text(
              formatDuration(_currentDuration),
              style: textTheme.displayLarge?.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w300,
                color: diffColor ?? colorScheme.onSurface,
              ),
            ),

            if (goalSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: AthlosSpacing.sm),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.isometricGoalLabel(
                          formatDuration(goalSeconds),
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (diffLabel.isNotEmpty) ...[
                        TextSpan(
                          text: ' · ',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextSpan(
                          text: diffLabel,
                          style: textTheme.bodyMedium?.copyWith(
                            color: diffColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AthlosSpacing.xl),

            _NumberInput(
              value: _currentWeight,
              suffix: 'kg',
              step: 2.5,
              onChanged: (v) => setState(() => _currentWeight = v),
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),

            const SizedBox(height: AthlosSpacing.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _RpeSelector(
                    value: _selectedRpe,
                    onChanged: (v) => setState(() => _selectedRpe = v),
                  ),
                ),
              ],
            ),

            const Spacer(flex: 3),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _onCompleteTimedSet(exec),
                icon: const Icon(Icons.check),
                label: Text(
                  l10n.isometricSaveSet,
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

  Widget _buildTimedCompleted(ActiveExecutionState exec, List<SetEntry> sets) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final name = _exerciseName(exercise.exerciseId);
    final nextInExercise = sets
        .where((s) => !s.isCompleted && s.setNumber > _focusedSetNumber)
        .toList();

    return Scaffold(
      appBar: _timedAppBar(
        name,
        sets.length,
        onBack: () => setState(() => _viewMode = _ViewMode.overview),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: colorScheme.primary),
            const SizedBox(height: AthlosSpacing.lg),
            Text(l10n.restComplete, style: textTheme.headlineSmall),
            const SizedBox(height: AthlosSpacing.xl),
            if (nextInExercise.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _goToFocused(
                  exec,
                  _focusedExerciseIndex,
                  nextInExercise.first.setNumber,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.nextSetLabel),
              )
            else ...[
              FilledButton.icon(
                onPressed: () => _goToNextExerciseOrOverview(exec),
                icon: const Icon(Icons.arrow_forward),
                label: Text(l10n.nextExerciseButton),
              ),
              const SizedBox(height: AthlosSpacing.md),
              OutlinedButton.icon(
                onPressed: () => setState(() => _viewMode = _ViewMode.overview),
                icon: const Icon(Icons.list_alt),
                label: Text(l10n.backToOverview),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onCompleteTimedSet(ActiveExecutionState exec) async {
    final exercise = exec.exercises[_focusedExerciseIndex];

    final int rest;
    try {
      final (r, _) = await ref
          .read(activeExecutionProvider.notifier)
          .completeSet(
            exercise.exerciseId,
            _focusedSetNumber,
            duration: _currentDuration > 0 ? _currentDuration : null,
            weight: _currentWeight > 0 ? _currentWeight : null,
            rpe: _selectedRpe,
            notes: _setNotes?.trim().isNotEmpty == true
                ? _setNotes!.trim()
                : null,
          );
      rest = r;
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
      return;
    }

    if (!mounted) return;
    ref.read(cardioTimerProvider.notifier).reset();

    final updatedExec = ref.read(activeExecutionProvider);
    if (updatedExec == null) return;

    final nextInGroup = _nextInSupersetGroup(
      updatedExec,
      _focusedExerciseIndex,
      _focusedSetNumber,
    );
    if (nextInGroup != null) {
      _goToFocused(updatedExec, nextInGroup, _focusedSetNumber);
      return;
    }

    _navigateAfterSet(updatedExec, rest);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onCompleteSet(ActiveExecutionState exec) async {
    final exercise = exec.exercises[_focusedExerciseIndex];
    final isCardio = _isFocusedCardio(exec);

    final isUni = _isUnilateral;

    if (!isCardio && !isUni && _currentReps <= 0) return;
    if (!isCardio && isUni && _leftReps <= 0 && _rightReps <= 0) return;

    final effectiveReps = isUni ? _leftReps : _currentReps;
    final effectiveWeight = isUni ? _leftWeight : _currentWeight;

    final segments = isCardio || _dropSegments.isEmpty
        ? <SegmentEntry>[]
        : [
            SegmentEntry(
              reps: effectiveReps,
              weight: effectiveWeight > 0 ? effectiveWeight : null,
            ),
            ..._dropSegments.map(
              (d) => SegmentEntry(reps: d.reps, weight: d.weight),
            ),
          ];

    final int rest;
    final double? suggestedWeight;
    try {
      final result = await ref
          .read(activeExecutionProvider.notifier)
          .completeSet(
            exercise.exerciseId,
            _focusedSetNumber,
            reps: isCardio ? null : effectiveReps,
            weight: isCardio
                ? null
                : (effectiveWeight > 0 ? effectiveWeight : null),
            duration: isCardio ? _currentDuration : null,
            distance: isCardio
                ? (_currentDistance > 0 ? _currentDistance : null)
                : null,
            rpe: _selectedRpe,
            notes: _setNotes?.trim().isNotEmpty == true
                ? _setNotes!.trim()
                : null,
            segments: segments.isEmpty ? null : segments,
            leftReps: isUni && _leftReps > 0 ? _leftReps : null,
            leftWeight: isUni && _leftWeight > 0 ? _leftWeight : null,
            rightReps: isUni && _rightReps > 0 ? _rightReps : null,
            rightWeight: isUni && _rightWeight > 0 ? _rightWeight : null,
            isUnilateral: isUni,
          );
      rest = result.$1;
      suggestedWeight = result.$2;
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
      return;
    }

    if (!mounted) return;

    if (suggestedWeight != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.suggestedWeightIncrease(suggestedWeight.toStringAsFixed(1)),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final updatedExec = ref.read(activeExecutionProvider);
    if (updatedExec == null) return;

    final nextInGroup = _nextInSupersetGroup(
      updatedExec,
      _focusedExerciseIndex,
      _focusedSetNumber,
    );
    if (nextInGroup != null) {
      _goToFocused(updatedExec, nextInGroup, _focusedSetNumber);
      return;
    }

    _navigateAfterSet(updatedExec, rest);
  }

  Future<void> _onCompleteCardioSet(ActiveExecutionState exec) async {
    final exercise = exec.exercises[_focusedExerciseIndex];

    final int rest;
    try {
      final (r, _) = await ref
          .read(activeExecutionProvider.notifier)
          .completeSet(
            exercise.exerciseId,
            _focusedSetNumber,
            duration: _currentDuration > 0 ? _currentDuration : null,
            distance: _currentDistance > 0 ? _currentDistance : null,
            rpe: _selectedRpe,
            notes: _setNotes?.trim().isNotEmpty == true
                ? _setNotes!.trim()
                : null,
          );
      rest = r;
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
      return;
    }

    if (!mounted) return;
    ref.read(cardioTimerProvider.notifier).reset();

    final updatedExec = ref.read(activeExecutionProvider);
    if (updatedExec == null) return;

    final nextInGroup = _nextInSupersetGroup(
      updatedExec,
      _focusedExerciseIndex,
      _focusedSetNumber,
    );
    if (nextInGroup != null) {
      _goToFocused(updatedExec, nextInGroup, _focusedSetNumber);
      return;
    }

    _navigateAfterSet(updatedExec, rest);
  }

  Future<void> _onFinish(BuildContext context) async {
    try {
      await ref.read(activeExecutionProvider.notifier).finishExecution();
      ref.read(restTimerProvider.notifier).reset();
      ref.read(cardioTimerProvider.notifier).reset();
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.workoutFinished)));

        final program = ref.read(activeProgramProvider).value;

        ref.invalidate(isDeloadDueProvider);
        final isDeloadDue = await ref.read(isDeloadDueProvider.future);
        if (isDeloadDue && context.mounted && program != null) {
          await _showDeloadPrompt(context, program);
        }

        if (program != null && context.mounted) {
          ref.invalidate(programSessionCountProvider(program.id));
          ref.invalidate(programProgressProvider(program.id));
          final progress = await ref.read(
            programProgressProvider(program.id).future,
          );
          if (progress.isCompleted && context.mounted) {
            await _showProgramCompletionPrompt(context, program);
          }
        }

        if (context.mounted) context.pop();
      }
    } on Exception catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
    }
  }

  Future<void> _showDeloadPrompt(
    BuildContext context,
    TrainingProgram program,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final config = program.deloadConfig;
    if (config == null) return;

    final accept = await showAthlosDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deloadPromptTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.deloadPromptMessage(config.frequency ?? 0))],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.deloadSkip),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.deloadAccept),
              ),
            ],
          ),
        ],
      ),
    );

    if (accept == true && mounted) {
      await ref.read(programActionsProvider.notifier).enterDeload(program.id);
      ref.invalidate(programListProvider);
      ref.invalidate(activeProgramProvider);
    }
  }

  Future<void> _showProgramCompletionPrompt(
    BuildContext context,
    TrainingProgram program,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showAthlosDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.emoji_events_rounded,
          color: Theme.of(ctx).colorScheme.primary,
          size: 40,
        ),
        title: Text(l10n.programCompletedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.programCompletedMessage(program.name))],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx, 'archive'),
                child: Text(l10n.programCompletedArchive),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx, 'continue'),
                child: Text(l10n.programCompletedContinue),
              ),
            ],
          ),
        ],
      ),
    );

    if (action == 'archive' && mounted) {
      await ref
          .read(programActionsProvider.notifier)
          .archiveProgram(program.id);
      ref.invalidate(programListProvider);
      ref.invalidate(activeProgramProvider);
    }
  }

  void _showCancelDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelExecution),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.cancelExecutionMessage)],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
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
                          content: Text(
                            AppLocalizations.of(context)!.genericError,
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(l10n.cancelExecution),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.back),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showFinishWorkoutIncompleteDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showAthlosDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.finishWorkoutIncompleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.finishWorkoutIncompleteMessage)],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.finishWorkoutIncompleteConfirm,
                  textAlign: TextAlign.center,
                ),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  l10n.finishWorkoutIncompleteStay,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _onFinish(context);
    }
  }

  void _showSkipRestTimerDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.skipRestTimerTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.skipRestTimerMessage)],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(restTimerProvider.notifier).reset();
                  setState(() => _viewMode = _ViewMode.overview);
                },
                child: Text(l10n.skipTimer),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.continueRest),
              ),
            ],
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
  final bool isUnilateral;
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
    this.isUnilateral = false,
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

    final groupColor = isInGroup && groupColorIndex != null
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
                        padding: const EdgeInsets.only(right: AthlosSpacing.xs),
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
                              Icon(Icons.link, size: 10, color: groupColor),
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
                      child: AthlosTruncatedText(
                        exerciseName,
                        style: textTheme.titleSmall?.copyWith(
                          decoration: isAllDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: isAllDone
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (muscleGroup.isNotEmpty || isUnilateral)
                  Row(
                    children: [
                      if (muscleGroup.isNotEmpty)
                        Flexible(
                          child: Text(
                            muscleGroup,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (isUnilateral) ...[
                        if (muscleGroup.isNotEmpty)
                          const SizedBox(width: AthlosSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.xs,
                            vertical: AthlosSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: AthlosRadius.fullAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 10,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                l10n.unilateralLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
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
                border: Border(left: BorderSide(color: groupColor, width: 4)),
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
  final bool compact;

  const _NumberInput({
    required this.value,
    required this.suffix,
    required this.step,
    required this.onChanged,
    required this.textTheme,
    required this.colorScheme,
    this.valueColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value % 1 == 0
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    final valueStyle = compact
        ? textTheme.headlineMedium
        : textTheme.displayMedium;
    final suffixStyle = compact ? textTheme.bodyMedium : textTheme.titleMedium;
    final spacing = compact ? AthlosSpacing.sm : AthlosSpacing.lg;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: Icons.remove,
          onPressed: value > 0
              ? () => onChanged((value - step).clamp(0, 9999))
              : null,
          colorScheme: colorScheme,
          compact: compact,
        ),
        SizedBox(width: spacing),
        Flexible(
          child: GestureDetector(
            onTap: () => _showEditDialog(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: (valueStyle?.fontSize ?? 45) * 1.2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      displayValue,
                      style: valueStyle?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: valueColor,
                      ),
                    ),
                  ),
                ),
                Text(
                  suffix,
                  style: suffixStyle?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: spacing),
        _CircleButton(
          icon: Icons.add,
          onPressed: () => onChanged(value + step),
          colorScheme: colorScheme,
          compact: compact,
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

    final result = await showAthlosDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suffix),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () {
                  final parsed = double.tryParse(controller.text);
                  Navigator.pop(ctx, parsed);
                },
                child: Text(AppLocalizations.of(ctx)!.okButton),
              ),
            ],
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
  final bool compact;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact ? AthlosSpacing.sm : AthlosSpacing.md;
    final iconSize = compact ? 20.0 : 28.0;

    return Material(
      shape: const CircleBorder(),
      color: onPressed != null
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerHighest.withAlpha(100),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Icon(
            icon,
            color: onPressed != null
                ? colorScheme.onSurface
                : colorScheme.onSurface.withAlpha(80),
            size: iconSize,
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
      _DropSegmentInput(reps: reps ?? this.reps, weight: weight ?? this.weight);
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
          ? widget.segment.weight.toStringAsFixed(
              widget.segment.weight % 1 == 0 ? 0 : 1,
            )
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
          Icon(
            Icons.arrow_downward,
            size: 18,
            color: widget.colorScheme.tertiary,
          ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
              onChanged: (v) => widget.onWeightChanged(double.tryParse(v) ?? 0),
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
            icon: Icon(
              Icons.close,
              size: 20,
              color: widget.colorScheme.onSurfaceVariant,
            ),
            onPressed: widget.onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal RPE selector (6–10 chips). Tap to select, tap again
/// to deselect. Null = not recorded.
class _RpeSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _RpeSelector({required this.value, required this.onChanged});

  static const _values = [6, 7, 8, 9, 10];

  Color _chipColor(int rpe, ColorScheme cs, AthlosCustomColors custom) {
    if (rpe >= 10) return cs.error;
    if (rpe >= 9) return custom.warning;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final custom = Theme.of(context).extension<AthlosCustomColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Tooltip(
          message: l10n.rpeTooltip,
          triggerMode: TooltipTriggerMode.longPress,
          child: Text(
            l10n.rpeLabel,
            style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: AthlosSpacing.sm),
        for (final rpe in _values) ...[
          _RpeChip(
            label: '$rpe',
            isSelected: value == rpe,
            color: _chipColor(rpe, cs, custom),
            colorScheme: cs,
            onTap: () => onChanged(value == rpe ? null : rpe),
          ),
          if (rpe != _values.last) const SizedBox(width: AthlosSpacing.xs),
        ],
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _RpeChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.sm,
          vertical: AthlosSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest,
          borderRadius: AthlosRadius.fullAll,
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? color : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : null,
          ),
        ),
      ),
    );
  }
}
