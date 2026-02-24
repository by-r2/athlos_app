import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/execution_set.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';

class ExecutionDetailScreen extends ConsumerWidget {
  final int executionId;

  const ExecutionDetailScreen({super.key, required this.executionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final executionsAsync = ref.watch(workoutExecutionListProvider);
    final setsAsync = ref.watch(executionSetsWithSegmentsProvider(executionId));
    final exercisesAsync = ref.watch(exerciseListProvider);

    final execution = executionsAsync.value?.where((e) => e.id == executionId).firstOrNull;

    if (execution == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final workoutAsync = ref.watch(workoutByIdProvider(execution.workoutId));
    final workoutName = workoutAsync.value?.name ?? l10n.unknownWorkout;

    return Scaffold(
      appBar: AppBar(
        title: Text(workoutName),
      ),
      body: setsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (sets) {
          final allExercises = exercisesAsync.value ?? [];
          final exerciseMap = {for (final e in allExercises) e.id: e};

          final exerciseIds = sets.map((s) => s.exerciseId).toSet().toList();

          double totalVolume = 0;
          int totalCompletedSets = 0;
          int totalPlannedSets = sets.length;

          for (final s in sets) {
            if (s.isCompleted) {
              totalCompletedSets++;
              if (s.segments.isNotEmpty) {
                for (final seg in s.segments) {
                  totalVolume += seg.reps * (seg.weight ?? 0);
                }
              } else {
                totalVolume += s.reps * (s.weight ?? 0);
              }
            }
          }

          final locale = Localizations.localeOf(context).toString();
          final dateStr = DateFormat.yMMMd(locale).add_Hm().format(execution.startedAt);
          final duration = execution.duration;
          String? durationStr;
          if (duration != null && duration.inMinutes >= 1) {
            final h = duration.inMinutes ~/ 60;
            final m = duration.inMinutes % 60;
            durationStr = h > 0
                ? l10n.durationFormat(h, m)
                : l10n.durationMinutes(m);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AthlosSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: AthlosSpacing.xs),
                          Text(dateStr,
                              style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant)),
                          if (durationStr != null) ...[
                            const SizedBox(width: AthlosSpacing.md),
                            Icon(Icons.timer_outlined,
                                size: 16,
                                color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: AthlosSpacing.xs),
                            Text(durationStr,
                                style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ],
                      ),
                      const SizedBox(height: AthlosSpacing.md),

                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: _SummaryCard(
                              icon: Icons.check_circle_outline,
                              label: l10n.setsCompletedOf(
                                  totalCompletedSets, totalPlannedSets),
                              color: colorScheme.primary,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                          const SizedBox(width: AthlosSpacing.sm),
                          Expanded(
                            child: _SummaryCard(
                              icon: Icons.fitness_center,
                              label: l10n.volumeLabel(
                                  totalVolume.toStringAsFixed(0)),
                              color: colorScheme.tertiary,
                              colorScheme: colorScheme,
                              textTheme: textTheme,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AthlosSpacing.lg),
                    ],
                  ),
                ),
              ),

              // Per-exercise breakdown
              ...exerciseIds.map((exId) {
                final exerciseSets =
                    sets.where((s) => s.exerciseId == exId).toList();
                final ex = exerciseMap[exId];
                final name = ex != null
                    ? localizedExerciseName(ex.name,
                        isVerified: ex.isVerified, l10n: l10n)
                    : '#$exId';
                final group = ex != null
                    ? localizedMuscleGroupName(ex.muscleGroup, l10n)
                    : '';

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.md),
                    child: _ExerciseBreakdown(
                      exerciseName: name,
                      muscleGroup: group,
                      sets: exerciseSets,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      l10n: l10n,
                    ),
                  ),
                );
              }),

              const SliverPadding(
                  padding: EdgeInsets.only(bottom: AthlosSpacing.xl)),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AthlosSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AthlosRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AthlosSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseBreakdown extends StatelessWidget {
  final String exerciseName;
  final String muscleGroup;
  final List<ExecutionSet> sets;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _ExerciseBreakdown({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName, style: textTheme.titleSmall),
            if (muscleGroup.isNotEmpty)
              Text(muscleGroup,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: AthlosSpacing.sm),

            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Text(l10n.setsLabel,
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant))),
                  Expanded(
                      child: Text('Reps',
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant))),
                  SizedBox(
                      width: 60,
                      child: Text('Peso',
                          style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant))),
                  const SizedBox(width: 24),
                ],
              ),
            ),

            ...sets.map((s) => _SetRow(
                  setEntry: s,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  l10n: l10n,
                )),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final ExecutionSet setEntry;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _SetRow({
    required this.setEntry,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final metTarget = setEntry.isCompleted && setEntry.reps >= setEntry.plannedReps;
    final statusColor = setEntry.isCompleted
        ? (metTarget ? colorScheme.primary : colorScheme.error)
        : colorScheme.onSurfaceVariant;

    final weightStr = setEntry.weight != null
        ? '${setEntry.weight!.toStringAsFixed(setEntry.weight! % 1 == 0 ? 0 : 1)}kg'
        : '-';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '${setEntry.setNumber}',
                  style: textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${setEntry.reps}',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      TextSpan(
                        text: '/${setEntry.plannedReps}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(weightStr, style: textTheme.bodyMedium),
              ),
              SizedBox(
                width: 24,
                child: Icon(
                  setEntry.isCompleted
                      ? (metTarget ? Icons.check_circle : Icons.warning)
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),

        // Drop set segments
        if (setEntry.segments.length > 1)
          ...setEntry.segments.skip(1).map((seg) {
            final segWeightStr = seg.weight != null
                ? '${seg.weight!.toStringAsFixed(seg.weight! % 1 == 0 ? 0 : 1)}kg'
                : '-';
            return Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 2),
              child: Row(
                children: [
                  Icon(Icons.arrow_downward,
                      size: 12, color: colorScheme.tertiary),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 16,
                    child: Text('', style: textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      '${seg.reps}',
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      segWeightStr,
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            );
          }),
      ],
    );
  }
}
