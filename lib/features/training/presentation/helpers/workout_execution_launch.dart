import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_user_id.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/enums/session_kind.dart';
import '../../domain/usecases/start_ad_hoc_workout_execution.dart';
import 'workout_execution_blocking.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/dangling_execution_dialog_session.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_execution_notifier.dart';

export 'workout_execution_blocking.dart';

/// Refreshes the dangling-execution cache after a local discard/finish.
Future<void> refreshDanglingExecution(WidgetRef ref) async {
  if (!isValidSyncUserId(ref.read(authProvider).value?.id)) return;
  ref.invalidate(danglingExecutionProvider);
  await ref.read(danglingExecutionProvider.future);
}

/// Removes unfinished executions that block [targetWorkoutId].
///
/// When [forceNewForTarget] is true, also discards an unfinished row for the
/// same workout so a brand-new session can start.
Future<void> clearDanglingBlockingWorkout(
  WidgetRef ref, {
  required String targetWorkoutId,
  bool forceNewForTarget = false,
}) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    ref.invalidate(danglingExecutionProvider);
    final dangling = await ref.read(danglingExecutionProvider.future);
    if (kDebugMode && (dangling != null || attempt > 0)) {
      debugPrint(
        '[DanglingExecution] clearBlocking(attempt=$attempt) target=$targetWorkoutId '
        'dangling=${dangling?.id} workout=${dangling?.workoutId} finished=${dangling?.isFinished} '
        'forceNewForTarget=$forceNewForTarget',
      );
    }
    if (dangling == null) return;

    final isTarget = dangling.workoutId == targetWorkoutId;
    if (isTarget && !forceNewForTarget && !dangling.isFinished) {
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[DanglingExecution] clearBlocking: discarding ${dangling.id} (workout=${dangling.workoutId})',
      );
    }
    await ref
        .read(activeExecutionProvider.notifier)
        .discardExecution(dangling.id);
  }
}

enum _WorkoutLaunchConflictChoice { cancel, resumeInProgress, discardAndStart }

enum _HomeDanglingChoice { discard, resume }

/// Creates a draft workout and opens improvised execution.
///
/// Returns `true` if the execute route was opened.
Future<bool> launchAdHocWorkoutExecution(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final program = (await ref.read(programRepositoryProvider).getActive())
      .getOrThrow();
  if (program == null) {
    if (context.mounted) {
      context.showAthlosErrorSnack(l10n.noProgramActiveHint);
    }
    return false;
  }

  if (!context.mounted) return false;
  final dateLabel = MaterialLocalizations.of(context).formatShortDate(
    DateTime.now(),
  );
  final draftName = l10n.improvisedWorkoutDefaultName(dateLabel);
  final draftId = (await ref
          .read(startAdHocWorkoutExecutionProvider)
          .call(StartAdHocWorkoutExecutionParams(draftWorkoutName: draftName)))
      .getOrThrow();

  if (!context.mounted) return false;
  return launchWorkoutExecution(context, ref, workoutId: draftId);
}

/// Navigates to [workoutId]/execute when allowed.
///
/// Returns `true` if the execute route was opened for [workoutId].
Future<bool> launchWorkoutExecution(
  BuildContext context,
  WidgetRef ref, {
  required String workoutId,
}) async {
  ref.invalidate(danglingExecutionProvider);
  final blocking = await resolveBlockingInProgressWorkout(ref, workoutId);
  if (!context.mounted) return false;

  if (blocking == null) {
    context.push(_executeRoute(workoutId));
    return true;
  }

  if (blocking.workoutId == workoutId) {
    context.push(_executeRoute(workoutId));
    return true;
  }

  final l10n = AppLocalizations.of(context)!;
  final inProgressName =
      await _workoutDisplayName(ref, blocking.workoutId) ?? '—';
  final newWorkoutName = await _workoutDisplayName(ref, workoutId) ?? '—';
  if (!context.mounted) return false;

  final choice = await showAthlosDialog<_WorkoutLaunchConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.danglingExecutionConflictTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.danglingExecutionConflictMessage(
              inProgressName,
              newWorkoutName,
            ),
          ),
        ],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () =>
                  Navigator.pop(ctx, _WorkoutLaunchConflictChoice.cancel),
              child: Text(l10n.cancel),
            ),
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () => Navigator.pop(
                ctx,
                _WorkoutLaunchConflictChoice.resumeInProgress,
              ),
              child: Text(l10n.danglingExecutionResumeInProgress),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(ctx),
              onPressed: () => Navigator.pop(
                ctx,
                _WorkoutLaunchConflictChoice.discardAndStart,
              ),
              child: Text(l10n.danglingExecutionDiscardAndStart),
            ),
          ],
        ),
      ],
    ),
  );

  if (!context.mounted || choice == null) return false;

  switch (choice) {
    case _WorkoutLaunchConflictChoice.cancel:
      return false;
    case _WorkoutLaunchConflictChoice.resumeInProgress:
      context.push(_executeRoute(blocking.workoutId));
      return false;
    case _WorkoutLaunchConflictChoice.discardAndStart:
      try {
        await ref
            .read(activeExecutionProvider.notifier)
            .discardExecution(blocking.executionId);
        await clearDanglingBlockingWorkout(
          ref,
          targetWorkoutId: workoutId,
          forceNewForTarget: true,
        );
        if (!context.mounted) return false;
        context.push(_executeRoute(workoutId, fresh: true));
        return true;
      } on Exception catch (_) {
        if (context.mounted) {
          context.showAthlosErrorSnack(l10n.genericError);
        }
        return false;
      }
  }
}

