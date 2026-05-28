import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_button_sizes.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/cycle_step.dart';
import '../../domain/entities/workout.dart';
import '../../domain/enums/program_focus.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/workout_notifier.dart';
import '../../../../core/widgets/layout/athlos_section.dart';

/// First logical line of workout notes (before the first newline). Null if empty.
String? _workoutNotesFirstLine(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final first = trimmed.split(RegExp(r'\r?\n')).first.trim();
  return first.isEmpty ? null : first;
}

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

    return Scaffold(
      body: program == null
          ? programAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const _NoProgramActiveView()
          : _ActiveProgramCycleView(programId: program.id),
    );
  }
}

// ── Active program cycle view ─────────────────────────────────────────

class _ActiveProgramCycleView extends ConsumerStatefulWidget {
  final String programId;

  const _ActiveProgramCycleView({required this.programId});

  @override
  ConsumerState<_ActiveProgramCycleView> createState() =>
      _ActiveProgramCycleViewState();
}

class _ActiveProgramCycleViewState
    extends ConsumerState<_ActiveProgramCycleView> {
  List<String>? _workoutIds;

  void _syncFromSteps(List<TrainingCycleStep> steps) {
    _workoutIds ??= steps.map((s) => s.workoutId).toList();
  }

  Future<void> _saveOrder() async {
    if (_workoutIds == null) return;
    final repo = ref.read(cycleRepositoryProvider);
    final steps = [
      for (var i = 0; i < _workoutIds!.length; i++)
        TrainingCycleStep(id: '', orderIndex: i, workoutId: _workoutIds![i]),
    ];
    final result = await repo.setSteps(steps, widget.programId);
    result.getOrThrow();
    ref.invalidate(cycleStepsProvider);
    ref.invalidate(cycleStepsForProgramProvider(widget.programId));
  }

  void _addWorkout(String workoutId) {
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

  void _showRemoveFromCycleSheet(
    BuildContext context,
    int index, {
    required String workoutName,
    String? workoutDescription,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showAthlosModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final descPreview = _workoutNotesFirstLine(workoutDescription);
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
                Text(workoutName, style: textTheme.titleMedium),
                if (descPreview != null) ...[
                  const Gap(AthlosSpacing.sm),
                  AthlosTruncatedText(
                    descPreview,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    showOverflowTooltip: false,
                  ),
                ],
                const Gap(AthlosSpacing.md),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    l10n.trainingCycleRemoveWorkout,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeAt(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCyclePickerFromRouteIfNeeded(BuildContext context) {
    final qp = GoRouterState.of(context).uri.queryParameters;
    if (qp[RoutePaths.queryOpenProgramCyclePicker] != '1') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      context.go(RoutePaths.trainingWorkouts);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final workouts = ref.read(workoutListProvider).value ?? [];
        if (!context.mounted) return;
        _showAddWorkoutPicker(context, workouts, _workoutIds ?? []);
      });
    });
  }

  void _showAddWorkoutPicker(
    BuildContext context,
    List<Workout> workouts,
    List<String> cycleWorkoutIds,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    showAthlosModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      wrapInShell: false,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => AthlosBottomSheetShell(
          expand: true,
          child: Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(ctx).bottom,
              ),
              children: [
                AthlosBottomSheetHeader(
                  title: l10n.trainingCycleAddWorkout,
                  subtitle: l10n.trainingCycleAddWorkoutSubtitle,
                  icon: Icons.playlist_add_rounded,
                ),
                ...workouts.map((w) {
                final isInCycle = cycleWorkoutIds.contains(w.id);
                return ListTile(
                  minTileHeight: AthlosComponentSizes.listItemMinHeight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                  ),
                  leading: Icon(
                    isInCycle ? Icons.check_circle : Icons.fitness_center,
                    color: isInCycle
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(w.name),
                  subtitle: w.description != null && w.description!.isNotEmpty
                      ? AthlosTruncatedText(w.description!, maxLines: 1)
                      : null,
                  onTap: () {
                    _addWorkout(w.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AthlosSpacing.md,
                  AthlosSpacing.md,
                  AthlosSpacing.md,
                  AthlosSpacing.sm,
                ),
                child: AthlosStackedActions(
                  children: [
                    TextButton.icon(
                      style: AthlosScreenButtonStyles.stackedGhost(ctx),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        showChironSheet(
                          context,
                          initialMessage: l10n.chironAskToCreateWorkout,
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(l10n.chironCreateWorkoutShortcut),
                    ),
                    FilledButton.icon(
                      style: AthlosScreenButtonStyles.stackedFilled(ctx),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.push(RoutePaths.trainingWorkoutNew);
                      },
                      icon: const Icon(Icons.edit_note_outlined),
                      label: Text(l10n.trainingWorkoutActionCreateManual),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final programAsync = ref.watch(activeProgramProvider);
    final program = programAsync.value;

    final stepsAsync = ref.watch(
      cycleStepsForProgramProvider(widget.programId),
    );
    final workoutsAsync = ref.watch(workoutListProvider);
    final workouts = workoutsAsync.value ?? [];

    final nextWorkoutAsync = ref.watch(nextWorkoutToStartProvider);
    final nextWorkoutId = nextWorkoutAsync.value?.id;

    stepsAsync.whenData(_syncFromSteps);

    final ids = _workoutIds ?? [];
    final workoutMap = {for (final w in workouts) w.id: w};

    final l10n = AppLocalizations.of(context)!;

    if (ids.isEmpty && !stepsAsync.isLoading) {
      _openCyclePickerFromRouteIfNeeded(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AthlosSpacing.md,
          AthlosSpacing.sm,
          AthlosSpacing.md,
          AthlosSpacing.fabClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (program != null) _ProgramSummaryCard(program: program),
            const Gap(AthlosSpacing.md),
            AthlosSection(
              title: l10n.programCycleSection,
              subtitle: l10n.programCycleHint,
              icon: Icons.repeat_rounded,
            ),
            _CycleAddWorkoutButton(
              label: l10n.trainingCycleAddWorkout,
              onPressed: () => _showAddWorkoutPicker(context, workouts, ids),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            AthlosSpacing.sm,
            AthlosSpacing.md,
            0,
          ),
          child: program != null ? _ProgramSummaryCard(program: program) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            AthlosSpacing.md,
            AthlosSpacing.md,
            0,
          ),
          child: AthlosSection(
            title: l10n.programCycleSection,
            subtitle: l10n.programCycleHint,
            icon: Icons.repeat_rounded,
            trailing: _CycleWorkoutCountBadge(count: ids.length),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              0,
              AthlosSpacing.md,
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
                  padding: const EdgeInsets.only(top: AthlosSpacing.sm),
                  child: _CycleAddWorkoutButton(
                    label: l10n.trainingCycleAddWorkout,
                    onPressed: () =>
                        _showAddWorkoutPicker(context, workouts, ids),
                    filled: false,
                  ),
                );
              }

              final workoutId = ids[index];
              final workout = workoutMap[workoutId];
              final descLine = _workoutNotesFirstLine(workout?.description);
              final isNext = workoutId == nextWorkoutId;
              return Dismissible(
                key: ValueKey('cycle-$index-$workoutId'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async => true,
                onDismissed: (_) => _removeAt(index),
                // Flutter requires [background] whenever [secondaryBackground] is set.
                background: Container(
                  margin: const EdgeInsets.only(bottom: AthlosSpacing.xs),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: AthlosRadius.mdAll,
                  ),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AthlosSpacing.lg),
                  margin: const EdgeInsets.only(bottom: AthlosSpacing.xs),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: AthlosRadius.mdAll,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                child: _CycleWorkoutCard(
                  index: index,
                  workoutName: workout?.name ?? 'Treino #$workoutId',
                  workoutDescription: descLine,
                  isNext: isNext,
                  onTap: workout != null
                      ? () => context.push(
                          '${RoutePaths.trainingWorkouts}/${workout.id}',
                        )
                      : null,
                  onStart: () => launchWorkoutExecution(
                    context,
                    ref,
                    workoutId: workoutId,
                  ),
                  onLongPress: () => _showRemoveFromCycleSheet(
                    context,
                    index,
                    workoutName: workout?.name ?? 'Treino #$workoutId',
                    workoutDescription: descLine,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Program summary card ──────────────────────────────────────────────

class _ProgramSummaryCard extends ConsumerWidget {
  final dynamic program;

  const _ProgramSummaryCard({required this.program});

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

    final programId = program.id as String;
    final progressAsync = ref.watch(programProgressProvider(programId));

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AthlosRadius.mdAll,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.trainingProgramDetail(programId)),
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const Gap(AthlosSpacing.sm),
                  Expanded(
                    child: AthlosTruncatedText(
                      program.name as String,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (program.isInDeload as bool) ...[
                    const Gap(AthlosSpacing.xs),
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
                    onPressed: () => context.push(
                      RoutePaths.trainingProgramDetail(programId),
                    ),
                  ),
                ],
              ),
              const Gap(AthlosSpacing.sm),
              progressAsync.when(
                data: (progress) => Row(
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(minHeight: 4),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleWorkoutCountBadge extends StatelessWidget {
  const _CycleWorkoutCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AthlosRadius.smAll,
      ),
      child: Text(
        '$count',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
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
  final VoidCallback onLongPress;

  const _CycleWorkoutCard({
    required this.index,
    required this.workoutName,
    this.workoutDescription,
    required this.isNext,
    this.onTap,
    required this.onStart,
    required this.onLongPress,
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
                width: 1.5,
              ),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AthlosRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AthlosComponentSizes.listItemMinHeight,
          ),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AthlosTruncatedText(
                        workoutName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: isNext ? FontWeight.w600 : null,
                        ),
                        maxLines: 1,
                        showOverflowTooltip: false,
                      ),
                      if (workoutDescription != null &&
                          workoutDescription!.isNotEmpty)
                        AthlosTruncatedText(
                          workoutDescription!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          showOverflowTooltip: false,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: isNext
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: l10n.startWorkout,
                  onPressed: onStart,
                ),
              ],
            ),
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
    final archivedPrograms =
        programsAsync.value?.where((p) => !p.isActive).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AthlosSpacing.md,
        AthlosSpacing.md,
        AthlosSpacing.md,
        AthlosSpacing.fabClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 56,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const Gap(AthlosSpacing.md),
                  Text(
                    l10n.noProgramActiveTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
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
                  _CycleAddWorkoutButton(
                    label: l10n.noProgramActiveCreateAction,
                    onPressed: () => context.push(RoutePaths.trainingProgramNew),
                  ),
                ],
              ),
            ),
          ),
          if (archivedPrograms.isNotEmpty) ...[
            const Gap(AthlosSpacing.md),
            TextButton.icon(
              onPressed: () => context.push(RoutePaths.trainingPrograms),
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(l10n.noProgramActiveViewArchived),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Cycle actions ─────────────────────────────────────────────────────

class _CycleAddWorkoutButton extends StatelessWidget {
  const _CycleAddWorkoutButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  static final _fullWidthStyle = FilledButton.styleFrom(
    minimumSize: const Size(double.infinity, AthlosButtonSizes.screenMinHeight),
  );

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return FilledButton.icon(
        style: _fullWidthStyle,
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, AthlosButtonSizes.screenMinHeight),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

