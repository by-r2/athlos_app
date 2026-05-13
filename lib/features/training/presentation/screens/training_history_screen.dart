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
import '../helpers/duration_format.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';
import '../widgets/training_history_filters.dart';

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

  int get _historyActiveFilterCount => _selectedWorkoutId != null ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workoutIdParam = GoRouterState.of(
      context,
    ).uri.queryParameters['workoutId'];
    if (workoutIdParam == _lastWorkoutIdParam) return;

    _lastWorkoutIdParam = workoutIdParam;
    _selectedWorkoutId = int.tryParse(workoutIdParam ?? '');
  }

  void _syncHistoryRouteWorkoutQuery(int? workoutId) {
    final router = GoRouter.of(context);
    if (workoutId == null) {
      router.go(RoutePaths.trainingHistory);
    } else {
      router.go('${RoutePaths.trainingHistory}?workoutId=$workoutId');
    }
  }

  Future<void> _openHistoryFilters(
    AppLocalizations l10n,
    List<Workout> allWorkouts,
  ) {
    return showTrainingHistoryWorkoutFilterSheet(
      context: context,
      l10n: l10n,
      workouts: allWorkouts,
      initialWorkoutId: _selectedWorkoutId,
      onApply: (workoutId) {
        setState(() => _selectedWorkoutId = workoutId);
        _syncHistoryRouteWorkoutQuery(workoutId);
      },
    );
  }

  List<WorkoutExecution>? _filterExecutions(
    List<WorkoutExecution>? executions,
  ) {
    if (executions == null) return null;
    if (_selectedWorkoutId == null) return executions;
    return executions.where((e) => e.workoutId == _selectedWorkoutId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final workoutsAsync = ref.watch(workoutListProvider);
    final archivedAsync = ref.watch(archivedWorkoutListProvider);

    final allWorkouts = [...?workoutsAsync.value, ...?archivedAsync.value];
    final workoutById = {for (final w in allWorkouts) w.id: w};

    if (executionsAsync.hasError) {
      return Center(child: Text(l10n.genericError));
    }

    final isLoading = executionsAsync.isLoading;
    final executions = executionsAsync.value;
    final filteredExecutions = _filterExecutions(executions);

    final reallyNoExecutions =
        !isLoading && executions != null && executions.isEmpty;
    final hasNoMatches =
        !isLoading &&
        executions != null &&
        executions.isNotEmpty &&
        (filteredExecutions?.isEmpty ?? true);

    final resolvedExecutions = filteredExecutions ?? _placeholderExecutions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.sm,
            AthlosSpacing.sm,
            AthlosSpacing.sm,
            AthlosSpacing.xs,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: _historyActiveFilterCount > 0
                  ? '${l10n.exerciseCatalogFiltersButton} ($_historyActiveFilterCount)'
                  : l10n.exerciseCatalogFiltersButton,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AthlosRadius.mdAll,
                  ),
                ),
                onPressed: () => _openHistoryFilters(l10n, allWorkouts),
                icon: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    if (_historyActiveFilterCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: const SizedBox.square(dimension: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: reallyNoExecutions
              ? _HistoryEmptyState(
                  title: l10n.emptyHistory,
                  hint: l10n.emptyHistoryHint,
                )
              : hasNoMatches
              ? _HistoryNoMatchesState(
                  title: l10n.trainingHistoryNoMatches,
                  hint: l10n.trainingHistoryNoMatchesHint,
                )
              : Skeletonizer(
                  enabled: isLoading,
                  child: ListView.builder(
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
        ),
      ],
    );
  }
}

class _HistoryNoMatchesState extends StatelessWidget {
  final String title;
  final String hint;

  const _HistoryNoMatchesState({required this.title, required this.hint});

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
              Icons.filter_alt_off_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
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

class _HistoryEmptyState extends StatelessWidget {
  final String title;
  final String hint;

  const _HistoryEmptyState({required this.title, required this.hint});

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
    final durationStr = formatWorkoutTotalDuration(execution.duration, l10n);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xs,
      ),
      child: InkWell(
        onTap: () =>
            context.push('${RoutePaths.trainingHistory}/${execution.id}'),
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
                        durationStr != null
                            ? '$dateStr  •  $durationStr'
                            : dateStr,
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
          children: [Text(l10n.deleteExecutionMessage)],
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
}
