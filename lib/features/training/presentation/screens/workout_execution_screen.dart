import 'dart:async';
import 'dart:math' as math;
import '../../../../core/widgets/feedback/athlos_messenger.dart';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/rest_timer_notification_service.dart';
import '../../../../core/services/workout_timer_feedback_service.dart';
import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_markdown_notes_card.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/body_metric_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/enums/load_mode.dart';
import '../../domain/helpers/training_metrics.dart';
import '../helpers/duration_format.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/load_mode_l10n.dart';
import '../helpers/rep_performance.dart';
import '../helpers/rest_next_target.dart';
import '../helpers/superset_grouping.dart';
import '../helpers/workout_exercise_prescription_summary.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/cardio_timer_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/rest_timer_notifier.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';
import '../providers/workout_share_summary_gate.dart';
import '../../domain/usecases/apply_planned_workout_edit.dart';
import '../../domain/usecases/promote_ad_hoc_workout.dart';
import '../widgets/ad_hoc_exercise_config_sheet.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/ghost_exercise_recovery_panel.dart';
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

enum _SetOptionsPane { hub, loadMode, dropSets }

String _setOptionsPaneTitle(_SetOptionsPane pane, AppLocalizations l10n) {
  return switch (pane) {
    _SetOptionsPane.hub => '',
    _SetOptionsPane.loadMode => l10n.executionSetLoadModeSheetTitle,
    _SetOptionsPane.dropSets => l10n.executionDropSetsSheetTitle,
  };
}

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
  final String workoutId;

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
  bool _suppressRestFeedbackOnce = false;
  bool _suppressGoalFeedbackOnce = false;
  bool _restAlertScheduledInBackground = false;
  bool _goalAlertScheduledInBackground = false;

  final _restTimerNotificationService = RestTimerNotificationService.instance;
  final _timerFeedbackService = WorkoutTimerFeedbackService.instance;

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

  /// When true, single weight + reps widgets mirror to both limbs (common case).
  bool _unilateralSidesLinked = true;
  List<_DropSegmentInput> _dropSegments = [];
  _TimedSubState _timedSubState = _TimedSubState.ready;
  int _countdownValue = 3;

  bool _isSupersetSelecting = false;
  bool _isJoiningExistingSuperset = false;
  String? _joinSeedExerciseId;
  int? _supersetEditingGroupId;
  Set<String> _supersetSelectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restTimerNotificationService.init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimerNotificationService.cancelAllWorkoutTimerNotifications();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasInBackground = _isInBackground;
    _isInBackground = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.inactive => false,
      _ => true,
    };

    if (state == AppLifecycleState.resumed) {
      _prepareResumeFeedbackSuppression(wasInBackground);
      ref.read(restTimerProvider.notifier).syncWithClock();
      ref.read(cardioTimerProvider.notifier).syncWithClock();
      if (wasInBackground) {
        unawaited(_cancelBackgroundScheduledAlerts());
      }
    }

    if (_isInBackground && !wasInBackground) {
      unawaited(_scheduleBackgroundTimerAlerts());
    }

    if (_isInBackground == wasInBackground) return;
    _syncRestTimerNotification(next: ref.read(restTimerProvider));
    _syncGoalTimerNotification(next: ref.read(cardioTimerProvider));
  }

  void _prepareResumeFeedbackSuppression(bool wasInBackground) {
    if (!wasInBackground) return;

    if (ref.read(restTimerProvider.notifier).wouldBeFinishedOnSync()) {
      _suppressRestFeedbackOnce = true;
    } else if (_restAlertScheduledInBackground) {
      _restAlertScheduledInBackground = false;
    }

    if (ref.read(cardioTimerProvider.notifier).wouldReachGoalOnSync()) {
      _suppressGoalFeedbackOnce = true;
    } else if (_goalAlertScheduledInBackground) {
      _goalAlertScheduledInBackground = false;
    }
  }

  Future<void> _scheduleBackgroundTimerAlerts() async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    await _restTimerNotificationService.init();

    final rest = ref.read(restTimerProvider);
    if (rest.isRunning) {
      final remaining = ref.read(restTimerProvider.notifier).wallClockRemainingSeconds();
      if (remaining > 0) {
        await _restTimerNotificationService.scheduleRestFinished(
          title: l10n.restTimerDone,
          body: l10n.restComplete,
          afterSeconds: remaining,
        );
        _restAlertScheduledInBackground = true;
      }
    }

    final cardio = ref.read(cardioTimerProvider);
    if (cardio.isRunning && cardio.goalSeconds > 0 && !cardio.hasReachedGoal) {
      final remaining =
          ref.read(cardioTimerProvider.notifier).wallClockSecondsUntilGoal();
      if (remaining > 0) {
        await _restTimerNotificationService.scheduleGoalReached(
          title: l10n.cardioGoalReached,
          body: l10n.cardioGoalLabel(formatDuration(cardio.goalSeconds)),
          afterSeconds: remaining,
        );
        _goalAlertScheduledInBackground = true;
      }
    }
  }

  Future<void> _cancelBackgroundScheduledAlerts() async {
    await _restTimerNotificationService.cancelScheduledRestFinished();
    await _restTimerNotificationService.cancelScheduledGoalReached();
    _restAlertScheduledInBackground = false;
    _goalAlertScheduledInBackground = false;
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      workoutExercisesProvider(widget.workoutId),
    );
    final execState = ref.watch(activeExecutionProvider);
    final exerciseCatalogAsync = ref.watch(exerciseListProvider);
    final danglingAsync = ref.watch(danglingExecutionProvider);
    final timerState = ref.watch(restTimerProvider);
    final cardioState = ref.watch(cardioTimerProvider);
    ref.listen<RestTimerState>(restTimerProvider, (previous, next) {
      _syncRestTimerNotification(previous: previous, next: next);
      _maybePlayRestFinishedFeedback(previous, next);
    });
    ref.listen<CardioTimerState>(cardioTimerProvider, (previous, next) {
      _syncGoalTimerNotification(previous: previous, next: next);
      _maybePlayGoalReachedFeedback(previous, next);
    });

    // If the workout references exercises that no longer exist in the local
    // catalog, we must stop and offer a recovery path instead of crashing.
    if (execState != null && exerciseCatalogAsync is AsyncData) {
      final allExercises = exerciseCatalogAsync.value ?? const <Exercise>[];
      final missingExerciseIds =
          execState.exercises
              .map((e) => e.exerciseId)
              .where((id) => !allExercises.any((e) => e.id == id))
              .toSet()
              .toList()
            ..sort();

      if (missingExerciseIds.isNotEmpty) {
        final l10n = AppLocalizations.of(context)!;
        return AthlosScaffold(
          appBar: AppBar(
            title: Text(l10n.ghostExerciseRecoveryTitle),
            leading: IconButton(
              tooltip: l10n.back,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: GhostExerciseRecoveryPanel(
                missingExerciseIds: missingExerciseIds,
                workoutId: widget.workoutId,
                onResolved: () => setState(() {}),
                onCancelExecution: () async {
                  await ref
                      .read(activeExecutionProvider.notifier)
                      .cancelExecution();
                  if (context.mounted) context.pop();
                },
              ),
            ),
          ),
        );
      }
    }

    if (!_isInitialized &&
        exercisesAsync is AsyncData<List<WorkoutExercise>> &&
        execState == null) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final l10n = AppLocalizations.of(context)!;
        final router = GoRouter.of(context);
        try {
          final dangling = danglingAsync.value;
          if (dangling != null && dangling.workoutId != widget.workoutId) {
            router.pop();
            return;
          }
          if (dangling != null && dangling.workoutId == widget.workoutId) {
            await resumeWorkoutExecution(ref, execution: dangling);
            return;
          }

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
          final workout = (await ref
                  .read(workoutRepositoryProvider)
                  .getById(widget.workoutId))
              .getOrThrow();
          final isAdHocDraft = workout?.isDraft ?? false;
          if (isAdHocDraft) {
            await ref.read(activeExecutionProvider.notifier).startAdHocExecution(
                  widget.workoutId,
                  programId: activeProgram.id,
                  deloadConfig: deloadConfig,
                  progressionRules: progressionRules,
                  defaultRestSeconds: activeProgram.defaultRestSeconds ?? 0,
                  isometricExerciseIds: isometricIds,
                );
          } else {
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
          }
        } on Exception catch (_) {
          if (!context.mounted) return;
          context.showAthlosErrorSnack(l10n.genericError);
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
        (previous?.remainingSeconds ?? 0) > 0 &&
        next.remainingSeconds == 0 &&
        next.finishReason == RestTimerFinishReason.natural;
    if (hasJustFinished) {
      await _restTimerNotificationService.cancelScheduledRestFinished();
      if (!_restTimerNotificationService.usesScheduledFinishAlert) {
        await _restTimerNotificationService.showRestFinished(
          title: l10n.restTimerDone,
          body: l10n.restComplete,
        );
        _suppressRestFeedbackOnce = true;
      }
      return;
    }

    if (next.isRunning && next.remainingSeconds > 0) {
      final nextBody = _restTimerNextBody(l10n);
      if (_restTimerNotificationService.supportsFrequentOngoingUpdates) {
        await _restTimerNotificationService.showOngoingRest(
          title: l10n.restTimerLabel(next.remainingSeconds),
          body: nextBody,
        );
        if (!_restAlertScheduledInBackground) {
          final remaining = ref
              .read(restTimerProvider.notifier)
              .wallClockRemainingSeconds();
          if (remaining > 0) {
            await _restTimerNotificationService.scheduleRestFinished(
              title: l10n.restTimerDone,
              body: l10n.restComplete,
              afterSeconds: remaining,
            );
            _restAlertScheduledInBackground = true;
          }
        }
      } else {
        final previousRemaining = previous?.remainingSeconds ?? 0;
        final wasRunning = previous?.isRunning ?? false;
        final hasRemaining = previousRemaining > 0;
        final startedOrResumed = !wasRunning || !hasRemaining;
        final wasExtended = next.remainingSeconds > (previousRemaining + 1);
        if (startedOrResumed || wasExtended) {
          await _restTimerNotificationService.showOngoingRest(
            title: l10n.restTimerLabel(next.remainingSeconds),
            body: nextBody,
          );
          await _restTimerNotificationService.scheduleRestFinished(
            title: l10n.restTimerDone,
            body: l10n.restComplete,
            afterSeconds: ref
                .read(restTimerProvider.notifier)
                .wallClockRemainingSeconds(),
          );
          _restAlertScheduledInBackground = true;
        }
      }
      return;
    }

    if (_restTimerNotificationService.usesScheduledFinishAlert &&
        !next.isRunning &&
        next.remainingSeconds > 0) {
      await _restTimerNotificationService.cancelScheduledRestFinished();
      _restAlertScheduledInBackground = false;
      return;
    }

    if (!next.isActive) {
      await _restTimerNotificationService.cancelAllForRestTimer();
      _restAlertScheduledInBackground = false;
    }
  }

  Future<void> _syncGoalTimerNotification({
    CardioTimerState? previous,
    required CardioTimerState next,
  }) async {
    if (!_isInBackground) {
      if ((previous?.isRunning ?? false) || next.isRunning) {
        await _restTimerNotificationService.cancelAllForGoalTimer();
      }
      return;
    }

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final hadGoal = previous?.hasReachedGoal ?? false;
    final hasJustReachedGoal =
        !hadGoal && next.hasReachedGoal && next.goalSeconds > 0;
    if (hasJustReachedGoal) {
      await _restTimerNotificationService.cancelScheduledGoalReached();
      await _restTimerNotificationService.showGoalReached(
        title: l10n.cardioGoalReached,
        body: l10n.cardioGoalLabel(formatDuration(next.goalSeconds)),
      );
      _suppressGoalFeedbackOnce = true;
      return;
    }

    if (next.isRunning &&
        next.goalSeconds > 0 &&
        !next.hasReachedGoal &&
        !_goalAlertScheduledInBackground) {
      final remaining = ref
          .read(cardioTimerProvider.notifier)
          .wallClockSecondsUntilGoal();
      if (remaining > 0) {
        await _restTimerNotificationService.scheduleGoalReached(
          title: l10n.cardioGoalReached,
          body: l10n.cardioGoalLabel(formatDuration(next.goalSeconds)),
          afterSeconds: remaining,
        );
        _goalAlertScheduledInBackground = true;
      }
      return;
    }

    if (!next.isRunning) {
      await _restTimerNotificationService.cancelAllForGoalTimer();
      _goalAlertScheduledInBackground = false;
    }
  }

  void _maybePlayRestFinishedFeedback(
    RestTimerState? previous,
    RestTimerState next,
  ) {
    if (_isInBackground) return;
    if (next.finishReason != RestTimerFinishReason.natural) return;
    if (previous?.finishReason == RestTimerFinishReason.natural) return;
    if (_suppressRestFeedbackOnce) {
      _suppressRestFeedbackOnce = false;
      return;
    }

    _timerFeedbackService.play(WorkoutTimerFeedbackEvent.restFinished);
  }

  void _maybePlayGoalReachedFeedback(
    CardioTimerState? previous,
    CardioTimerState next,
  ) {
    if (_isInBackground) return;
    if (next.goalSeconds <= 0) return;

    final hadReachedGoal = previous?.hasReachedGoal ?? false;
    if (hadReachedGoal || !next.hasReachedGoal) return;
    if (_suppressGoalFeedbackOnce) {
      _suppressGoalFeedbackOnce = false;
      return;
    }

    _timerFeedbackService.play(WorkoutTimerFeedbackEvent.goalReached);
  }

  String _restTimerNextBody(AppLocalizations l10n) {
    final exec = ref.read(activeExecutionProvider);
    if (exec == null) return l10n.nextSetLabel;

    final next = findNextRestTarget(
      exec,
      focusedExerciseIndex: _focusedExerciseIndex,
      focusedSetNumber: _focusedSetNumber,
    );
    if (next == null) return l10n.allSetsComplete;

    return l10n.nextUpLabel(
      _exerciseName(exec.exercises[next.exerciseIndex].exerciseId),
      next.setNumber,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _exerciseName(String exerciseId) {
    final l10n = AppLocalizations.of(context)!;
    final allExercises = ref.read(exerciseListProvider).value;
    final entity = allExercises?.where((e) => e.id == exerciseId).firstOrNull;
    if (entity == null) return l10n.unknownExerciseId(exerciseId);
    return localizedExerciseName(
      entity.name,
      isVerified: entity.isVerified,
      l10n: l10n,
    );
  }

  String _muscleGroupName(String exerciseId) {
    final l10n = AppLocalizations.of(context)!;
    final allExercises = ref.read(exerciseListProvider).value;
    final entity = allExercises?.where((e) => e.id == exerciseId).firstOrNull;
    if (entity == null) return '';
    return localizedMuscleGroupName(entity.muscleGroup, l10n);
  }

  Exercise? _exerciseEntity(String exerciseId) {
    final allExercises = ref.read(exerciseListProvider).value;
    return allExercises?.where((e) => e.id == exerciseId).firstOrNull;
  }

  LoadMode _resolvedLoadModeFor(
    WorkoutExercise workoutExercise, [
    SetEntry? currentSetEntry,
  ]) {
    final exercise = _exerciseEntity(workoutExercise.exerciseId);
    if (exercise == null) return LoadMode.weighted;
    return resolveLoadMode(
      activeSetLoadModeOverride: currentSetEntry?.loadModeOverride,
      workoutExercise: workoutExercise,
      exercise: exercise,
    );
  }

  String _weightSuffixForMode(LoadMode mode) => switch (mode) {
    LoadMode.weighted => 'kg',
    LoadMode.bodyweight => '+kg',
    LoadMode.assisted => '-kg',
  };

  String? _effectiveLoadTooltipMessage({
    required LoadMode mode,
    required double? bodyWeight,
    required Exercise? exerciseEntity,
    required double plateOrAssistKg,
    required double? effectiveTotal,
  }) {
    if (bodyWeight == null ||
        exerciseEntity == null ||
        effectiveTotal == null) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    final bk = bodyWeight.toStringAsFixed(1);
    final fac = (exerciseEntity.bodyweightLoadFactor ?? 1.0).toStringAsFixed(2);
    final plate = plateOrAssistKg.toStringAsFixed(1);
    final tot = effectiveTotal.toStringAsFixed(1);
    return switch (mode) {
      LoadMode.bodyweight => l10n.executionBodyweightLoadTooltip(
        bk,
        fac,
        plate,
        tot,
      ),
      LoadMode.assisted => l10n.executionAssistedLoadTooltip(
        bk,
        fac,
        plate,
        tot,
      ),
      LoadMode.weighted => null,
    };
  }

  Widget? _effectiveLoadTooltipIcon({
    required LoadMode mode,
    required Exercise? exerciseEntity,
    required double? bodyWeight,
    required double? effectiveTotal,
    required double plateOrAssistKg,
    required ColorScheme colorScheme,
  }) {
    final msg = _effectiveLoadTooltipMessage(
      mode: mode,
      bodyWeight: bodyWeight,
      exerciseEntity: exerciseEntity,
      plateOrAssistKg: plateOrAssistKg,
      effectiveTotal: effectiveTotal,
    );
    if (msg == null) return null;
    return Tooltip(
      message: msg,
      triggerMode: TooltipTriggerMode.tap,
      child: Icon(
        Icons.info_outline,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
    );
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
      final rowId = exec.exercises[i].id;
      final sets = exec.exerciseSets[rowId] ?? [];
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
      final rowId = exec.exercises[nextIdx].id;
      final sets = exec.exerciseSets[rowId] ?? [];
      final match = sets.where(
        (s) => s.setNumber == setNumber && !s.isCompleted,
      );
      if (match.isNotEmpty) return nextIdx;
    }
    return null;
  }

  bool _isExerciseIsometric(String exerciseId) {
    final allExercises = ref.read(exerciseListProvider).value;
    return allExercises?.any((e) => e.id == exerciseId && e.isIsometric) ??
        false;
  }

  bool _isFocusedIsometric(ActiveExecutionState exec) =>
      _isExerciseIsometric(exec.exercises[_focusedExerciseIndex].exerciseId);

  bool _isFocusedCardio(ActiveExecutionState exec) =>
      exec.exercises[_focusedExerciseIndex].durationSeconds != null &&
      !_isFocusedIsometric(exec);

  void _goToFocused(
    ActiveExecutionState exec,
    int exerciseIndex, [
    int? setNumber,
  ]) {
    final rowId = exec.exercises[exerciseIndex].id;
    final sets = exec.exerciseSets[rowId] ?? [];

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

    final isIsometric = _isExerciseIsometric(
      exec.exercises[exerciseIndex].exerciseId,
    );
    final isCardio =
        exec.exercises[exerciseIndex].durationSeconds != null && !isIsometric;

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
                : exec.exercises[exerciseIndex].durationSeconds ?? 0);
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
                : exec.exercises[exerciseIndex].durationSeconds ?? 0);
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
      _dropSegments = entry.segments
          .skip(1)
          .map((s) => _DropSegmentInput(reps: s.reps, weight: s.weight ?? 0))
          .toList();

      _isUnilateral = exec.exercises[exerciseIndex].isUnilateral;
      _leftReps = entry.leftReps ?? _currentReps;
      _leftWeight = entry.leftWeight ?? _currentWeight;
      _rightReps = entry.rightReps ?? _currentReps;
      _rightWeight = entry.rightWeight ?? _currentWeight;
      _unilateralSidesLinked = _inferUnilateralSidesLinked(
        _leftWeight,
        _rightWeight,
        _leftReps,
        _rightReps,
      );
    });
  }

  void _goToNextSetFromTimer(ActiveExecutionState exec) {
    ref.read(restTimerProvider.notifier).reset();
    final next = findNextRestTarget(
      exec,
      focusedExerciseIndex: _focusedExerciseIndex,
      focusedSetNumber: _focusedSetNumber,
    );
    if (next != null) {
      _goToFocused(exec, next.exerciseIndex, next.setNumber);
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
    final rowId = exec.exercises[_focusedExerciseIndex].id;
    final sets = exec.exerciseSets[rowId] ?? [];
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

  void _showExerciseNotesDialog(String markdownNotes) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.executionSetOptionsNotesHeading),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: markdownNotes,
              styleSheet: MarkdownStyleSheet(
                p: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                listBullet: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.okButton),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Load mode and drop sets for this set (notes: chip → dialog).
  Future<void> _showSetOptionsBottomSheet({
    required WorkoutExercise exercise,
    required SetEntry currentSetEntry,
    required Exercise? exerciseEntity,
    required bool showLoadModeSection,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final inheritedMode = exerciseEntity != null
        ? resolveLoadMode(workoutExercise: exercise, exercise: exerciseEntity)
        : null;
    final resolvedForHub = _resolvedLoadModeFor(exercise, currentSetEntry);
    final showLoadTile =
        showLoadModeSection && exerciseEntity != null && inheritedMode != null;

    var pane = _SetOptionsPane.hub;

    await showAthlosModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;
            final primaryReps = _isUnilateral ? _leftReps : _currentReps;
            final primaryWeight = _isUnilateral ? _leftWeight : _currentWeight;

            void bump() {
              if (mounted) setState(() {});
              setModalState(() {});
            }

            return PopScope(
              canPop: pane == _SetOptionsPane.hub,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && pane != _SetOptionsPane.hub) {
                  setModalState(() => pane = _SetOptionsPane.hub);
                }
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AthlosSpacing.md,
                      AthlosSpacing.sm,
                      AthlosSpacing.md,
                      AthlosSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pane != _SetOptionsPane.hub) ...[
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                onPressed: () => setModalState(
                                  () => pane = _SetOptionsPane.hub,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _setOptionsPaneTitle(pane, l10n),
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AthlosSpacing.sm),
                        ] else ...[
                          Text(
                            l10n.executionSetOptionsSheetTitle,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AthlosSpacing.xs),
                          Text(
                            l10n.executionSetOptionsSheetIntro,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AthlosSpacing.md),
                        ],
                        if (pane == _SetOptionsPane.hub) ...[
                          if (showLoadTile)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.scale_outlined,
                                color: cs.primary,
                              ),
                              title: Text(l10n.executionSetLoadModeSheetTitle),
                              subtitle: Text(
                                localizedLoadModeOptionTitle(
                                  resolvedForHub,
                                  l10n,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: cs.onSurfaceVariant,
                              ),
                              onTap: () => setModalState(
                                () => pane = _SetOptionsPane.loadMode,
                              ),
                            ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.layers_outlined,
                              color: cs.tertiary,
                            ),
                            title: Text(l10n.executionDropSetsTileTitle),
                            subtitle: Text(
                              _dropSegments.isEmpty
                                  ? l10n.executionDropSetsSubtitleEmpty
                                  : l10n.executionDropSetsSubtitleCount(
                                      _dropSegments.length,
                                    ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: cs.onSurfaceVariant,
                            ),
                            onTap: () => setModalState(
                              () => pane = _SetOptionsPane.dropSets,
                            ),
                          ),
                        ],
                        if (pane == _SetOptionsPane.loadMode &&
                            showLoadTile) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.executionSetLoadModeInherit),
                            subtitle: Text(
                              localizedLoadModeOptionTitle(inheritedMode, l10n),
                            ),
                            onTap: () {
                              ref
                                  .read(activeExecutionProvider.notifier)
                                  .updateSetLoadModeOverride(
                                    exercise.id,
                                    currentSetEntry.setNumber,
                                    null,
                                  );
                              bump();
                            },
                          ),
                          for (final mode in LoadMode.values)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                localizedLoadModeOptionTitle(mode, l10n),
                              ),
                              onTap: () {
                                ref
                                    .read(activeExecutionProvider.notifier)
                                    .updateSetLoadModeOverride(
                                      exercise.id,
                                      currentSetEntry.setNumber,
                                      mode == inheritedMode ? null : mode,
                                    );
                                bump();
                              },
                            ),
                        ],
                        if (pane == _SetOptionsPane.dropSets) ...[
                          Text(
                            l10n.executionDropSetsSheetHint,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AthlosSpacing.sm),
                          if (_dropSegments.isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: AthlosRadius.mdAll,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AthlosSpacing.xs,
                                ),
                                child: Column(
                                  children: [
                                    for (
                                      var idx = 0;
                                      idx < _dropSegments.length;
                                      idx++
                                    )
                                      _DropSegmentRow(
                                        index: idx,
                                        segment: _dropSegments[idx],
                                        colorScheme: cs,
                                        textTheme: tt,
                                        l10n: l10n,
                                        onWeightChanged: (w) {
                                          setState(
                                            () => _dropSegments[idx] =
                                                _dropSegments[idx].copyWith(
                                                  weight: w,
                                                ),
                                          );
                                          setModalState(() {});
                                        },
                                        onRepsChanged: (r) {
                                          setState(
                                            () => _dropSegments[idx] =
                                                _dropSegments[idx].copyWith(
                                                  reps: r,
                                                ),
                                          );
                                          setModalState(() {});
                                        },
                                        onRemove: () {
                                          setState(
                                            () => _dropSegments.removeAt(idx),
                                          );
                                          setModalState(() {});
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          if (_dropSegments.isNotEmpty)
                            const SizedBox(height: AthlosSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _dropSegments.add(
                                  _DropSegmentInput(
                                    reps: (primaryReps * 0.5).ceil().clamp(
                                      1,
                                      999999,
                                    ),
                                    weight: primaryWeight * 0.8,
                                  ),
                                );
                              });
                              setModalState(() {});
                            },
                            icon: Icon(Icons.add, size: 18, color: cs.tertiary),
                            label: Text(l10n.addDropSet),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.tertiary,
                              side: BorderSide(
                                color: cs.tertiary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverviewNextSetButton(
    BuildContext context,
    ActiveExecutionState exec,
    (int exerciseIndex, int setNumber) next,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final onPrimary = colorScheme.onPrimary;
    final label = l10n.nextSetButton(
      _exerciseName(exec.exercises[next.$1].exerciseId),
      next.$2,
    );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.md,
            vertical: AthlosSpacing.smd,
          ),
        ),
        onPressed: () => _goToFocused(exec, next.$1, next.$2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const iconSize = 24.0;
            const gap = AthlosSpacing.sm;
            final leading = iconSize + gap;
            final maxTextWidth = (constraints.maxWidth - leading)
                .clamp(0.0, double.infinity)
                .toDouble();

            final labelStyle = textTheme.titleSmall?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.w600,
            );

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: onPrimary, size: iconSize),
                  const SizedBox(width: gap),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxTextWidth),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 1: Overview
  // ---------------------------------------------------------------------------

  Future<void> _onAddAdHocExercise(ActiveExecutionState exec) async {
    final exercise = await showExercisePickerSheet(
      context,
      alreadyInWorkoutCatalogIds: {
        for (final e in exec.exercises) e.exerciseId,
      },
    );
    if (exercise == null || !mounted) return;
    try {
      final added =
          await ref.read(activeExecutionProvider.notifier).addExercise(exercise);
      if (!added && mounted) {
        context.showAthlosSnack(
          AppLocalizations.of(context)!.workoutExerciseAlreadyInWorkout,
        );
      }
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  Exercise? _exerciseById(String exerciseId) {
    final allExercises = ref.read(exerciseListProvider).value;
    if (allExercises == null) return null;
    for (final e in allExercises) {
      if (e.id == exerciseId) return e;
    }
    return null;
  }

  Future<void> _onEditAdHocExercise(
    ActiveExecutionState exec,
    WorkoutExercise workoutExercise,
  ) async {
    final exercise = _exerciseById(workoutExercise.exerciseId);
    if (exercise == null) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
      return;
    }

    final completedSets = (exec.exerciseSets[workoutExercise.id] ?? [])
        .where((s) => s.isCompleted)
        .length;

    final updated = await showAdHocExerciseConfigSheet(
      context,
      workoutExercise: workoutExercise,
      exercise: exercise,
      minSets: completedSets,
    );
    if (updated == null || !mounted) return;

    try {
      await ref
          .read(activeExecutionProvider.notifier)
          .updateAdHocExercise(updated);
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  void _showAdHocExerciseOptionsSheet(
    BuildContext context,
    ActiveExecutionState exec,
    WorkoutExercise workoutExercise,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exerciseName = _exerciseName(workoutExercise.exerciseId);

    showAthlosModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(exerciseName, style: textTheme.titleMedium),
                const SizedBox(height: AthlosSpacing.md),
                if (workoutExercise.groupId == null) ...[
                  ListTile(
                    leading: Icon(Icons.link, color: colorScheme.primary),
                    title: Text(l10n.linkSuperset),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startSupersetSelection(workoutExercise);
                    },
                  ),
                  if (_hasExistingSuperset(exec))
                    ListTile(
                      leading: Icon(
                        Icons.add_link,
                        color: colorScheme.primary,
                      ),
                      title: Text(l10n.adHocSupersetJoinExistingAction),
                      onTap: () {
                        Navigator.pop(ctx);
                        _startJoinExistingSupersetSelection(workoutExercise);
                      },
                    ),
                ] else
                  ListTile(
                    leading: Icon(Icons.tune, color: colorScheme.primary),
                    title: Text(l10n.adHocSupersetEditAction),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startSupersetEditMode(exec, workoutExercise);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
                  title: Text(l10n.editExercise),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onEditAdHocExercise(exec, workoutExercise);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    l10n.removeExercise,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _onRemoveAdHocExercise(
                      context,
                      exec,
                      workoutExercise.id,
                    );
                    if (confirmed && mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _onRemoveAdHocExercise(
    BuildContext context,
    ActiveExecutionState exec,
    String rowId,
  ) async {
    final sets = exec.exerciseSets[rowId] ?? [];
    final hasCompleted = sets.any((s) => s.isCompleted);
    if (hasCompleted) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showAthlosDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.adHocRemoveExerciseTitle),
          content: Text(l10n.adHocRemoveExerciseMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.removeExercise),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
    }
    ref.read(activeExecutionProvider.notifier).removeExercise(rowId);
    return true;
  }

  bool _hasExistingSuperset(ActiveExecutionState exec) =>
      exec.exercises.any((e) => e.groupId != null);

  void _startSupersetSelection(WorkoutExercise seed) {
    if (seed.groupId != null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {seed.exerciseId};
    });
  }

  void _startSupersetEditMode(
    ActiveExecutionState exec,
    WorkoutExercise seed,
  ) {
    final gid = seed.groupId;
    if (gid == null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = gid;
      _supersetSelectedIds = {
        for (final e in exec.exercises)
          if (e.groupId == gid) e.exerciseId,
      };
    });
  }

  void _startJoinExistingSupersetSelection(WorkoutExercise seed) {
    if (seed.groupId != null) return;
    setState(() {
      _isSupersetSelecting = true;
      _isJoiningExistingSuperset = true;
      _joinSeedExerciseId = seed.exerciseId;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {seed.exerciseId};
    });
  }

  bool _isJoinSupersetSelectionLocked(WorkoutExercise exercise) {
    final seedId = _joinSeedExerciseId;
    if (seedId == null) return true;
    final gid = exercise.groupId;
    if (gid != null) {
      return _supersetEditingGroupId != null && gid != _supersetEditingGroupId;
    }
    return exercise.exerciseId != seedId;
  }

  void _cancelSupersetEdit() {
    setState(() {
      _isSupersetSelecting = false;
      _isJoiningExistingSuperset = false;
      _joinSeedExerciseId = null;
      _supersetEditingGroupId = null;
      _supersetSelectedIds = {};
    });
  }

  void _toggleSupersetSelection(WorkoutExercise exercise) {
    if (_isJoiningExistingSuperset) {
      if (_isJoinSupersetSelectionLocked(exercise)) return;

      final seedId = _joinSeedExerciseId;
      if (seedId == null) return;

      final gid = exercise.groupId;
      if (gid == null) {
        setState(() {
          if (_supersetSelectedIds.contains(seedId)) {
            _supersetSelectedIds = {};
          } else {
            _supersetSelectedIds = {seedId};
          }
          _supersetEditingGroupId = null;
        });
        return;
      }

      final exec = ref.read(activeExecutionProvider);
      if (exec == null) return;

      if (_supersetEditingGroupId == gid) {
        setState(() {
          _supersetEditingGroupId = null;
          _supersetSelectedIds = {seedId};
        });
        return;
      }

      setState(() {
        _supersetEditingGroupId = gid;
        _supersetSelectedIds = {
          seedId,
          for (final e in exec.exercises)
            if (e.groupId == gid) e.exerciseId,
        };
      });
      return;
    }

    if (isLockedInOtherSuperset(exercise, _supersetEditingGroupId)) return;
    setState(() {
      if (_supersetSelectedIds.contains(exercise.exerciseId)) {
        _supersetSelectedIds = {..._supersetSelectedIds}
          ..remove(exercise.exerciseId);
      } else {
        _supersetSelectedIds = {..._supersetSelectedIds, exercise.exerciseId};
      }
    });
  }

  void _confirmSupersetEdit() {
    if (_isJoiningExistingSuperset) {
      final l10n = AppLocalizations.of(context)!;
      if (_supersetEditingGroupId == null || _supersetSelectedIds.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adHocSupersetJoinConfirmNeedsGroup)),
        );
        return;
      }
    }

    final exec = ref.read(activeExecutionProvider);
    final focusedExerciseId = exec != null &&
            _focusedExerciseIndex >= 0 &&
            _focusedExerciseIndex < exec.exercises.length
        ? exec.exercises[_focusedExerciseIndex].exerciseId
        : null;

    ref.read(activeExecutionProvider.notifier).commitSupersetSelection(
          _supersetSelectedIds,
          editingGroupId: _supersetEditingGroupId,
        );

    if (focusedExerciseId != null && mounted) {
      final updated = ref.read(activeExecutionProvider);
      final newIndex = updated?.exercises.indexWhere(
        (e) => e.exerciseId == focusedExerciseId,
      );
      if (newIndex != null && newIndex >= 0) {
        setState(() => _focusedExerciseIndex = newIndex);
      }
    }

    _cancelSupersetEdit();
  }

  void _onReorderAdHocExercises(int oldIndex, int newIndex) {
    final exec = ref.read(activeExecutionProvider);
    if (exec == null || exec.exercises.isEmpty) return;

    final safeFocused = _focusedExerciseIndex.clamp(
      0,
      exec.exercises.length - 1,
    );
    final focusedId = exec.exercises[safeFocused].exerciseId;

    final moved = ref
        .read(activeExecutionProvider.notifier)
        .reorderAdHocExercises(oldIndex, newIndex);

    if (!moved && mounted) {
      context.showAthlosErrorSnack(
        AppLocalizations.of(context)!.plannedEditReorderBlocked,
      );
      return;
    }

    final updated = ref.read(activeExecutionProvider);
    if (!mounted || updated == null) return;

    final newFocusedIndex = updated.exercises.indexWhere(
      (e) => e.exerciseId == focusedId,
    );
    if (newFocusedIndex >= 0) {
      setState(() => _focusedExerciseIndex = newFocusedIndex);
    }
  }

  Future<void> _onDiscardStructuralEdits() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(activeExecutionProvider.notifier).discardStructuralEdits();
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(l10n.genericError);
      }
    }
  }

  Widget _buildSupersetSelectionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        elevation: AthlosElevation.md,
        borderRadius: AthlosRadius.fullAll,
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'superset-cancel',
                onPressed: _cancelSupersetEdit,
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
                child: const Icon(Icons.close),
              ),
              const SizedBox(width: AthlosSpacing.sm),
              FloatingActionButton.small(
                heroTag: 'superset-confirm',
                onPressed: _confirmSupersetEdit,
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context, ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId));
    final workoutName = exec.isAdHoc
        ? l10n.improvisedWorkoutTitle
        : (workoutAsync.value?.name ?? '');
    final workoutNotes = workoutAsync.value?.description?.trim();
    final completed = exec.completedSetCount;
    final total = _totalSetCount;
    final next = _findNextPendingSet(exec);

    final isSupersetSelecting = exec.canEditStructure && _isSupersetSelecting;
    final showAddExerciseFab =
        exec.canEditStructure && !isSupersetSelecting && !exec.isFinishing;

    return PopScope(
      canPop: !isSupersetSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSupersetSelecting) _cancelSupersetEdit();
      },
      child: AthlosScaffold(
        floatingActionButton: showAddExerciseFab
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: next != null
                      ? AthlosSpacing.executionOverviewFabBottomInsetStacked
                      : AthlosSpacing.executionOverviewFabBottomInset,
                ),
                child: FloatingActionButton(
                  heroTag: 'execution-add-exercise',
                  onPressed: () => _onAddAdHocExercise(exec),
                  tooltip: l10n.adHocAddExercise,
                  child: const Icon(Icons.add),
                ),
              )
            : null,
        appBar: AppBar(
          title: AthlosTruncatedText(l10n.executionTitle(workoutName)),
          automaticallyImplyLeading: false,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              exec.isStructuralEditing ? 48 : 40,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AthlosSpacing.xs,
                right: AthlosSpacing.xs,
                bottom: AthlosSpacing.xs,
              ),
              child: Row(
                children: [
                  if (!isSupersetSelecting && !exec.isAdHoc) ...[
                    if (exec.isStructuralEditing)
                      FilledButton.tonalIcon(
                        onPressed: exec.isFinishing
                            ? null
                            : _onDiscardStructuralEdits,
                        icon: const Icon(Icons.undo, size: 18),
                        label: Text(
                          l10n.plannedEditRevertAction,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.md,
                            vertical: AthlosSpacing.sm,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.tune_outlined),
                        tooltip: l10n.plannedEditEnterAction,
                        onPressed: exec.isFinishing
                            ? null
                            : () => ref
                                .read(activeExecutionProvider.notifier)
                                .enterStructuralEditing(),
                      ),
                  ],
                  const Spacer(),
                  if (isSupersetSelecting)
                    TextButton(
                      onPressed: _cancelSupersetEdit,
                      child: Text(l10n.cancel),
                    )
                  else
                    TextButton(
                      onPressed: () => _showCancelDialog(context),
                      child: Text(l10n.cancelExecution),
                    ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            if (isSupersetSelecting)
              Material(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                    vertical: AthlosSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: AthlosSpacing.sm),
                      Expanded(
                        child: Text(
                          _isJoiningExistingSuperset
                              ? l10n.adHocSupersetJoinSelectHint
                              : _supersetEditingGroupId == null
                                  ? l10n.adHocSupersetSelectHintNewGroup
                                  : l10n.adHocSupersetSelectHintEdit,
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Builder(
                  builder: (context) {
                    if (exec.isAdHoc && exec.exercises.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AthlosSpacing.lg),
                          child: Text(
                            l10n.adHocEmptyHint,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final groupColorMap =
                        supersetColorIndexByGroupId(exec.exercises);
                    final canReorderOverview =
                        exec.canEditStructure && !isSupersetSelecting;

                    final listPadding = EdgeInsets.fromLTRB(
                      AthlosSpacing.sm,
                      AthlosSpacing.sm,
                      AthlosSpacing.sm,
                      isSupersetSelecting || showAddExerciseFab
                          ? AthlosSpacing.fabClearance
                          : AthlosSpacing.sm,
                    );

                    Widget buildOverviewItem(BuildContext context, int index) {
                    final exercise = exec.exercises[index];
                    final sets = exec.exerciseSets[exercise.id] ?? [];
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

                    final catalogExercise = _exerciseById(exercise.exerciseId);
                    final prescriptionSummary = catalogExercise != null
                        ? formatWorkoutExercisePrescriptionSummary(
                            exercise: exercise,
                            catalogExercise: catalogExercise,
                            l10n: l10n,
                          )
                        : null;

                    final isSelected = _supersetSelectedIds.contains(
                      exercise.exerciseId,
                    );
                    final isSupersetLocked = isSupersetSelecting &&
                        (_isJoiningExistingSuperset
                            ? _isJoinSupersetSelectionLocked(exercise)
                            : isLockedInOtherSuperset(
                                exercise,
                                _supersetEditingGroupId,
                              ));

                    final overviewCard = _OverviewExerciseCard(
                      exerciseName: _exerciseName(exercise.exerciseId),
                      muscleGroup: _muscleGroupName(exercise.exerciseId),
                      prescriptionSummary: prescriptionSummary,
                      isAmrap: exercise.isAmrap,
                      completedSets: completedSets,
                      totalSets: totalSets,
                      isAllDone: isAllDone,
                      isActive: isActive && !isSupersetSelecting,
                      isUnilateral: exercise.isUnilateral,
                      isGroupedWithPrevious: isGroupedWithPrev,
                      isGroupedWithNext: isGroupedWithNext,
                      groupColorIndex: gid != null ? groupColorMap[gid] : null,
                      isSupersetSelectionActive: isSupersetSelecting,
                      isSupersetSelected: isSelected,
                      isSupersetSelectionLocked: isSupersetLocked,
                      reorderListIndex:
                          canReorderOverview ? index : null,
                      onTap: isSupersetSelecting
                          ? () => _toggleSupersetSelection(exercise)
                          : () => _goToFocused(exec, index),
                      onLongPress: exec.canEditStructure && !isSupersetSelecting
                          ? () => _showAdHocExerciseOptionsSheet(
                                context,
                                exec,
                                exercise,
                              )
                          : null,
                    );

                    if (!exec.canEditStructure || isSupersetSelecting) {
                      return KeyedSubtree(
                        key: ValueKey(exercise.id),
                        child: overviewCard,
                      );
                    }

                    return Dismissible(
                      key: ValueKey(exercise.id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _onEditAdHocExercise(exec, exercise);
                          return false;
                        }
                        return _onRemoveAdHocExercise(
                          context,
                          exec,
                          exercise.id,
                        );
                      },
                      onDismissed: (_) {},
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: AthlosSpacing.lg),
                        margin: const EdgeInsets.symmetric(
                          vertical: AthlosSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: AthlosRadius.mdAll,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AthlosSpacing.lg),
                        margin: const EdgeInsets.symmetric(
                          vertical: AthlosSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: AthlosRadius.mdAll,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      child: overviewCard,
                    );
                    }

                    return ReorderableListView.builder(
                      padding: listPadding,
                      itemCount: exec.exercises.length,
                      onReorderItem: canReorderOverview
                          ? _onReorderAdHocExercises
                          : (_, _) {},
                      itemBuilder: buildOverviewItem,
                    );
                  },
                ),
                if (isSupersetSelecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AthlosSpacing.lg),
                    child: _buildSupersetSelectionBar(context),
                  ),
              ],
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
                            style: AthlosScreenButtonStyles.fullWidthText(
                              context,
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
                        _buildOverviewNextSetButton(context, exec, next),
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
      ),
    );
  }

  /// Prescription rep target under the reps inputs (e.g. `8-12`, fixed `10`, `12+` AMRAP).
  List<Widget> _executionRepsTargetBelowInputs(
    BuildContext context,
    WorkoutExercise exercise,
  ) {
    final label = exercise.repsDisplay;
    if (label.isEmpty) return const [];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metaStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
      fontWeight: FontWeight.w400,
    );
    final metaIconColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.65);

    return [
      Padding(
        padding: const EdgeInsets.only(top: AthlosSpacing.xs),
        child: Center(
          child: Text.rich(
            TextSpan(
              style: metaStyle,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ExcludeSemantics(
                    child: _RepsGoalTargetWithArrow(color: metaIconColor),
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(text: label),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// True when load and reps match on both sides (single merged UI is enough).
  bool _inferUnilateralSidesLinked(
    double leftWeight,
    double rightWeight,
    int leftReps,
    int rightReps,
  ) {
    const eps = 1e-6;
    return (leftWeight - rightWeight).abs() < eps && leftReps == rightReps;
  }

  // ---------------------------------------------------------------------------
  // View 2: Focused
  // ---------------------------------------------------------------------------

  Widget _buildFocused(BuildContext context, ActiveExecutionState exec) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.id] ?? [];
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
    final exerciseEntity = _exerciseEntity(exercise.exerciseId);
    final notesTrimmed = exercise.notes?.trim();
    final resolvedLoadMode = _resolvedLoadModeFor(exercise, currentSetEntry);
    final weightSuffix = _weightSuffixForMode(resolvedLoadMode);
    final bodyWeight = ref.watch(latestBodyWeightProvider).value;
    final weightForEffectiveLoad = _isUnilateral ? _leftWeight : _currentWeight;
    final effectiveLoadHint = exerciseEntity == null
        ? null
        : effectiveLoad(
            mode: resolvedLoadMode,
            setWeight: weightForEffectiveLoad > 0
                ? weightForEffectiveLoad
                : null,
            bodyWeight: bodyWeight,
            loadFactor: exerciseEntity.bodyweightLoadFactor,
          );

    Widget? unilateralPlateTooltip(double plateKg) {
      if (exerciseEntity == null) return null;
      final hint = effectiveLoad(
        mode: resolvedLoadMode,
        setWeight: plateKg > 0 ? plateKg : null,
        bodyWeight: bodyWeight,
        loadFactor: exerciseEntity.bodyweightLoadFactor,
      );
      return _effectiveLoadTooltipIcon(
        mode: resolvedLoadMode,
        exerciseEntity: exerciseEntity,
        bodyWeight: bodyWeight,
        effectiveTotal: hint,
        plateOrAssistKg: plateKg,
        colorScheme: colorScheme,
      );
    }

    return AthlosScaffold(
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
                          _unilateralSidesLinked = true;
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
            if (notesTrimmed != null && notesTrimmed.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: (group.isNotEmpty || exercise.isUnilateral)
                      ? AthlosSpacing.sm
                      : AthlosSpacing.md,
                ),
                child: Center(
                  child: ActionChip(
                    avatar: Icon(
                      Icons.note_alt_outlined,
                      size: 18,
                      color: colorScheme.secondary,
                    ),
                    label: Text(l10n.executionSetOptionsNotesHeading),
                    onPressed: () => _showExerciseNotesDialog(notesTrimmed),
                  ),
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
                suffix: weightSuffix,
                suffixTrailing: _effectiveLoadTooltipIcon(
                  mode: resolvedLoadMode,
                  exerciseEntity: exerciseEntity,
                  bodyWeight: bodyWeight,
                  effectiveTotal: effectiveLoadHint,
                  plateOrAssistKg: weightForEffectiveLoad,
                  colorScheme: colorScheme,
                ),
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

              ..._executionRepsTargetBelowInputs(context, exercise),
            ] else ...[
              Center(
                child: IconButton(
                  tooltip: _unilateralSidesLinked
                      ? l10n.executionUnilateralSidesLinkedTooltip
                      : l10n.executionUnilateralSidesSplitTooltip,
                  onPressed: () => setState(() {
                    if (_unilateralSidesLinked) {
                      _unilateralSidesLinked = false;
                    } else {
                      _unilateralSidesLinked = true;
                      _rightWeight = _leftWeight;
                      _rightReps = _leftReps;
                    }
                  }),
                  icon: Icon(
                    _unilateralSidesLinked
                        ? Icons.link_rounded
                        : Icons.link_off_rounded,
                    color: _unilateralSidesLinked
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AthlosSpacing.xxs,
                    children: [
                      Text(
                        l10n.executionUnilateralWeightPerSideLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Tooltip(
                        message: _unilateralSidesLinked
                            ? l10n.executionUnilateralMergedHint
                            : l10n.executionUnilateralWeightHint,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(
                          Icons.help_outline,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_unilateralSidesLinked) ...[
                _NumberInput(
                  value: _leftWeight,
                  suffix: weightSuffix,
                  suffixTrailing: _effectiveLoadTooltipIcon(
                    mode: resolvedLoadMode,
                    exerciseEntity: exerciseEntity,
                    bodyWeight: bodyWeight,
                    effectiveTotal: effectiveLoadHint,
                    plateOrAssistKg: weightForEffectiveLoad,
                    colorScheme: colorScheme,
                  ),
                  step: 2.5,
                  onChanged: (v) => setState(() {
                    _leftWeight = v;
                    _rightWeight = v;
                  }),
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AthlosSpacing.lg,
                    bottom: AthlosSpacing.sm,
                  ),
                  child: Text(
                    l10n.executionUnilateralRepsPerSideLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _NumberInput(
                  value: _leftReps.toDouble(),
                  suffix: l10n.repsShort,
                  step: 1,
                  onChanged: (v) => setState(() {
                    final reps = v.toInt();
                    _leftReps = reps;
                    _rightReps = reps;
                  }),
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
              ] else ...[
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
                            value: _leftWeight,
                            suffix: weightSuffix,
                            suffixTrailing: unilateralPlateTooltip(_leftWeight),
                            step: 2.5,
                            compact: true,
                            onChanged: (v) => setState(() => _leftWeight = v),
                            textTheme: textTheme,
                            colorScheme: colorScheme,
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
                            value: _rightWeight,
                            suffix: weightSuffix,
                            suffixTrailing: unilateralPlateTooltip(
                              _rightWeight,
                            ),
                            step: 2.5,
                            compact: true,
                            onChanged: (v) => setState(() => _rightWeight = v),
                            textTheme: textTheme,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: AthlosSpacing.lg,
                    bottom: AthlosSpacing.sm,
                  ),
                  child: Text(
                    l10n.executionUnilateralRepsPerSideLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                              Theme.of(
                                context,
                              ).extension<AthlosCustomColors>()!,
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
                              Theme.of(
                                context,
                              ).extension<AthlosCustomColors>()!,
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
              ],

              ..._executionRepsTargetBelowInputs(context, exercise),
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

            // RPE selector
            Padding(
              padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
              child: Row(
                children: [
                  if (!_isFocusedCardio(exec))
                    Expanded(
                      child: _RpeSelector(
                        value: _selectedRpe,
                        onChanged: (v) => setState(() => _selectedRpe = v),
                      ),
                    ),
                ],
              ),
            ),

            if (!_isFocusedCardio(exec) && !currentSetEntry.isCompleted)
              Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: AthlosScreenButtonStyles.fullWidthTextMuted(context),
                    icon: const Icon(Icons.tune_outlined, size: 20),
                    label: Text(
                      l10n.executionSetOptionsSheetTitle,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onPressed: () => _showSetOptionsBottomSheet(
                      exercise: exercise,
                      currentSetEntry: currentSetEntry,
                      exerciseEntity: exerciseEntity,
                      showLoadModeSection:
                          exerciseEntity != null &&
                          exerciseEntity.supportsLoadModeOverride,
                    ),
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

    final next = findNextRestTarget(
      exec,
      focusedExerciseIndex: _focusedExerciseIndex,
      focusedSetNumber: _focusedSetNumber,
    );
    final nextLabel = next != null
        ? l10n.nextUpLabel(
            _exerciseName(exec.exercises[next.exerciseIndex].exerciseId),
            next.setNumber,
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

    final next = findNextRestTarget(
      exec,
      focusedExerciseIndex: _focusedExerciseIndex,
      focusedSetNumber: _focusedSetNumber,
    );
    final nextLabel = next != null
        ? l10n.nextUpLabel(
            _exerciseName(exec.exercises[next.exerciseIndex].exerciseId),
            next.setNumber,
          )
        : l10n.allSetsComplete;

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

            const SizedBox(height: AthlosSpacing.md),
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
              child: next != null
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _goToNextSetFromTimer(exec),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              next.exerciseIndex == _focusedExerciseIndex
                                  ? l10n.nextSetLabel
                                  : l10n.nextExerciseButton,
                            ),
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
                    )
                  : Column(
                      children: [
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final completedReps = <int>[];
    for (final s in sets) {
      if (!s.isCompleted || s.isWarmup) continue;
      final n = repsForAggregateLoadFeedback(
        reps: s.reps,
        leftReps: s.leftReps,
        rightReps: s.rightReps,
      );
      if (n <= 0) continue;
      completedReps.add(n);
    }

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

  void _enterTimedManualEntry(ActiveExecutionState exec) {
    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final currentSetEntry = sets.firstWhere(
      (s) => s.setNumber == _focusedSetNumber,
      orElse: () => sets.first,
    );

    ref.read(cardioTimerProvider.notifier).reset();
    setState(() {
      _currentDuration =
          currentSetEntry.duration ??
          exercise.durationSeconds ??
          _currentDuration;
      _timedSubState = _TimedSubState.finishing;
      _viewMode = _ViewMode.timedSet;
    });
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final goalSeconds = exercise.durationSeconds ?? 0;

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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return AthlosScaffold(
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final hasReachedGoal = cardioState.hasReachedGoal;
    final isPaused = cardioState.isPaused;

    final timerColor = isPaused
        ? colorScheme.onSurfaceVariant
        : hasReachedGoal
        ? colorScheme.primary
        : colorScheme.onSurface;

    return AthlosScaffold(
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return AthlosScaffold(
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

    return AthlosScaffold(
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final goalSeconds = exercise.durationSeconds ?? 0;

    return AthlosScaffold(
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
                onPressed: () => _enterTimedManualEntry(exec),
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
        final goalSeconds = exercise.durationSeconds ?? 0;
        ref.read(cardioTimerProvider.notifier).start(goalSeconds);
        setState(() => _timedSubState = _TimedSubState.running);
      }
    });
  }

  Widget _buildTimedCountdown(ActiveExecutionState exec) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final exercise = exec.exercises[_focusedExerciseIndex];
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);

    return AthlosScaffold(
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final hasReachedGoal = cardioState.hasReachedGoal;

    final timerColor = hasReachedGoal
        ? colorScheme.primary
        : colorScheme.onSurface;

    return AthlosScaffold(
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
    final sets = exec.exerciseSets[exercise.id] ?? [];
    final name = _exerciseName(exercise.exerciseId);
    final goalSeconds = exercise.durationSeconds ?? 0;

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

    return AthlosScaffold(
      appBar: _timedAppBar(name, sets.length),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          children: [
            const Spacer(flex: 2),

            _NumberInput(
              value: _currentDuration.toDouble(),
              suffix: l10n.durationSecondsSuffix,
              step: 5,
              onChanged: (v) => setState(() => _currentDuration = v.toInt()),
              textTheme: textTheme,
              colorScheme: colorScheme,
              valueColor: diffColor,
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

    return AthlosScaffold(
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
            exercise.id,
            _focusedSetNumber,
            duration: _currentDuration > 0 ? _currentDuration : null,
            rpe: _selectedRpe,
          );
      rest = r;
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
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

    /// When unilateral drops are mirrored (linked limbs), persisted [rightReps]
    /// must match total reps on the ladder so volume scaling matches the left-arm
    /// segment sum (computeSetVolume divides by segment total reps).
    final int? rightRepsPersisted = !isUni
        ? null
        : !_unilateralSidesLinked
        ? (_rightReps > 0 ? _rightReps : null)
        : segments.isNotEmpty
        ? segments.fold<int>(0, (a, seg) => a + seg.reps)
        : (_rightReps > 0 ? _rightReps : null);

    final int rest;
    final double? suggestedWeight;
    try {
      final result = await ref
          .read(activeExecutionProvider.notifier)
          .completeSet(
            exercise.id,
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
            segments: segments.isEmpty ? null : segments,
            leftReps: isUni && _leftReps > 0 ? _leftReps : null,
            leftWeight: isUni && _leftWeight > 0 ? _leftWeight : null,
            rightReps: rightRepsPersisted,
            rightWeight: isUni && _rightWeight > 0 ? _rightWeight : null,
            isUnilateral: isUni,
          );
      rest = result.$1;
      suggestedWeight = result.$2;
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
      return;
    }

    if (!mounted) return;

    if (suggestedWeight != null) {
      context.showAthlosSnack(
        AppLocalizations.of(
          context,
        )!.suggestedWeightIncrease(suggestedWeight.toStringAsFixed(1)),
        duration: const Duration(seconds: 4),
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
            exercise.id,
            _focusedSetNumber,
            duration: _currentDuration > 0 ? _currentDuration : null,
            distance: _currentDistance > 0 ? _currentDistance : null,
            rpe: _selectedRpe,
          );
      rest = r;
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
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
    final exec = ref.read(activeExecutionProvider);
    if (exec == null) return;

    if (exec.isAdHoc) {
      if (exec.exercises.isEmpty || !exec.hasCompletedSets) {
        await _showAdHocFinishBlockedDialog(context);
        return;
      }
      final saveResult = await _showAdHocSaveDialog(context, exec);
      if (!context.mounted || saveResult == null) return;
      await _finishAdHocWithOutcome(
        context,
        exec,
        saveResult.outcome,
        saveResult.name,
      );
      return;
    }

    if (exec.hasTemplateChangesFromBaseline) {
      final outcome = await _showPlannedEditSaveDialog(context);
      if (!context.mounted || outcome == null) return;
      await _finishPlannedWithStructuralEdit(context, exec, outcome);
      return;
    }

    await _finishPlannedExecution(context, exec);
  }

  Future<void> _finishPlannedExecution(
    BuildContext context,
    ActiveExecutionState exec,
  ) async {
    final executionIdToShare = exec.executionId;
    try {
      await ref.read(activeExecutionProvider.notifier).finishExecution();
      ref.read(restTimerProvider.notifier).reset();
      ref.read(cardioTimerProvider.notifier).reset();
      if (context.mounted) {
        await _navigateAfterPlannedFinish(context, executionIdToShare);
      }
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  Future<void> _finishPlannedWithStructuralEdit(
    BuildContext context,
    ActiveExecutionState exec,
    PlannedWorkoutEditOutcome outcome,
  ) async {
    final executionIdToShare = exec.executionId;
    final l10n = AppLocalizations.of(context)!;
    final exercisesToPersist = List<WorkoutExercise>.from(exec.exercises);

    try {
      await ref.read(activeExecutionProvider.notifier).finishExecution();

      if (outcome == PlannedWorkoutEditOutcome.persist) {
        (await ref.read(applyPlannedWorkoutEditProvider).call(
              ApplyPlannedWorkoutEditParams(
                workoutId: exec.workoutId,
                exercises: exercisesToPersist,
                outcome: outcome,
              ),
            ))
            .getOrThrow();
        ref.invalidate(workoutByIdProvider(exec.workoutId));
        ref.invalidate(workoutExercisesProvider(exec.workoutId));
        ref.invalidate(workoutListProvider);
      }

      ref.read(restTimerProvider.notifier).reset();
      ref.read(cardioTimerProvider.notifier).reset();
      if (!context.mounted) return;
      await _navigateAfterPlannedFinish(context, executionIdToShare);
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(l10n.genericError);
      }
    }
  }

  Future<void> _navigateAfterPlannedFinish(
    BuildContext context,
    String executionIdToShare,
  ) async {
    final router = GoRouter.of(context);
    final l10n = AppLocalizations.of(context)!;
    context.showAthlosSuccessSnack(l10n.workoutFinished);

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

    if (context.mounted) {
      router.pop();
      final openSummary = ref.read(shouldAutoShowWorkoutShareSummaryProvider);
      if (openSummary) {
        router.push(
          RoutePaths.trainingExecutionShareSummary(executionIdToShare),
        );
      }
    }
  }

  Future<PlannedWorkoutEditOutcome?> _showPlannedEditSaveDialog(
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    return showAthlosDialog<PlannedWorkoutEditOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.plannedEditSaveTitle),
        content: Text(l10n.plannedEditSaveMessage),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(
                  ctx,
                  PlannedWorkoutEditOutcome.sessionOnly,
                ),
                child: Text(l10n.plannedEditSessionOnly),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(
                  ctx,
                  PlannedWorkoutEditOutcome.persist,
                ),
                child: Text(l10n.plannedEditPersist),
              ),
            ],
          ),
        ],
      ),
    );
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

  Future<void> _showAdHocFinishBlockedDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adHocFinishBlockedTitle),
        content: Text(l10n.adHocFinishBlockedMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }

  Future<({AdHocSaveOutcome outcome, String name})?> _showAdHocSaveDialog(
    BuildContext context,
    ActiveExecutionState exec,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final workout =
        ref.read(workoutByIdProvider(widget.workoutId)).value;
    final nameController = TextEditingController(
      text: workout?.name ?? l10n.improvisedWorkoutTitle,
    );

    String resolveName() {
      final trimmed = nameController.text.trim();
      return trimmed.isEmpty ? l10n.improvisedWorkoutTitle : trimmed;
    }

    return showAthlosDialog<({AdHocSaveOutcome outcome, String name})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adHocSaveTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.adHocSaveMessage),
            const SizedBox(height: AthlosSpacing.md),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.adHocSaveNameLabel,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    (
                      outcome: AdHocSaveOutcome.historyOnly,
                      name: resolveName(),
                    ),
                  );
                },
                child: Text(l10n.adHocSaveHistoryOnly),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    (
                      outcome: AdHocSaveOutcome.save,
                      name: resolveName(),
                    ),
                  );
                },
                child: Text(l10n.adHocSaveWorkout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _finishAdHocWithOutcome(
    BuildContext context,
    ActiveExecutionState exec,
    AdHocSaveOutcome outcome,
    String saveName,
  ) async {
    final router = GoRouter.of(context);
    final executionIdToShare = exec.executionId;
    final l10n = AppLocalizations.of(context)!;
    final program = ref.read(activeProgramProvider).value;
    if (program == null) return;

    try {
      await ref.read(activeExecutionProvider.notifier).finishExecution();

      await ref.read(promoteAdHocWorkoutProvider).call(
            PromoteAdHocWorkoutParams(
              workoutId: exec.workoutId,
              programId: program.id,
              name: saveName,
              exercises: exec.exercises,
              outcome: outcome,
            ),
          );

      ref.read(restTimerProvider.notifier).reset();
      ref.read(cardioTimerProvider.notifier).reset();
      ref.invalidate(workoutListProvider);
      ref.invalidate(cycleStepsProvider);
      ref.invalidate(cycleStepsForProgramProvider(program.id));
      ref.invalidate(nextWorkoutToStartProvider);

      if (!context.mounted) return;
      context.showAthlosSuccessSnack(l10n.workoutFinished);
      router.pop();

      if (ref.read(shouldAutoShowWorkoutShareSummaryProvider)) {
        router.push(
          RoutePaths.trainingExecutionShareSummary(executionIdToShare),
        );
      }
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(l10n.genericError);
      }
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
                      context.showAthlosErrorSnack(
                        AppLocalizations.of(context)!.genericError,
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
  final String? prescriptionSummary;
  final bool isAmrap;
  final int completedSets;
  final int totalSets;
  final bool isAllDone;
  final bool isActive;
  final bool isUnilateral;
  final bool isGroupedWithPrevious;
  final bool isGroupedWithNext;
  final int? groupColorIndex;
  final bool isSupersetSelectionActive;
  final bool isSupersetSelected;
  final bool isSupersetSelectionLocked;
  final int? reorderListIndex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _OverviewExerciseCard({
    required this.exerciseName,
    required this.muscleGroup,
    this.prescriptionSummary,
    this.isAmrap = false,
    required this.completedSets,
    required this.totalSets,
    required this.isAllDone,
    required this.isActive,
    this.isUnilateral = false,
    this.isGroupedWithPrevious = false,
    this.isGroupedWithNext = false,
    this.groupColorIndex,
    this.isSupersetSelectionActive = false,
    this.isSupersetSelected = false,
    this.isSupersetSelectionLocked = false,
    this.reorderListIndex,
    required this.onTap,
    this.onLongPress,
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
    if (isSupersetSelectionActive) {
      if (isSupersetSelectionLocked) {
        statusIcon = Icons.lock_outline;
        statusColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      } else {
        statusIcon = isSupersetSelected
            ? Icons.check_circle
            : Icons.circle_outlined;
        statusColor = isSupersetSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
      }
    } else if (isAllDone) {
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
          if (reorderListIndex != null)
            ReorderableDragStartListener(
              index: reorderListIndex!,
              child: Padding(
                padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                child: Icon(
                  Icons.drag_handle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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
                if (prescriptionSummary != null &&
                    prescriptionSummary!.isNotEmpty) ...[
                  const SizedBox(height: AthlosSpacing.xxs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prescriptionSummary!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isAmrap) ...[
                        const SizedBox(width: AthlosSpacing.xs),
                        Icon(
                          Icons.whatshot,
                          size: 12,
                          color: colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ],
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
          if (!isSupersetSelectionActive) ...[
            const SizedBox(width: AthlosSpacing.xs),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    BorderSide? cardBorder;
    if (isSupersetSelectionActive && isSupersetSelected) {
      cardBorder = BorderSide(color: colorScheme.primary, width: 2);
    } else if (groupColor != null) {
      cardBorder = BorderSide(color: groupColor.withValues(alpha: 0.4));
    }

    final card = Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      shape: cardBorder != null
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: cardBorder,
            )
          : RoundedRectangleBorder(borderRadius: AthlosRadius.mdAll),
      child: Container(
        decoration: groupColor != null
            ? BoxDecoration(
                borderRadius: AthlosRadius.mdAll,
                border: Border(left: BorderSide(color: groupColor, width: 4)),
              )
            : null,
        child: InkWell(
          onTap: isSupersetSelectionLocked ? null : onTap,
          onLongPress: isSupersetSelectionLocked ? null : onLongPress,
          borderRadius: AthlosRadius.mdAll,
          child: content,
        ),
      ),
    );

    if (!isSupersetSelectionLocked) return card;

    return Opacity(opacity: 0.45, child: card);
  }
}

// =============================================================================
// Number Input with +/- buttons
// =============================================================================

class _NumberInput extends StatelessWidget {
  final double value;
  final String suffix;

  /// Optional widget beside [suffix] (e.g. BW load explanation tooltip).
  final Widget? suffixTrailing;
  final double step;
  final ValueChanged<double> onChanged;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final Color? valueColor;
  final bool compact;

  const _NumberInput({
    required this.value,
    required this.suffix,
    this.suffixTrailing,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      suffix,
                      style: suffixStyle?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (suffixTrailing != null) ...[
                      const SizedBox(width: AthlosSpacing.xs),
                      suffixTrailing!,
                    ],
                  ],
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

/// RPE selector (1–10). Tap to select, tap again to deselect. Null = not recorded.
class _RpeSelector extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _RpeSelector({required this.value, required this.onChanged});

  static const List<int> _values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  Color _chipColor(int rpe, ColorScheme cs, AthlosCustomColors custom) {
    if (rpe >= 10) return cs.error;
    if (rpe >= 9) return custom.warning;
    if (rpe >= 7) return cs.primary;
    return cs.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final custom = Theme.of(context).extension<AthlosCustomColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l10n.rpeTooltip,
          triggerMode: TooltipTriggerMode.longPress,
          child: Text(
            l10n.rpeLabel,
            style: textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: AthlosSpacing.xs),
        Wrap(
          spacing: AthlosSpacing.xs,
          runSpacing: AthlosSpacing.xs,
          children: [
            for (final rpe in _values)
              _RpeChip(
                label: '$rpe',
                isSelected: value == rpe,
                color: _chipColor(rpe, cs, custom),
                colorScheme: cs,
                onTap: () => onChanged(value == rpe ? null : rpe),
              ),
          ],
        ),
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

/// Tiny target-board with a dart hitting the center (preset-rep “goal” cue).
class _RepsGoalTargetWithArrow extends StatelessWidget {
  final Color color;

  const _RepsGoalTargetWithArrow({required this.color});

  static const double _size = 14;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _size,
    height: _size,
    child: CustomPaint(painter: _RepsGoalTargetArrowPainter(color: color)),
  );
}

class _RepsGoalTargetArrowPainter extends CustomPainter {
  final Color color;

  _RepsGoalTargetArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(center.dx, center.dy) - 0.55;
    final ringW = (outerR * 0.11).clamp(0.75, 1.05);
    final shaftW = (outerR * 0.15).clamp(0.9, 1.25);

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringW
      ..isAntiAlias = true;

    canvas.drawCircle(center, outerR, ringPaint);
    canvas.drawCircle(center, outerR * 0.56, ringPaint);

    final start =
        center + Offset.fromDirection(-math.pi * 3 / 4, outerR * 0.92);
    final tip = center;
    final dir = (tip - start).direction;
    final headLen = outerR * 0.47;
    final halfBase = outerR * 0.22;
    final shaftEnd = tip - Offset.fromDirection(dir, headLen);

    final shaftPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = shaftW
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(start, shaftEnd, shaftPaint);

    final baseMid = tip - Offset.fromDirection(dir, headLen * 0.92);
    final baseA = baseMid + Offset.fromDirection(dir + math.pi / 2, halfBase);
    final baseB = baseMid + Offset.fromDirection(dir - math.pi / 2, halfBase);

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(baseA.dx, baseA.dy)
      ..lineTo(baseB.dx, baseB.dy)
      ..close();
    canvas.drawPath(
      headPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _RepsGoalTargetArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
