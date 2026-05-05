import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout.dart';
import '../../domain/entities/workout_exercise.dart';
import '../helpers/duration_format.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/workout_notifier.dart';
import '../widgets/workout_exercise_tile.dart' show supersetColorFor;

final _placeholderExercises = List.generate(
  3,
  (i) => WorkoutExercise(
    workoutId: 0,
    exerciseId: 0,
    order: i,
    sets: 3,
    minReps: 10,
    maxReps: 10,
    rest: 60,
  ),
);
final _placeholderWorkout = Workout(
  id: 0,
  name: '',
  description: null,
  sortOrder: null,
  isArchived: false,
  createdAt: DateTime(0),
);

/// Detail view of a single workout.
class WorkoutDetailScreen extends ConsumerWidget {
  final int workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final workoutAsync = ref.watch(workoutByIdProvider(workoutId));
    final exercisesAsync = ref.watch(workoutExercisesProvider(workoutId));
    final nextWorkout = ref.watch(nextWorkoutProvider);

    final workout = workoutAsync.value;

    if (workoutAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!workoutAsync.isLoading && workout == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.workoutNotFound)),
      );
    }

    final displayWorkout = workout ?? _placeholderWorkout;
    final isNext = nextWorkout?.id == displayWorkout.id;

    return Scaffold(
          appBar: AppBar(
            title: Text(displayWorkout.name),
            actions: [
              if (!displayWorkout.isArchived)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.edit,
                  onPressed: () => context.push(
                    '${RoutePaths.trainingWorkouts}/${displayWorkout.id}/edit',
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'archive':
                      try {
                        await ref
                            .read(workoutListProvider.notifier)
                            .archiveWorkout(displayWorkout.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.workoutArchived)),
                          );
                          context.pop();
                        }
                      } on Exception catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.genericError)),
                          );
                        }
                      }
                    case 'unarchive':
                      try {
                        await ref
                            .read(workoutListProvider.notifier)
                            .unarchiveWorkout(displayWorkout.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.workoutUnarchived)),
                          );
                          context.pop();
                        }
                      } on Exception catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.genericError)),
                          );
                        }
                      }
                    case 'duplicate':
                      try {
                        await ref
                            .read(workoutListProvider.notifier)
                            .duplicateWorkout(displayWorkout.id,
                                nameSuffix: l10n.workoutCopySuffix);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.duplicatedWorkout)),
                          );
                        }
                      } on Exception catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.genericError)),
                          );
                        }
                      }
                    case 'delete':
                      _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  if (!displayWorkout.isArchived)
                    PopupMenuItem(
                      value: 'archive',
                      child: ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(l10n.archiveWorkout),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  else
                    PopupMenuItem(
                      value: 'unarchive',
                      child: ListTile(
                        leading: const Icon(Icons.unarchive_outlined),
                        title: Text(l10n.unarchiveWorkout),
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
          body: Skeletonizer(
            enabled: workoutAsync.isLoading,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNext)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                    vertical: AthlosSpacing.sm,
                  ),
                  color: colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_outline,
                          color: colorScheme.onPrimaryContainer, size: 20),
                      const SizedBox(width: AthlosSpacing.sm),
                      Text(
                        l10n.nextWorkoutBadge,
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              if (displayWorkout.description != null &&
                  displayWorkout.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AthlosSpacing.md,
                    AthlosSpacing.sm,
                    AthlosSpacing.md,
                    AthlosSpacing.md,
                  ),
                  child: Text(
                    displayWorkout.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              _WorkoutLastVsPreviousSection(workoutId: workoutId),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.md,
                ),
                child: Text(
                  l10n.exercisesInWorkout,
                  style: textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: AthlosSpacing.sm),
              Expanded(
                child: () {
                  if (exercisesAsync.hasError) {
                    return Center(
                        child: Text('${exercisesAsync.error}'));
                  }
                  final exercises = exercisesAsync.value ??
                      _placeholderExercises;
                  return Skeletonizer(
                    enabled: exercisesAsync.isLoading,
                    child: exercises.isEmpty
                        ? Center(
                            child: Text(
                              l10n.emptyWorkoutExercises,
                              style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final groupColorMap = <int, int>{};
                              var nextColorIdx = 0;
                              for (final ex in exercises) {
                                if (ex.groupId != null &&
                                    !groupColorMap.containsKey(ex.groupId)) {
                                  groupColorMap[ex.groupId!] = nextColorIdx++;
                                }
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AthlosSpacing.sm,
                                ),
                                itemCount: exercises.length,
                                itemBuilder: (context, index) {
                                  final ex = exercises[index];
                                  final gid = ex.groupId;
                                  final isGroupedWithPrev = index > 0 &&
                                      gid != null &&
                                      exercises[index - 1].groupId == gid;
                                  final isGroupedWithNext =
                                      index < exercises.length - 1 &&
                                          gid != null &&
                                          exercises[index + 1].groupId == gid;
                                  final groupColorIndex =
                                      gid != null ? groupColorMap[gid] : null;

                                  return _ExerciseDetailTile(
                                    exercise: ex,
                                    index: index + 1,
                                    isGroupedWithPrev: isGroupedWithPrev,
                                    isGroupedWithNext: isGroupedWithNext,
                                    groupColorIndex: groupColorIndex,
                                  );
                                },
                              );
                            },
                          ),
                  );
                }(),
              ),
            ],
          ),
        ),
        bottomNavigationBar: displayWorkout.isArchived
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AthlosSpacing.md),
                    child: FilledButton.icon(
                      onPressed: () => _startWorkout(context, ref),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.startWorkout),
                    ),
                  ),
                ),
    );
  }

  void _startWorkout(BuildContext context, WidgetRef ref) {
    context.push('${RoutePaths.trainingWorkouts}/$workoutId/execute');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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
                        .deleteWorkout(workoutId);
                    if (context.mounted) context.pop();
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
}

