import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_execution.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';

/// Training module — History tab.
///
/// Shows finished workout executions sorted by date (most recent first),
/// with workout name and duration. Supports deleting entries.
class TrainingHistoryScreen extends ConsumerWidget {
  const TrainingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final archivedAsync = ref.watch(archivedWorkoutListProvider);

    final allWorkouts = [
      ...?workoutsAsync.value,
      ...?archivedAsync.value,
    ];
    final workoutById = {for (final w in allWorkouts) w.id: w};

    return executionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (executions) {
        if (executions.isEmpty) {
          return Center(
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
                  l10n.emptyHistory,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AthlosSpacing.sm),
                Text(
                  l10n.emptyHistoryHint,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.sm,
            vertical: AthlosSpacing.sm,
          ),
          itemCount: executions.length,
          itemBuilder: (context, index) => _ExecutionCard(
            key: ValueKey(executions[index].id),
            execution: executions[index],
            workout: workoutById[executions[index].workoutId],
          ),
        );
      },
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
        onTap: () => context.push(
            '${RoutePaths.trainingHistory}/${execution.id}'),
        borderRadius: AthlosRadius.mdAll,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workoutName,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
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
                    leading:
                        Icon(Icons.delete_outline, color: colorScheme.error),
                    title: Text(
                      l10n.delete,
                      style: TextStyle(color: colorScheme.error),
                    ),
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteExecutionTitle),
        content: Text(l10n.deleteExecutionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
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
