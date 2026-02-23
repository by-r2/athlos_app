import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../providers/workout_notifier.dart';

/// Training module — Workouts tab.
///
/// Shows active workouts in a reorderable list with a FAB to start the next
/// workout in the cycle and a collapsible archived section.
class TrainingWorkoutsScreen extends ConsumerWidget {
  const TrainingWorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final workoutsAsync = ref.watch(workoutListProvider);
    final nextAsync = ref.watch(nextWorkoutProvider);
    final archivedAsync = ref.watch(archivedWorkoutListProvider);

    return Scaffold(
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (workouts) {
          if (workouts.isEmpty &&
              (archivedAsync.value == null ||
                  archivedAsync.value!.isEmpty)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 64,
                    color:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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

          final nextWorkout = nextAsync.value;

          return _WorkoutListBody(
            workouts: workouts,
            nextWorkoutId: nextWorkout?.id,
            archivedAsync: archivedAsync,
          );
        },
      ),
      floatingActionButton: _buildFab(context, ref, nextAsync, l10n),
    );
  }

  Widget? _buildFab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Workout?> nextAsync,
    AppLocalizations l10n,
  ) {
    final next = nextAsync.value;

    if (next != null) {
      return FloatingActionButton.extended(
        heroTag: 'start_next',
        onPressed: () => _startWorkout(context, ref, next.id),
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.startNextWorkout(next.name)),
      );
    }

    return FloatingActionButton(
      onPressed: () => context.push(RoutePaths.trainingWorkoutNew),
      tooltip: l10n.createWorkout,
      child: const Icon(Icons.add),
    );
  }

  void _startWorkout(BuildContext context, WidgetRef ref, int workoutId) async {
    await ref.read(markWorkoutDoneProvider(workoutId).future);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.workoutMarkedAsDone),
        ),
      );
    }
  }
}

class _WorkoutListBody extends ConsumerStatefulWidget {
  final List<Workout> workouts;
  final int? nextWorkoutId;
  final AsyncValue<List<Workout>> archivedAsync;

  const _WorkoutListBody({
    required this.workouts,
    required this.nextWorkoutId,
    required this.archivedAsync,
  });

  @override
  ConsumerState<_WorkoutListBody> createState() => _WorkoutListBodyState();
}

class _WorkoutListBodyState extends ConsumerState<_WorkoutListBody> {
  late List<Workout> _orderedWorkouts;
  bool _archivedExpanded = false;

  @override
  void initState() {
    super.initState();
    _orderedWorkouts = List.of(widget.workouts);
  }

  @override
  void didUpdateWidget(covariant _WorkoutListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workouts != oldWidget.workouts) {
      _orderedWorkouts = List.of(widget.workouts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // New workout button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.xs,
            ),
            child: OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.trainingWorkoutNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.createWorkout),
            ),
          ),
        ),

        // Active workouts — reorderable
        SliverReorderableList(
          itemCount: _orderedWorkouts.length,
          onReorder: _onReorder,
          itemBuilder: (context, index) {
            final workout = _orderedWorkouts[index];
            final isNext = workout.id == widget.nextWorkoutId;

            return ReorderableDragStartListener(
              key: ValueKey(workout.id),
              index: index,
              child: _WorkoutCard(
                workout: workout,
                isNext: isNext,
                onTap: () => context.push(
                  '${RoutePaths.trainingWorkouts}/${workout.id}',
                ),
                onStart: () => _startWorkout(context, workout.id),
                onArchive: () => _archiveWorkout(context, workout.id),
                onDuplicate: () => _duplicateWorkout(context, workout.id),
                onDelete: () => _confirmDelete(context, workout),
              ),
            );
          },
        ),

        // Archived section
        if (widget.archivedAsync.value != null &&
            widget.archivedAsync.value!.isNotEmpty)
          SliverToBoxAdapter(
            child: ExpansionTile(
              title: Text(
                l10n.archivedSection,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              initiallyExpanded: _archivedExpanded,
              onExpansionChanged: (v) => setState(() => _archivedExpanded = v),
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

        // Bottom padding for FAB
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _orderedWorkouts.removeAt(oldIndex);
      _orderedWorkouts.insert(newIndex, item);
    });
    final orderedIds = _orderedWorkouts.map((w) => w.id).toList();
    ref.read(workoutListProvider.notifier).reorderWorkouts(orderedIds);
  }

  void _startWorkout(BuildContext context, int workoutId) async {
    await ref.read(markWorkoutDoneProvider(workoutId).future);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.workoutMarkedAsDone),
        ),
      );
    }
  }

  void _archiveWorkout(BuildContext context, int id) async {
    await ref.read(workoutListProvider.notifier).archiveWorkout(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.workoutArchived),
        ),
      );
    }
  }

  void _unarchiveWorkout(BuildContext context, int id) async {
    await ref.read(workoutListProvider.notifier).unarchiveWorkout(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.workoutUnarchived),
        ),
      );
    }
  }

  void _duplicateWorkout(BuildContext context, int id) async {
    await ref.read(workoutListProvider.notifier).duplicateWorkout(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.duplicatedWorkout),
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, Workout workout) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWorkoutTitle),
        content: Text(l10n.deleteWorkoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(workoutListProvider.notifier)
                  .deleteWorkout(workout.id);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final bool isNext;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onArchive;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.isNext,
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
      shape: isNext
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.md,
            vertical: AthlosSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AthlosSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workout.name,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNext)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AthlosSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              l10n.nextWorkoutBadge,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (workout.description != null &&
                        workout.description!.isNotEmpty)
                      Text(
                        workout.description!,
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
                      leading: Icon(Icons.delete_outline,
                          color: colorScheme.error),
                      title: Text(l10n.delete,
                          style: TextStyle(color: colorScheme.error)),
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
      leading: Icon(Icons.archive_outlined, color: colorScheme.onSurfaceVariant),
      title: Text(workout.name),
      subtitle: workout.description != null && workout.description!.isNotEmpty
          ? Text(
              workout.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
