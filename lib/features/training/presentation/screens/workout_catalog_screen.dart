import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../chiron/presentation/widgets/chiron_bottom_sheet.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../providers/workout_notifier.dart';

final _placeholderWorkouts = List.generate(
  6,
  (i) => Workout(
    id: -(i + 1),
    name: BoneMock.name,
    createdAt: DateTime(2024),
  ),
);

/// Standalone workout catalog screen (all user workout templates).
///
/// Accessible from the Dashboard library section. Shows a flat list of
/// active workouts with archive/duplicate/delete actions, plus an
/// expandable FAB for creating new workouts (manual or via Chiron).
class WorkoutCatalogScreen extends ConsumerWidget {
  const WorkoutCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workoutsAsync = ref.watch(workoutListProvider);
    final workoutCount = workoutsAsync.value?.length ?? 0;

    return Scaffold(
      body: const _WorkoutCatalogBody(),
      floatingActionButton: _ExpandableWorkoutFab(
        chironLabel: workoutCount == 0
            ? l10n.chironCreateWorkoutShortcut
            : l10n.chironAnalyzeWorkoutsShortcut,
        createManualLabel: l10n.trainingWorkoutActionCreateManual,
        onChiron: () => showChironSheet(
          context,
          initialMessage: workoutCount == 0
              ? l10n.chironAskToCreateWorkout
              : l10n.chironAnalyzeWorkoutsMessage,
        ),
        onCreateManual: () => context.push(RoutePaths.trainingWorkoutNew),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────

class _WorkoutCatalogBody extends ConsumerWidget {
  const _WorkoutCatalogBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final workoutsAsync = ref.watch(workoutListProvider);
    final archivedAsync = ref.watch(archivedWorkoutListProvider);

    if (workoutsAsync.hasError) {
      return Center(child: Text(l10n.genericError));
    }

    final isLoading = workoutsAsync.isLoading;
    final workouts = workoutsAsync.value ?? [];
    if (!isLoading &&
        workouts.isEmpty &&
        (archivedAsync.value == null || archivedAsync.value!.isEmpty)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AthlosSpacing.md),
            Text(
              l10n.emptyWorkouts,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AthlosSpacing.sm),
            Text(
              l10n.emptyWorkoutsHint,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final displayWorkouts =
        isLoading && workouts.isEmpty ? _placeholderWorkouts : workouts;

    return Skeletonizer(
      enabled: isLoading,
      child: _WorkoutListView(
        workouts: displayWorkouts,
        archivedAsync: archivedAsync,
      ),
    );
  }
}

// ── Workout list view ─────────────────────────────────────────────────

class _WorkoutListView extends ConsumerStatefulWidget {
  final List<Workout> workouts;
  final AsyncValue<List<Workout>> archivedAsync;

  const _WorkoutListView({
    required this.workouts,
    required this.archivedAsync,
  });

  @override
  ConsumerState<_WorkoutListView> createState() => _WorkoutListViewState();
}

class _WorkoutListViewState extends ConsumerState<_WorkoutListView> {
  bool _isArchivedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverList.builder(
          itemCount: widget.workouts.length,
          itemBuilder: (context, index) {
            final workout = widget.workouts[index];
            return _WorkoutCard(
              key: ValueKey(workout.id),
              workout: workout,
              onTap: () => context.push(
                '${RoutePaths.trainingWorkouts}/${workout.id}',
              ),
              onStart: () => context.push(
                '${RoutePaths.trainingWorkouts}/${workout.id}/execute',
              ),
              onArchive: () => _archiveWorkout(context, workout.id),
              onDuplicate: () => _duplicateWorkout(context, workout.id),
              onDelete: () => _confirmDelete(context, workout),
            );
          },
        ),

        if (widget.archivedAsync.value != null &&
            widget.archivedAsync.value!.isNotEmpty)
          SliverToBoxAdapter(
            child: ExpansionTile(
              title: Text(
                l10n.archivedSection,
                style: textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              initiallyExpanded: _isArchivedExpanded,
              onExpansionChanged: (v) =>
                  setState(() => _isArchivedExpanded = v),
              children: widget.archivedAsync.value!
                  .map((w) => _ArchivedWorkoutTile(
                        workout: w,
                        onUnarchive: () => _unarchiveWorkout(context, w.id),
                        onDuplicate: () => _duplicateWorkout(context, w.id),
                        onTap: () => context.push(
                          '${RoutePaths.trainingWorkouts}/${w.id}',
                        ),
                      ))
                  .toList(),
            ),
          ),

        const SliverPadding(
            padding: EdgeInsets.only(bottom: AthlosSpacing.fabClearance)),
      ],
    );
  }

  void _archiveWorkout(BuildContext context, int id) async {
    try {
      await ref.read(workoutListProvider.notifier).archiveWorkout(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.workoutArchived),
          ),
        );
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

  void _unarchiveWorkout(BuildContext context, int id) async {
    try {
      await ref.read(workoutListProvider.notifier).unarchiveWorkout(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.workoutUnarchived),
          ),
        );
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

  void _duplicateWorkout(BuildContext context, int id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(workoutListProvider.notifier)
          .duplicateWorkout(id, nameSuffix: l10n.workoutCopySuffix);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.duplicatedWorkout),
          ),
        );
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

  void _confirmDelete(BuildContext context, Workout workout) {
    final l10n = AppLocalizations.of(context)!;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWorkoutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteWorkoutMessage),
          ],
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
                        .read(workoutListProvider.notifier)
                        .deleteWorkout(workout.id);
                  } on Exception catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.genericError),
                        ),
                      );
                    }
                  }
                },
                child: Text(l10n.delete),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Workout Card ──────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onArchive;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _WorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
    required this.onStart,
    required this.onArchive,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xs,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.md,
            vertical: AthlosSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AthlosTruncatedText(
                      workout.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                    ),
                    if (workout.description != null &&
                        workout.description!.isNotEmpty)
                      AthlosTruncatedText(
                        workout.description!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.play_circle_outline,
                    color: colorScheme.primary),
                tooltip: l10n.startWorkout,
                onPressed: onStart,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'archive':
                      onArchive();
                    case 'duplicate':
                      onDuplicate();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text(l10n.archiveWorkout),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(l10n.duplicateWorkout),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      title: Text(l10n.delete),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Archived Workout Tile ─────────────────────────────────────────────

