import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/workout_notifier.dart';

final _placeholderWorkouts = List.generate(
  6,
  (i) => Workout(id: 'placeholder-$i', name: BoneMock.name, createdAt: DateTime(2024)),
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
    return const _WorkoutCatalogBody();
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

    final displayWorkouts = isLoading && workouts.isEmpty
        ? _placeholderWorkouts
        : workouts;

    return Skeletonizer(
      enabled: isLoading,
      child: _WorkoutListView(
        workouts: displayWorkouts,
        archivedAsync: archivedAsync,
        enableGestures: !isLoading,
      ),
    );
  }
}

// ── Workout list view ─────────────────────────────────────────────────

class _WorkoutListView extends ConsumerStatefulWidget {
  final List<Workout> workouts;
  final AsyncValue<List<Workout>> archivedAsync;
  final bool enableGestures;

  const _WorkoutListView({
    required this.workouts,
    required this.archivedAsync,
    this.enableGestures = true,
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
            final card = _WorkoutCard(
              workout: workout,
              onTap: () =>
                  context.push('${RoutePaths.trainingWorkouts}/${workout.id}'),
              onStart: () => launchWorkoutExecution(
                context,
                ref,
                workoutId: workout.id,
              ),
              onLongPress: widget.enableGestures
                  ? () => _showWorkoutOptionsSheet(context, workout)
                  : null,
            );

            if (!widget.enableGestures) {
              return KeyedSubtree(
                key: ValueKey(workout.id),
                child: card,
              );
            }

            return Dismissible(
              key: ValueKey(workout.id),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) =>
                  _confirmWorkoutDismiss(context, workout, direction),
              onDismissed: (_) async {
                try {
                  await ref
                      .read(workoutListProvider.notifier)
                      .deleteWorkout(workout.id);
                } on Exception catch (_) {
                  if (context.mounted) {
                    context.showAthlosErrorSnack(l10n.genericError);
                  }
                }
              },
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: AthlosSpacing.lg),
                margin: const EdgeInsets.symmetric(
                  vertical: AthlosSpacing.xs,
                  horizontal: AthlosSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AthlosRadius.mdAll,
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AthlosSpacing.lg),
                margin: const EdgeInsets.symmetric(
                  vertical: AthlosSpacing.xs,
                  horizontal: AthlosSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: AthlosRadius.mdAll,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              child: card,
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
                  .map(
                    (w) => _ArchivedWorkoutTile(
                      workout: w,
                      onUnarchive: () => _unarchiveWorkout(context, w.id),
                      onDuplicate: () => _duplicateWorkout(context, w.id),
                      onTap: () => context.push(
                        '${RoutePaths.trainingWorkouts}/${w.id}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

        const SliverPadding(
          padding: EdgeInsets.only(bottom: AthlosSpacing.fabClearance),
        ),
      ],
    );
  }

  void _archiveWorkout(BuildContext context, String id) async {
    try {
      await ref.read(workoutListProvider.notifier).archiveWorkout(id);
      if (context.mounted) {
        context.showAthlosSuccessSnack(
          AppLocalizations.of(context)!.workoutArchived,
        );
      }
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  void _unarchiveWorkout(BuildContext context, String id) async {
    try {
      await ref.read(workoutListProvider.notifier).unarchiveWorkout(id);
      if (context.mounted) {
        context.showAthlosSuccessSnack(
          AppLocalizations.of(context)!.workoutUnarchived,
        );
      }
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  void _duplicateWorkout(BuildContext context, String id) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(workoutListProvider.notifier)
          .duplicateWorkout(id, nameSuffix: l10n.workoutCopySuffix);
      if (context.mounted) {
        context.showAthlosSuccessSnack(
          AppLocalizations.of(context)!.duplicatedWorkout,
        );
      }
    } on Exception catch (_) {
      if (context.mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    }
  }

  Future<bool> _confirmDeleteWorkout(BuildContext context, Workout workout) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showAthlosDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWorkoutTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.deleteWorkoutMessage)],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<bool> _confirmWorkoutDismiss(
    BuildContext context,
    Workout workout,
    DismissDirection direction,
  ) async {
    if (direction == DismissDirection.startToEnd) {
      context.push('${RoutePaths.trainingWorkouts}/${workout.id}/edit');
      return false;
    }
    return _confirmDeleteWorkout(context, workout);
  }

  void _showWorkoutOptionsSheet(BuildContext context, Workout workout) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                Text(workout.name, style: textTheme.titleMedium),
                if (workout.description != null &&
                    workout.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AthlosSpacing.xs),
                  AthlosTruncatedText(
                    workout.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: AthlosSpacing.md),
                ListTile(
                  leading: Icon(Icons.play_circle_outline, color: colorScheme.primary),
                  title: Text(l10n.startWorkout),
                  onTap: () {
                    Navigator.pop(ctx);
                    launchWorkoutExecution(context, ref, workoutId: workout.id);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
                  title: Text(l10n.editWorkout),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${RoutePaths.trainingWorkouts}/${workout.id}/edit',
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.archive_outlined, color: colorScheme.primary),
                  title: Text(l10n.archiveWorkout),
                  onTap: () {
                    Navigator.pop(ctx);
                    _archiveWorkout(context, workout.id);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.copy_outlined, color: colorScheme.primary),
                  title: Text(l10n.duplicateWorkout),
                  onTap: () {
                    Navigator.pop(ctx);
                    _duplicateWorkout(context, workout.id);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    l10n.delete,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirmed = await _confirmDeleteWorkout(context, workout);
                    if (!confirmed || !context.mounted) return;
                    try {
                      await ref
                          .read(workoutListProvider.notifier)
                          .deleteWorkout(workout.id);
                    } on Exception catch (_) {
                      if (context.mounted) {
                        context.showAthlosErrorSnack(l10n.genericError);
                      }
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
}

// ── Workout Card ──────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback? onLongPress;

  const _WorkoutCard({
    required this.workout,
    required this.onTap,
    required this.onStart,
    this.onLongPress,
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
        onLongPress: onLongPress,
        borderRadius: AthlosRadius.mdAll,
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
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                  icon: Icon(
                    Icons.play_circle_outline,
                    color: colorScheme.primary,
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
      minTileHeight: AthlosComponentSizes.listItemMinHeight,
      leading: Icon(
        Icons.archive_outlined,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Text(workout.name),
      subtitle: workout.description != null && workout.description!.isNotEmpty
          ? AthlosTruncatedText(workout.description!, maxLines: 1)
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
