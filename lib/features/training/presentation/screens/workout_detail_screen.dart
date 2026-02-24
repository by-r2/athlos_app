import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/workout_exercise.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_notifier.dart';

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

    return workoutAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (workout) {
        if (workout == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.workoutNotFound)),
          );
        }

        final isNext = nextWorkout?.id == workout.id;

        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [
              if (!workout.isArchived)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.edit,
                  onPressed: () => context.push(
                    '${RoutePaths.trainingWorkouts}/${workout.id}/edit',
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'archive':
                      try {
                        await ref
                            .read(workoutListProvider.notifier)
                            .archiveWorkout(workout.id);
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
                            .unarchiveWorkout(workout.id);
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
                            .duplicateWorkout(workout.id,
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
                  if (!workout.isArchived)
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
                      leading:
                          Icon(Icons.delete_outline, color: colorScheme.error),
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
          body: Column(
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
              if (workout.description != null &&
                  workout.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AthlosSpacing.md,
                    AthlosSpacing.sm,
                    AthlosSpacing.md,
                    AthlosSpacing.md,
                  ),
                  child: Text(
                    workout.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
                child: exercisesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (exercises) {
                    if (exercises.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.emptyWorkoutExercises,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.sm,
                      ),
                      itemCount: exercises.length,
                      itemBuilder: (context, index) =>
                          _ExerciseDetailTile(
                        exercise: exercises[index],
                        index: index + 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: workout.isArchived
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
      },
    );
  }

  void _startWorkout(BuildContext context, WidgetRef ref) {
    context.push('${RoutePaths.trainingWorkouts}/$workoutId/execute');
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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
        ],
      ),
    );
  }
}

class _ExerciseDetailTile extends ConsumerWidget {
  final WorkoutExercise exercise;
  final int index;

  const _ExerciseDetailTile({required this.exercise, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercisesAsync = ref.watch(exerciseListProvider);

    final exerciseEntity = exercisesAsync.value?.firstWhere(
      (e) => e.id == exercise.exerciseId,
      orElse: () => throw StateError('Exercise not found'),
    );

    final displayName = exerciseEntity != null
        ? localizedExerciseName(
            exerciseEntity.name,
            isVerified: exerciseEntity.isVerified,
            l10n: l10n,
          )
        : '#${exercise.exerciseId}';

    final groupName = exerciseEntity != null
        ? localizedMuscleGroupName(exerciseEntity.muscleGroup, l10n)
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xs,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            '$index',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(displayName),
        subtitle: Text(
          groupName.isNotEmpty
              ? '$groupName  •  ${exercise.sets}×${exercise.reps}  •  ${exercise.restSeconds}s'
              : '${exercise.sets}×${exercise.reps}  •  ${exercise.restSeconds}s',
        ),
      ),
    );
  }
}
