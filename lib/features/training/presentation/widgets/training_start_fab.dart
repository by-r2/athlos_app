import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';

/// Single FAB: tap starts [nextWorkout]; long press or corner chip opens the menu.
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

  Future<void> _runMenuAction(Future<void> Function() action) async {
    _setExpanded(false);
    await action();
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
    final colorScheme = Theme.of(context).colorScheme;
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
      return FloatingActionButton(
        heroTag: 'training_shell_start_fab',
        onPressed: () {
          context.go(RoutePaths.trainingWorkoutsOpenCyclePickerQuery());
        },
        tooltip: l10n.trainingCycleAddWorkout,
        child: const Icon(Icons.add),
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
        AnimatedSize(
          duration: AthlosDurations.normal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                  child: Material(
                    elevation: AthlosElevation.md,
                    borderRadius: AthlosRadius.lgAll,
                    color: colorScheme.surface,
                    clipBehavior: Clip.antiAlias,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AthlosRadius.lgAll,
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 280,
                          maxWidth: 320,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AthlosSpacing.md,
                                AthlosSpacing.md,
                                AthlosSpacing.md,
                                AthlosSpacing.xs,
                              ),
                              child: Text(
                                l10n.trainingStartFabMenuTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            _TrainingStartFabMenuTile(
                              icon: Icons.play_circle_outline,
                              title: l10n.trainingStartFabNextLabel,
                              subtitle: nextWorkout.name,
                              isEmphasized: true,
                              onTap: () => _runMenuAction(
                                () => launchWorkoutExecution(
                                  context,
                                  ref,
                                  workoutId: nextWorkout.id,
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant,
                            ),
                            _TrainingStartFabMenuTile(
                              icon: Icons.edit_note_outlined,
                              title: l10n.improvisedWorkoutTitle,
                              subtitle: l10n.trainingStartFabImprovisedHint,
                              onTap: () => _runMenuAction(
                                () => launchAdHocWorkoutExecution(context, ref),
                              ),
                            ),
                            const SizedBox(height: AthlosSpacing.xs),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onLongPress: _openMenu,
                child: Tooltip(
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

/// Small chip on the FAB corner — opens the workout menu (visible alternative to long press).
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

class _TrainingStartFabMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEmphasized;
  final VoidCallback onTap;

  const _TrainingStartFabMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isEmphasized = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final avatarBackground = isEmphasized
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final iconColor = isEmphasized
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Material(
      color: isEmphasized
          ? colorScheme.primaryContainer.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AthlosComponentSizes.listItemMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.md,
              vertical: AthlosSpacing.sm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarBackground,
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: AthlosSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AthlosTruncatedText(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: AthlosSpacing.xxs),
                      AthlosTruncatedText(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