class _ExerciseDetailTile extends ConsumerWidget {
  final WorkoutExercise exercise;
  final int index;
  final bool isGroupedWithPrev;
  final bool isGroupedWithNext;
  final int? groupColorIndex;

  const _ExerciseDetailTile({
    required this.exercise,
    required this.index,
    this.isGroupedWithPrev = false,
    this.isGroupedWithNext = false,
    this.groupColorIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercisesAsync = ref.watch(exerciseListProvider);

    final exerciseEntity = exercisesAsync.value?.cast<dynamic>().firstWhere(
          (e) => e.id == exercise.exerciseId,
          orElse: () => null,
        );

    final displayName = exerciseEntity != null
        ? localizedExerciseName(
            exerciseEntity.name,
            isVerified: exerciseEntity.isVerified,
            l10n: l10n,
          )
        : l10n.unknownExerciseId(exercise.exerciseId);

    final groupName = exerciseEntity != null
        ? localizedMuscleGroupName(exerciseEntity.muscleGroup, l10n)
        : '';

    final isInGroup = isGroupedWithPrev || isGroupedWithNext;
    final groupColor = isInGroup && groupColorIndex != null
        ? supersetColorFor(groupColorIndex!, colorScheme)
        : null;

    final card = Card(
      margin: EdgeInsets.only(
        left: AthlosSpacing.sm,
        right: AthlosSpacing.sm,
        top: isGroupedWithPrev ? AthlosSpacing.xxs : AthlosSpacing.xs,
        bottom: isGroupedWithNext ? AthlosSpacing.xxs : AthlosSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AthlosRadius.mdAll,
        side: groupColor != null
            ? BorderSide(color: groupColor.withValues(alpha: 0.4))
            : BorderSide.none,
      ),
      child: Container(
        decoration: groupColor != null
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: groupColor, width: 3),
                ),
              )
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: groupColor?.withValues(alpha: 0.15) ??
                colorScheme.primaryContainer,
            child: Text(
              '$index',
              style: textTheme.titleSmall?.copyWith(
                color: groupColor ?? colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(child: AthlosTruncatedText(displayName)),
              if (exercise.isUnilateral)
                Padding(
                  padding: const EdgeInsets.only(left: AthlosSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.sm,
                      vertical: AthlosSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: AthlosRadius.fullAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz,
                            size: 10,
                            color: colorScheme.onSecondaryContainer),
                        const SizedBox(width: 2),
                        Text(
                          l10n.unilateralLabel,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isInGroup && !isGroupedWithPrev)
                Padding(
                  padding: const EdgeInsets.only(left: AthlosSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.sm,
                      vertical: AthlosSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: groupColor?.withValues(alpha: 0.12),
                      borderRadius: AthlosRadius.smAll,
                    ),
                    child: Text(
                      l10n.supersetLabel,
                      style: textTheme.labelSmall?.copyWith(
                        color: groupColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_exerciseSubtitle(exercise, groupName)),
              if (exercise.notes != null && exercise.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AthlosSpacing.xxs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AthlosSpacing.xs),
                      Flexible(
                        child: Text(
                          exercise.notes!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  String _exerciseSubtitle(WorkoutExercise ex, String groupName) {
    final config = ex.duration != null
        ? '${ex.sets}×${formatDuration(ex.duration!)}  •  ${ex.rest}s'
        : '${ex.sets}×${ex.repsDisplay}  •  ${ex.rest}s';
    return groupName.isNotEmpty ? '$groupName  •  $config' : config;
  }
}

class _WorkoutLastVsPreviousSection extends ConsumerWidget {
  const _WorkoutLastVsPreviousSection({required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync =
        ref.watch(lastVsPreviousComparisonProvider(workoutId));
    return comparisonAsync.when(
      data: (c) {
        if (c == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        final textTheme = Theme.of(context).textTheme;
        final colorScheme = Theme.of(context).colorScheme;
        final locale = Localizations.localeOf(context);
        final lastDate = intl.DateFormat.MMMd(locale.toString())
            .format(c.last.startedAt.toLocal());
        final prevDate = intl.DateFormat.MMMd(locale.toString())
            .format(c.previous.startedAt.toLocal());
        final lastDur = formatDuration(c.last.duration?.inSeconds ?? 0);
        final prevDur = formatDuration(c.previous.duration?.inSeconds ?? 0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            0,
            AthlosSpacing.md,
            AthlosSpacing.sm,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trainingLastVsPrevious,
                    style: textTheme.titleSmall,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    '${l10n.trainingLastSession}: $lastDate · $lastDur · ${c.volumeLast.toStringAsFixed(0)} kg',
                    style: textTheme.bodySmall,
                  ),
                  Text(
                    '${l10n.trainingPreviousSession}: $prevDate · $prevDur · ${c.volumePrevious.toStringAsFixed(0)} kg',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (c.volumeDelta != 0) ...[
                    const Gap(AthlosSpacing.xs),
                    Text(
                      l10n.trainingVolumeDelta(c.volumeDelta.toStringAsFixed(1)),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stackTrace) => const SizedBox.shrink(),
    );
  }
}