class _ArchivedWorkoutTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onUnarchive;
  final VoidCallback onDuplicate;
  final VoidCallback onTap;

  const _ArchivedWorkoutTile({
    required this.workout,
    required this.onUnarchive,
    required this.onDuplicate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading:
          Icon(Icons.archive_outlined, color: colorScheme.onSurfaceVariant),
      title: Text(workout.name),
      subtitle: workout.description != null && workout.description!.isNotEmpty
          ? AthlosTruncatedText(
              workout.description!,
              maxLines: 1,
            )
          : null,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.unarchive_outlined),
            tooltip: l10n.unarchiveWorkout,
            onPressed: onUnarchive,
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: l10n.duplicateWorkout,
            onPressed: onDuplicate,
          ),
        ],
      ),
    );
  }
}

// ── Expandable FAB ────────────────────────────────────────────────────

class _ExpandableWorkoutFab extends StatefulWidget {
  final String chironLabel;
  final String createManualLabel;
  final VoidCallback onChiron;
  final VoidCallback onCreateManual;

  const _ExpandableWorkoutFab({
    required this.chironLabel,
    required this.createManualLabel,
    required this.onChiron,
    required this.onCreateManual,
  });

  @override
  State<_ExpandableWorkoutFab> createState() => _ExpandableWorkoutFabState();
}

class _ExpandableWorkoutFabState extends State<_ExpandableWorkoutFab> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _onAction(VoidCallback action) {
    action();
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ActionChip(
                        icon: Icons.auto_awesome,
                        label: widget.chironLabel,
                        onPressed: () => _onAction(widget.onChiron),
                      ),
                      const SizedBox(height: AthlosSpacing.sm),
                      _ActionChip(
                        icon: Icons.edit_note,
                        label: widget.createManualLabel,
                        onPressed: () => _onAction(widget.onCreateManual),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'catalog_fab',
          onPressed: _toggle,
          tooltip: _expanded ? '' : widget.createManualLabel,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: AthlosRadius.mdAll,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AthlosSpacing.sm,
                vertical: AthlosSpacing.xs,
              ),
              child: AthlosTruncatedText(
                label,
                style: textTheme.labelLarge,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: AthlosSpacing.sm),
          FloatingActionButton.small(
            heroTag: null,
            onPressed: onPressed,
            tooltip: label,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