/// Shows resume/discard dialog on the training home tab when a dangling exists.
Future<void> showDanglingExecutionHomeDialogIfNeeded(
  BuildContext context,
  WidgetRef ref,
  WorkoutExecution execution,
) async {
  final session = ref.read(danglingExecutionDialogSessionProvider.notifier);
  if (!session.tryBeginHomePrompt(execution.id)) return;

  final l10n = AppLocalizations.of(context)!;
  final workoutName =
      await _workoutDisplayName(ref, execution.workoutId) ?? '—';
  if (!context.mounted) {
    session.cancelHomePrompt();
    return;
  }

  final choice = await showAthlosDialog<_HomeDanglingChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.danglingExecutionTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(l10n.danglingExecutionMessage(workoutName))],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () => Navigator.pop(ctx, _HomeDanglingChoice.discard),
              child: Text(l10n.danglingExecutionDiscard),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(ctx),
              onPressed: () => Navigator.pop(ctx, _HomeDanglingChoice.resume),
              child: Text(l10n.danglingExecutionResume),
            ),
          ],
        ),
      ],
    ),
  );

  if (!context.mounted) {
    session.cancelHomePrompt();
    return;
  }

  if (choice == null) {
    session.cancelHomePrompt();
    return;
  }

  try {
    switch (choice) {
      case _HomeDanglingChoice.resume:
        await resumeWorkoutExecution(ref, execution: execution);
        session.completeHomePrompt(execution.id);
        if (context.mounted) {
          context.push(_executeRoute(execution.workoutId));
        }
      case _HomeDanglingChoice.discard:
        session.cancelHomePrompt();
        await ref
            .read(activeExecutionProvider.notifier)
            .discardExecution(execution.id);
        await refreshDanglingExecution(ref);
        session.completeHomePrompt(execution.id);
        if (!context.mounted) return;
        final routerState = GoRouterState.of(context);
        final currentUri = routerState.uri;
        final currentPath = currentUri.path;

        final looksLikeExecute =
            currentPath.contains('/execute') && currentPath.contains(execution.workoutId);
        if (looksLikeExecute) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RoutePaths.trainingWorkouts);
          }
        }
    }
  } on Exception catch (_) {
    session.cancelHomePrompt();
    if (context.mounted) {
      context.showAthlosErrorSnack(l10n.genericError);
    }
  }
}

Future<void> resumeWorkoutExecution(
  WidgetRef ref, {
  required WorkoutExecution execution,
}) async {
  final wRepo = ref.read(workoutRepositoryProvider);
  final pRepo = ref.read(programRepositoryProvider);
  final workout = (await wRepo.getById(execution.workoutId)).getOrThrow();
  final isAdHoc =
      execution.sessionKind == SessionKind.adHoc || (workout?.isDraft ?? false);
  final exercises =
      (await wRepo.getExercises(execution.workoutId)).getOrThrow();
  final program = (await pRepo.getActive()).getOrThrow();
  final allExercises = ref.read(exerciseListProvider).value ?? [];
  final isometricIds = {
    for (final e in allExercises)
      if (e.isIsometric) e.id,
  };
  await ref.read(activeExecutionProvider.notifier).resumeExecution(
        execution.id,
        execution.workoutId,
        exercises,
        programId: execution.programId,
        defaultRestSeconds: program?.defaultRestSeconds ?? 0,
        isometricExerciseIds: isometricIds,
        isAdHoc: isAdHoc,
      );
}

/// Returns blocking in-progress workout for [targetWorkoutId], or null if safe.
Future<BlockingInProgressWorkout?> resolveBlockingInProgressWorkout(
  WidgetRef ref,
  String targetWorkoutId,
) async {
  final dangling = await ref.read(danglingExecutionProvider.future);
  final active = ref.read(activeExecutionProvider);
  return blockingInProgressWorkout(
    dangling: dangling,
    active: active,
    targetWorkoutId: targetWorkoutId,
  );
}

Future<String?> _workoutDisplayName(WidgetRef ref, String workoutId) async {
  final workout =
      (await ref.read(workoutRepositoryProvider).getById(workoutId))
          .getOrThrow();
  return workout?.name;
}

String _executeRoute(String workoutId, {bool fresh = false}) =>
    '${RoutePaths.trainingWorkouts}/$workoutId/execute'
    '${fresh ? '?fresh=1' : ''}';
