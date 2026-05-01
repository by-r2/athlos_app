import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_button_sizes.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/cycle_step.dart';
import '../../domain/entities/workout.dart';
import '../../domain/enums/program_focus.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/workout_notifier.dart';

/// Training module — Treinos tab.
///
/// Shows the active program's cycle as a clean ordered list of workouts.
/// Gear icon opens ProgramDetailScreen for advanced settings (progression,
/// deload, etc.). The "add workout" picker shows the personal catalog.
class TrainingWorkoutsScreen extends ConsumerWidget {
  const TrainingWorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(activeProgramProvider);
    final program = programAsync.value;

    final nextWorkoutAsync = ref.watch(nextWorkoutToStartProvider);
    final nextWorkout = nextWorkoutAsync.value;

    return Scaffold(
      body: program == null
          ? programAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const _NoProgramActiveView()
          : _ActiveProgramCycleView(programId: program.id),
      floatingActionButton: _StartNextWorkoutFab(nextWorkout: nextWorkout),
    );
  }
}

// ── Start Next Workout FAB ────────────────────────────────────────────

class _StartNextWorkoutFab extends StatelessWidget {
  final dynamic nextWorkout;

  const _StartNextWorkoutFab({this.nextWorkout});

  @override
  Widget build(BuildContext context) {
    if (nextWorkout == null) return const SizedBox.shrink();

    return FloatingActionButton(
      heroTag: 'workouts_fab',
      onPressed: () => context.push(
        '${RoutePaths.trainingWorkouts}/${nextWorkout.id}/execute',
      ),
      tooltip: nextWorkout.name,
      child: const Icon(Icons.play_arrow),
    );
  }
}

// ── Active program cycle view ─────────────────────────────────────────

class _ActiveProgramCycleView extends ConsumerStatefulWidget {
  final int programId;

  const _ActiveProgramCycleView({required this.programId});

  @override
  ConsumerState<_ActiveProgramCycleView> createState() =>
      _ActiveProgramCycleViewState();
}

