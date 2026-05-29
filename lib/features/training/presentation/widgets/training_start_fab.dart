import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../../domain/entities/workout.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';
import 'expandable_fab.dart';
import 'expandable_workout_fab.dart';

/// Single FAB: tap starts [nextWorkout]; corner chip opens the menu.
class TrainingStartFab extends ConsumerStatefulWidget {
  final Workout? nextWorkout;

  const TrainingStartFab({this.nextWorkout, super.key});

  @override
  ConsumerState<TrainingStartFab> createState() => _TrainingStartFabState();
}

class _TrainingStartFabState extends ConsumerState<TrainingStartFab> {
  bool _expanded = false;

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
  }

  void _openMenu() {
    if (_expanded) return;
    HapticFeedback.lightImpact();
    _setExpanded(true);
  }

  void _runMenuAction(VoidCallback action) {
    _setExpanded(false);
    action();
  }

  void _onPrimaryTap(Workout nextWorkout) {
    if (_expanded) {
      _setExpanded(false);
      return;
    }
    launchWorkoutExecution(context, ref, workoutId: nextWorkout.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasActiveProgram = ref.watch(activeProgramProvider).value != null;

    if (!hasActiveProgram) {
      return FloatingActionButton(
        heroTag: 'training_shell_start_fab',
        onPressed: () => context.push(RoutePaths.trainingProgramNew),
        tooltip: l10n.noProgramActiveCreateAction,
        child: const Icon(Icons.add),
      );
    }

    final hasCycleSteps =
        (ref.watch(effectiveCycleStepsProvider).value ?? const []).isNotEmpty;
    final nextWorkout = widget.nextWorkout;

    if (nextWorkout == null) {
      if (hasCycleSteps) {
        return FloatingActionButton(
          heroTag: 'training_shell_start_fab',
          onPressed: () => launchAdHocWorkoutExecution(context, ref),
          tooltip: l10n.startImprovisedWorkoutAction,
          child: const Icon(Icons.edit_note_outlined),
        );
      }
      return ExpandableWorkoutFab(
        heroTag: 'training_shell_start_fab',
        chironLabel: l10n.chironCreateWorkoutShortcut,
        createManualLabel: l10n.trainingWorkoutActionCreateManual,
        startDraftLabel: l10n.startImprovisedWorkoutAction,
        onChiron: () => showChironSheet(
          context,
          initialMessage: l10n.chironAskToCreateWorkout,
        ),
        onCreateManual: () => context.push(RoutePaths.trainingWorkoutNew),
        onStartDraft: () => launchAdHocWorkoutExecution(context, ref),
      );
    }

    final primaryTooltip = _expanded
        ? l10n.cancel
        : '${l10n.trainingStartFabStartNext(nextWorkout.name)}\n'
            '${l10n.trainingStartFabStartNextHint}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ExpandableFabMenu(
          expanded: _expanded,
          actions: [
            ExpandableFabAction(
              icon: Icons.play_circle_outline,
              label: l10n.trainingStartFabNextLabel,
              subtitle: nextWorkout.name,
              onPressed: () => launchWorkoutExecution(
                context,
                ref,
                workoutId: nextWorkout.id,
              ),
            ),
            ExpandableFabAction(
              icon: Icons.edit_note_outlined,
              label: l10n.improvisedWorkoutTitle,
              subtitle: l10n.trainingStartFabImprovisedHint,
              onPressed: () => launchAdHocWorkoutExecution(context, ref),
            ),
          ],
          onActionSelected: _runMenuAction,
        ),
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Tooltip(
                message: primaryTooltip,
                child: FloatingActionButton(
                  heroTag: 'training_shell_start_fab',
                  onPressed: () => _onPrimaryTap(nextWorkout),
                  child: AnimatedSwitcher(
                    duration: AthlosDurations.fast,
                    child: Icon(
                      _expanded
                          ? Icons.close_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey(_expanded),
                    ),
                  ),
                ),
              ),
              if (!_expanded)
                Positioned(
                  right: -2,
                  top: -2,
                  child: _FabMoreOptionsChip(
                    tooltip: l10n.trainingStartFabMoreOptions,
                    onPressed: _openMenu,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small chip on the FAB corner — opens the workout menu.
class _FabMoreOptionsChip extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const _FabMoreOptionsChip({
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: AthlosElevation.sm,
        shape: CircleBorder(
          side: BorderSide(color: colorScheme.surface, width: 2),
        ),
        color: colorScheme.secondaryContainer,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
