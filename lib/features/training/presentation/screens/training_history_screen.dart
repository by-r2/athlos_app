import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_execution.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';

final _placeholderExecutions = List.generate(
  6,
  (i) => WorkoutExecution(
    id: i,
    workoutId: 0,
    programId: 0,
    startedAt: DateTime(2024),
    finishedAt: DateTime(2024).add(const Duration(minutes: 45)),
  ),
);

/// Training module — History tab.
///
/// Shows finished workout executions sorted by date (most recent first),
/// with workout name and duration. Supports deleting entries.
class TrainingHistoryScreen extends ConsumerStatefulWidget {
  const TrainingHistoryScreen({super.key});

  @override
  ConsumerState<TrainingHistoryScreen> createState() =>
      _TrainingHistoryScreenState();
}

class _TrainingHistoryScreenState extends ConsumerState<TrainingHistoryScreen> {
  int? _selectedWorkoutId;
  String? _lastWorkoutIdParam;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workoutIdParam =
        GoRouterState.of(context).uri.queryParameters['workoutId'];
    if (workoutIdParam == _lastWorkoutIdParam) return;

    _lastWorkoutIdParam = workoutIdParam;
    _selectedWorkoutId = int.tryParse(workoutIdParam ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final archivedAsync = ref.watch(archivedWorkoutListProvider);

    final allWorkouts = [
      ...?workoutsAsync.value,
      ...?archivedAsync.value,
    ];
    final workoutById = {for (final w in allWorkouts) w.id: w};

    if (executionsAsync.hasError) {
      return Center(child: Text(l10n.genericError));
    }

    final isLoading = executionsAsync.isLoading;
    final executions = executionsAsync.value;
    final filteredExecutions = switch (executions) {
      null => null,
      _ when _selectedWorkoutId == null => executions,
      _ => executions
          .where((execution) => execution.workoutId == _selectedWorkoutId)
          .toList(),
    };

    final hasNoItems = !isLoading && (filteredExecutions?.isEmpty ?? true);
    final resolvedExecutions = filteredExecutions ?? _placeholderExecutions;

    return Skeletonizer(
      enabled: isLoading,
      child: Column(
        children: [
          if (allWorkouts.isNotEmpty)
            _HistoryWorkoutFilterBar(
              selectedWorkoutId: _selectedWorkoutId,
              workouts: allWorkouts,
              onSelectedWorkout: (workoutId) {
                setState(() => _selectedWorkoutId = workoutId);
              },
              allLabel: l10n.filterAll,
            ),
          Expanded(
            child: hasNoItems
                ? _HistoryEmptyState(
                    title: l10n.emptyHistory,
                    hint: l10n.emptyHistoryHint,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.sm,
                      vertical: AthlosSpacing.sm,
                    ),
                    itemCount: resolvedExecutions.length,
                    itemBuilder: (context, index) => _ExecutionCard(
                      key: ValueKey(resolvedExecutions[index].id),
                      execution: resolvedExecutions[index],
                      workout: workoutById[resolvedExecutions[index].workoutId],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final String title;
  final String hint;

  const _HistoryEmptyState({
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AthlosSpacing.md),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AthlosSpacing.sm),
            Text(
              hint,
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

class _HistoryWorkoutFilterBar extends StatelessWidget {
  final int? selectedWorkoutId;
  final List<Workout> workouts;
  final ValueChanged<int?> onSelectedWorkout;
  final String allLabel;

  const _HistoryWorkoutFilterBar({
    required this.selectedWorkoutId,
    required this.workouts,
    required this.onSelectedWorkout,
    required this.allLabel,
  });

  @override
  Widget build(BuildContext context) {
    final sortedWorkouts = workouts.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.md,
          vertical: AthlosSpacing.xs,
        ),
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(allLabel),
            selected: selectedWorkoutId == null,
            onSelected: (_) => onSelectedWorkout(null),
          ),
          const SizedBox(width: AthlosSpacing.xs),
          ...sortedWorkouts.map(
            (workout) => Padding(
              padding: const EdgeInsets.only(right: AthlosSpacing.xs),
              child: FilterChip(
                key: ValueKey(workout.id),
                label: Text(workout.name),
                selected: selectedWorkoutId == workout.id,
                onSelected: (_) => onSelectedWorkout(workout.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionCard extends ConsumerWidget {
  final WorkoutExecution execution;
  final Workout? workout;

  const _ExecutionCard({
    super.key,
    required this.execution,
    required this.workout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final workoutName = workout?.name ?? l10n.unknownWorkout;
    final dateStr = _formatDate(execution.startedAt, context);
    final durationStr = _formatDuration(execution.duration, l10n);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xs,
      ),
      child: InkWell(
        onTap: () => context.push('${RoutePaths.trainingHistory}/${execution.id}'),
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
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  workoutName.isNotEmpty ? workoutName[0].toUpperCase() : '?',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AthlosSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AthlosTruncatedText(
                      workoutName,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                    ),
                    const SizedBox(height: AthlosSpacing.xs),
                    Text(
                      durationStr != null ? '$dateStr  •  $durationStr' : dateStr,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (context) => [
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
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteExecutionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteExecutionMessage),
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
                        .read(workoutExecutionListProvider.notifier)
                        .deleteExecution(execution.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.executionDeleted)),
                      );
                    }
                  } on Exception catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.genericError)),
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

  String _formatDate(DateTime date, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final timeStr = DateFormat.Hm(locale).format(date);

    if (dateDay == today) return l10n.dateToday(timeStr);
    if (dateDay == today.subtract(const Duration(days: 1))) {
      return l10n.dateYesterday(timeStr);
    }

    final dateStr = DateFormat.MMMd(locale).format(date);
    if (date.year != now.year) {
      return '${DateFormat.yMMMd(locale).format(date)}, $timeStr';
    }
    return '$dateStr, $timeStr';
  }

  String? _formatDuration(Duration? duration, AppLocalizations l10n) {
    if (duration == null) return null;
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 1) return null;

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return l10n.durationFormat(hours, minutes);
    }
    return l10n.durationMinutes(minutes);
  }
}