class _ActiveProgramCycleViewState
    extends ConsumerState<_ActiveProgramCycleView> {
  List<int>? _workoutIds;

  void _syncFromSteps(List<TrainingCycleStep> steps) {
    _workoutIds ??= steps.map((s) => s.workoutId).toList();
  }

  Future<void> _saveOrder() async {
    if (_workoutIds == null) return;
    final repo = ref.read(cycleRepositoryProvider);
    final steps = [
      for (var i = 0; i < _workoutIds!.length; i++)
        TrainingCycleStep(id: 0, orderIndex: i, workoutId: _workoutIds![i]),
    ];
    final result = await repo.setSteps(steps, widget.programId);
    result.getOrThrow();
    ref.invalidate(cycleStepsProvider);
    ref.invalidate(cycleStepsForProgramProvider(widget.programId));
  }

  void _addWorkout(int workoutId) {
    setState(() {
      _workoutIds = [...?_workoutIds, workoutId];
    });
    _saveOrder();
  }

  void _removeAt(int index) {
    setState(() {
      _workoutIds = [...?_workoutIds]..removeAt(index);
    });
    _saveOrder();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final ids = [...?_workoutIds];
      final item = ids.removeAt(oldIndex);
      ids.insert(newIndex, item);
      _workoutIds = ids;
    });
    _saveOrder();
  }

  void _showAddWorkoutPicker(
    BuildContext context,
    List<Workout> workouts,
    List<int> cycleWorkoutIds,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Text(
                  l10n.trainingCycleAddWorkout,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...workouts.map((w) {
                      final isInCycle = cycleWorkoutIds.contains(w.id);
                      return ListTile(
                        leading: Icon(
                          isInCycle
                              ? Icons.check_circle
                              : Icons.fitness_center,
                          color: isInCycle
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(w.name),
                        subtitle:
                            w.description != null && w.description!.isNotEmpty
                                ? Text(
                                    w.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                        onTap: () {
                          _addWorkout(w.id);
                          Navigator.of(ctx).pop();
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.edit_note,
                          color: colorScheme.primary),
                      title: Text(
                        l10n.trainingWorkoutActionCreateManual,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.push(RoutePaths.trainingWorkoutNew);
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.auto_awesome,
                          color: colorScheme.primary),
                      title: Text(
                        l10n.chironCreateWorkoutShortcut,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        showChironSheet(
                          context,
                          initialMessage: l10n.chironAskToCreateWorkout,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(activeProgramProvider);
    final program = programAsync.value;

    final stepsAsync =
        ref.watch(cycleStepsForProgramProvider(widget.programId));
    final workoutsAsync = ref.watch(workoutListProvider);
    final workouts = workoutsAsync.value ?? [];

    final nextWorkoutAsync = ref.watch(nextWorkoutToStartProvider);
    final nextWorkoutId = nextWorkoutAsync.value?.id;

    stepsAsync.whenData(_syncFromSteps);

    final ids = _workoutIds ?? [];
    final workoutMap = {for (final w in workouts) w.id: w};

    final l10n = AppLocalizations.of(context)!;

    if (ids.isEmpty && !stepsAsync.isLoading) {
      return Column(
        children: [
          if (program != null) _ProgramHeader(program: program),
          Expanded(
            child: _EmptyCycleMessage(
              workouts: workouts,
              onAddWorkout: _addWorkout,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (program != null) _ProgramHeader(program: program),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.sm,
              AthlosSpacing.xs,
              AthlosSpacing.sm,
              AthlosSpacing.fabClearance,
            ),
            itemCount: ids.length + 1,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex >= ids.length || newIndex > ids.length) return;
              _reorder(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              if (index == ids.length) {
                return Padding(
                  key: const ValueKey('add-workout-btn'),
                  padding: const EdgeInsets.only(top: AthlosSpacing.xs),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AthlosButtonSizes.screenMinHeight,
                        ),
                      ),
                      onPressed: () =>
                          _showAddWorkoutPicker(context, workouts, ids),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.trainingCycleAddWorkout),
                    ),
                  ),
                );
              }

              final workoutId = ids[index];
              final workout = workoutMap[workoutId];
              final isNext = workoutId == nextWorkoutId;
              return _CycleWorkoutCard(
                key: ValueKey('cycle-$index-$workoutId'),
                index: index,
                workoutName: workout?.name ?? 'Treino #$workoutId',
                workoutDescription: workout?.description,
                isNext: isNext,
                onTap: workout != null
                    ? () => context.push(
                          '${RoutePaths.trainingWorkouts}/${workout.id}',
                        )
                    : null,
                onStart: () => context.push(
                  '${RoutePaths.trainingWorkouts}/$workoutId/execute',
                ),
                onRemove: () => _removeAt(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Program header (name + focus, inline) ─────────────────────────────

class _ProgramHeader extends ConsumerWidget {
  final dynamic program;

  const _ProgramHeader({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final focusLabel = switch (program.focus as ProgramFocus) {
      ProgramFocus.hypertrophy => l10n.programFocusHypertrophy,
      ProgramFocus.strength => l10n.programFocusStrength,
      ProgramFocus.endurance => l10n.programFocusEndurance,
      ProgramFocus.custom => l10n.programFocusCustom,
    };

    final programId = program.id as int;
    final progressAsync = ref.watch(programProgressProvider(programId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AthlosSpacing.md,
        AthlosSpacing.sm,
        AthlosSpacing.xs,
        AthlosSpacing.xs,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.primary, size: 18),
              const Gap(AthlosSpacing.sm),
              Expanded(
                child: Text(
                  program.name as String,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                  vertical: AthlosSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: AthlosRadius.smAll,
                ),
                child: Text(
                  focusLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (program.isInDeload as bool) ...[
                const Gap(AthlosSpacing.xxs),
                Icon(Icons.spa, size: 16, color: colorScheme.tertiary),
              ],
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: l10n.programAdvancedSettings,
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    context.push(RoutePaths.trainingProgramDetail(programId)),
              ),
            ],
          ),
          const Gap(AthlosSpacing.xs),
          progressAsync.when(
            data: (progress) => Padding(
              padding: const EdgeInsets.only(right: AthlosSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AthlosRadius.smAll,
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 4,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const Gap(AthlosSpacing.sm),
                  Text(
                    '${progress.completedSessions}/${progress.totalSessions}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.only(right: AthlosSpacing.sm),
              child: LinearProgressIndicator(minHeight: 4),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Cycle workout card ────────────────────────────────────────────────

class _CycleWorkoutCard extends StatelessWidget {
  final int index;
  final String workoutName;
  final String? workoutDescription;
  final bool isNext;
  final VoidCallback? onTap;
  final VoidCallback onStart;
  final VoidCallback onRemove;

  const _CycleWorkoutCard({
    super.key,
    required this.index,
    required this.workoutName,
    this.workoutDescription,
    required this.isNext,
    this.onTap,
    required this.onStart,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      shape: isNext
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.6),
                  width: 1.5),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AthlosSpacing.xs,
            right: AthlosSpacing.xs,
          ),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(AthlosSpacing.sm),
                  child: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (isNext) ...[
                Icon(Icons.arrow_right, size: 20, color: colorScheme.primary),
                const Gap(AthlosSpacing.xxs),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workoutName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: isNext ? FontWeight.w600 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (workoutDescription != null &&
                        workoutDescription!.isNotEmpty)
                      Text(
                        workoutDescription!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.play_circle_outline,
                  color: isNext ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                tooltip: l10n.startWorkout,
                onPressed: onStart,
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                tooltip: l10n.remove,
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No active program view ────────────────────────────────────────────

class _NoProgramActiveView extends ConsumerWidget {
  const _NoProgramActiveView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final programsAsync = ref.watch(programListProvider);
    final archivedPrograms = programsAsync.value
            ?.where((p) => !p.isActive)
            .toList() ??
        [];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const Gap(AthlosSpacing.md),
            Text(
              l10n.noProgramActiveTitle,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              l10n.noProgramActiveHint,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(AthlosSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.trainingProgramNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.noProgramActiveCreateAction),
            ),
            if (archivedPrograms.isNotEmpty) ...[
              const Gap(AthlosSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.trainingPrograms),
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.noProgramActiveViewArchived),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty cycle message ───────────────────────────────────────────────

class _EmptyCycleMessage extends StatelessWidget {
  final List<Workout> workouts;
  final void Function(int workoutId) onAddWorkout;

  const _EmptyCycleMessage({
    required this.workouts,
    required this.onAddWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const Gap(AthlosSpacing.md),
            Text(
              l10n.programCycleSection,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              l10n.programCycleHint,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
