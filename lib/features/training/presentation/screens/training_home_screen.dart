import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/execution_comparison.dart';
import '../../domain/entities/workout_execution.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/program_focus.dart';
import '../helpers/duration_format.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/workout_execution_launch.dart';
import '../providers/dangling_execution_dialog_session.dart';
import '../providers/exercise_notifier.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';
import '../providers/training_metrics_provider.dart';
import '../providers/workout_execution_notifier.dart';
import '../providers/workout_notifier.dart';
import '../../../profile/presentation/providers/profile_notifier.dart'
    show profileProvider;
import '../../../profile/presentation/widgets/body_metrics_dashboard_card.dart';

/// Training module — Dashboard tab.
///
/// Single scrollable view ordered by motivational priority:
/// program banner → streaks/frequency → recent PR → evolution →
/// weekly volume → body metrics → library section,
/// with a FAB to start the next workout.
class TrainingHomeScreen extends ConsumerStatefulWidget {
  const TrainingHomeScreen({super.key});

  @override
  ConsumerState<TrainingHomeScreen> createState() => _TrainingHomeScreenState();
}

class _TrainingHomeScreenState extends ConsumerState<TrainingHomeScreen> {
  late final DanglingExecutionDialogSession _dialogSession;
  bool _didScheduleInitialDanglingCheck = false;

  @override
  void initState() {
    super.initState();
    _dialogSession = ref.read(danglingExecutionDialogSessionProvider.notifier);
  }

  @override
  void dispose() {
    _dialogSession.cancelHomePrompt();
    super.dispose();
  }

  void _onDanglingExecutionChanged(AsyncValue<WorkoutExecution?> next) {
    if (!context.mounted) return;
    next.when(
      data: (execution) {
        if (execution == null) {
          _dialogSession.clear();
          return;
        }
        if (!_dialogSession.shouldShowHomePrompt(execution.id)) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          showDanglingExecutionHomeDialogIfNeeded(context, ref, execution);
        });
      },
      loading: () {},
      error: (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_didScheduleInitialDanglingCheck) {
      _didScheduleInitialDanglingCheck = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _onDanglingExecutionChanged(ref.read(danglingExecutionProvider));
      });
    }

    ref.listen(danglingExecutionProvider, (prev, next) {
      if (prev?.value?.id == next.value?.id &&
          prev?.hasValue == true &&
          next.hasValue) {
        return;
      }
      _onDanglingExecutionChanged(next);
    });

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CompactProgramBanner(),
            const Gap(AthlosSpacing.sm),
            _StatPillsRow(l10n: l10n),
            const Gap(AthlosSpacing.sm),
            const _RecentPRCard(),
            const Gap(AthlosSpacing.sm),
            _EvolutionCard(l10n: l10n),
            const Gap(AthlosSpacing.md),
            const _WeeklyVolumeCard(),
            const Gap(AthlosSpacing.md),
            const BodyMetricsDashboardCard(),
            const Gap(AthlosSpacing.lg),
            _LibrarySection(l10n: l10n),
            const Gap(AthlosSpacing.fabClearance),
          ],
        ),
      ),
    );
  }
}

// ── Compact Program Banner ────────────────────────────────────────────

class _CompactProgramBanner extends ConsumerWidget {
  const _CompactProgramBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final programAsync = ref.watch(activeProgramProvider);
    final program = programAsync.value;
    if (program == null) return const SizedBox.shrink();

    final focusLabel = switch (program.focus) {
      ProgramFocus.hypertrophy => l10n.programFocusHypertrophy,
      ProgramFocus.strength => l10n.programFocusStrength,
      ProgramFocus.endurance => l10n.programFocusEndurance,
      ProgramFocus.custom => l10n.programFocusCustom,
    };

    final progressAsync = ref.watch(programProgressProvider(program.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AthlosRadius.mdAll,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: () => context.push(RoutePaths.trainingProgramDetail(program.id)),
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
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
                      program.name,
                      style: textTheme.titleSmall,
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
                      ),
                    ),
                  ),
                  if (program.isInDeload) ...[
                    const Gap(AthlosSpacing.xs),
                    Icon(Icons.spa, size: 16, color: colorScheme.tertiary),
                  ],
                  const Gap(AthlosSpacing.xs),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const Gap(AthlosSpacing.sm),
              progressAsync.when(
                data: (progress) => ClipRRect(
                  borderRadius: AthlosRadius.smAll,
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 4,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
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

// ── Library Section ───────────────────────────────────────────────────

class _LibrarySection extends ConsumerWidget {
  final AppLocalizations l10n;

  const _LibrarySection({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final exercisesAsync = ref.watch(exerciseListProvider);
    final exerciseCount = exercisesAsync.value?.length ?? 0;

    final workoutsAsync = ref.watch(workoutListProvider);
    final workoutCount = workoutsAsync.value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashboardCatalogsTab,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        _CatalogCard(
          icon: Icons.fitness_center,
          title: l10n.workoutsCatalog,
          subtitle: workoutCount > 0
              ? l10n.workoutsCount(workoutCount)
              : l10n.workoutsCatalogDesc,
          onTap: () => context.go(RoutePaths.trainingWorkoutCatalog),
        ),
        const Gap(AthlosSpacing.sm),
        _CatalogCard(
          icon: Icons.sports_gymnastics,
          title: l10n.exercisesCatalog,
          subtitle: exerciseCount > 0
              ? l10n.exercisesCount(exerciseCount)
              : l10n.exercisesCatalogDesc,
          onTap: () => context.go(RoutePaths.trainingExercises),
        ),
      ],
    );
  }
}

// ── Stat pills (frequency + cycle) ───────────────────────────────────

class _StatPillsRow extends ConsumerWidget {
  final AppLocalizations l10n;

  const _StatPillsRow({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _FrequencyPill(l10n: l10n)),
          const Gap(AthlosSpacing.sm),
          Expanded(child: _FinishedSessionsPill(l10n: l10n)),
        ],
      ),
    );
  }
}

class _FrequencyPill extends ConsumerWidget {
  final AppLocalizations l10n;

  const _FrequencyPill({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final thisWeek = ref.watch(thisWeekSessionCountProvider).value ?? 0;
    final profileAsync = ref.watch(profileProvider);
    final target =
        profileAsync.value?.trainingFrequency ?? kDefaultTrainingFrequency;
    final consistencyStatus =
        ref.watch(consistencyStatusProvider).value ??
        const ConsistencyStatus(streakCount: 0, isCurrentWeekSecured: false);
    final frequencyStreak = profileAsync.value?.currentFrequencyStreak ?? 0;
    final bestFrequencyStreak = profileAsync.value?.bestFrequencyStreak ?? 0;

    final dotCount = thisWeek > target ? thisWeek : target;

    return Tooltip(
      message: l10n.dashboardConsistencyTooltip(target),
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.dashboardFrequencyTitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Gap(AthlosSpacing.sm),
              Text(
                l10n.dashboardFrequencyProgress(thisWeek, target),
                style: textTheme.titleSmall,
              ),
              const Gap(AthlosSpacing.xs),
              Wrap(
                spacing: AthlosSpacing.xxs,
                runSpacing: AthlosSpacing.xxs,
                children: List.generate(dotCount, (i) {
                  final isFilled = i < thisWeek;
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                    ),
                  );
                }),
              ),
              const Gap(AthlosSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 14,
                    color: consistencyStatus.isCurrentWeekSecured
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  const Gap(AthlosSpacing.xxs),
                  Expanded(
                    child: Text(
                      l10n.dashboardConsistencyStreak(frequencyStreak),
                      style: textTheme.bodySmall?.copyWith(
                        color: consistencyStatus.isCurrentWeekSecured
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (bestFrequencyStreak > 0) ...[
                const Gap(AthlosSpacing.xxs),
                Text(
                  l10n.dashboardStreakBestFrequency(bestFrequencyStreak),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedSessionsPill extends ConsumerWidget {
  final AppLocalizations l10n;

  const _FinishedSessionsPill({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final sessionCount =
        ref.watch(finishedSessionCountProvider).value ?? 0;
    final hasSessions = sessionCount > 0;

    return Tooltip(
      message: l10n.dashboardFinishedSessionsTooltip,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    l10n.dashboardFinishedSessionsTitle,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Gap(AthlosSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: hasSessions
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Expanded(
                    child: _DashboardPillValueText(
                      l10n.dashboardFinishedSessionsCount(sessionCount),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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

/// Value line in dashboard stat pills: wraps on up to two lines and scales
/// down when the label is long or the count is large.
class _DashboardPillValueText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _DashboardPillValueText(this.text, {this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Text(
              text,
              style: style,
              maxLines: 2,
              softWrap: true,
            ),
          ),
        );
      },
    );
  }
}

// ── Weekly Volume with targets ───────────────────────────────────────

class _WeeklyVolumeCard extends ConsumerWidget {
  const _WeeklyVolumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final volumeAsync = ref.watch(weeklyVolumePerMuscleGroupProvider);
    final profileAsync = ref.watch(profileProvider);
    final experienceLevel = profileAsync.value?.experienceLevel?.name;
    final target = volumeTargetForLevel(experienceLevel);

    return volumeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (volume) {
        if (volume.isEmpty) return const SizedBox.shrink();
        final sorted = volume.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return Tooltip(
          message: l10n.weeklyVolumeTooltip,
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: true,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(RoutePaths.trainingVolumeTrend),
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const Gap(AthlosSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.weeklyVolume,
                            style: textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          l10n.dashboardVolumeTargetRange(
                            target.min,
                            target.max,
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Gap(AthlosSpacing.xs),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const Gap(AthlosSpacing.sm),
                    ...sorted.map((e) {
                      final group = MuscleGroup.values
                          .where((g) => g.name == e.key)
                          .firstOrNull;
                      final label = group != null
                          ? localizedMuscleGroupName(group, l10n)
                          : e.key;
                      return _VolumeRow(
                        label: label,
                        workingSets: e.value,
                        targetMin: target.min,
                        targetMax: target.max,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        l10n: l10n,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final String label;
  final int workingSets;
  final int targetMin;
  final int targetMax;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _VolumeRow({
    required this.label,
    required this.workingSets,
    required this.targetMin,
    required this.targetMax,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  static const _volumeGood = Color(0xFF4CAF50);
  static const _volumeOver = Color(0xFFE67E22);

  @override
  Widget build(BuildContext context) {
    final fraction = (workingSets / targetMax).clamp(0.0, 1.0);
    final statusColor = workingSets < targetMin
        ? colorScheme.error
        : workingSets > targetMax
        ? _volumeOver
        : _volumeGood;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: AthlosTruncatedText(
              label,
              style: textTheme.bodySmall,
              maxLines: 1,
            ),
          ),
          const Gap(AthlosSpacing.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: statusColor,
              ),
            ),
          ),
          const Gap(AthlosSpacing.sm),
          SizedBox(
            width: 88,
            child: Text(
              l10n.weeklyVolumeSets(workingSets),
              style: textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent PR Card ───────────────────────────────────────────────────

class _RecentPRCard extends ConsumerWidget {
  const _RecentPRCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final prsAsync = ref.watch(allExercisePRsProvider);

    return prsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();
        final top = prs.first;
        final name = localizedExerciseName(
          top.exerciseName,
          isVerified: top.isVerified,
          l10n: l10n,
        );
        final e1rmStr = top.best1RM % 1 == 0
            ? top.best1RM.toInt().toString()
            : top.best1RM.toStringAsFixed(1);
        return Tooltip(
          message: l10n.prTooltip,
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: true,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(RoutePaths.trainingPRHistory),
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: colorScheme.tertiary,
                      size: 24,
                    ),
                    const Gap(AthlosSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.prBadge, style: textTheme.titleSmall),
                          Text(
                            '$name — $e1rmStr kg',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Evolution Card ───────────────────────────────────────────────────

class _EvolutionCard extends ConsumerWidget {
  const _EvolutionCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(lastExecutedWorkoutComparisonProvider);
    return comparisonAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final c = data.comparison;
        final lastDurationSec = c.last.duration?.inSeconds ?? 0;
        final prevDurationSec = c.previous.duration?.inSeconds ?? 0;
        final locale = Localizations.localeOf(context);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(
              '${RoutePaths.trainingHistory}?workoutId=${c.last.workoutId}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.trainingEvolutionRecent,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    data.workoutName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Gap(AthlosSpacing.sm),
                  _evolutionRow(
                    context,
                    l10n.trainingLastSession,
                    intl.DateFormat.MMMd(
                      locale.toString(),
                    ).format(c.last.startedAt.toLocal()),
                    formatDuration(lastDurationSec),
                    c.volumeLast,
                  ),
                  const Gap(AthlosSpacing.xs),
                  _evolutionRow(
                    context,
                    l10n.trainingPreviousSession,
                    intl.DateFormat.MMMd(
                      locale.toString(),
                    ).format(c.previous.startedAt.toLocal()),
                    formatDuration(prevDurationSec),
                    c.volumePrevious,
                  ),
                  if (c.volumeDelta != 0 || c.volumePercentChange != null) ...[
                    const Gap(AthlosSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          c.volumeDelta > 0
                              ? Icons.trending_up
                              : c.volumeDelta < 0
                              ? Icons.trending_down
                              : Icons.trending_flat,
                          size: 16,
                          color: c.volumeDelta > 0
                              ? Theme.of(context).colorScheme.primary
                              : c.volumeDelta < 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const Gap(AthlosSpacing.xs),
                        Text(
                          _deltaText(c),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: c.volumeDelta > 0
                                    ? Theme.of(context).colorScheme.primary
                                    : c.volumeDelta < 0
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _evolutionRow(
    BuildContext context,
    String label,
    String date,
    String duration,
    double volume,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '$date · $duration · ${volume.toStringAsFixed(0)} kg',
            style: textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  String _deltaText(ExecutionComparison comparison) {
    final delta = comparison.volumeDelta;
    final sign = delta > 0
        ? '+'
        : delta < 0
        ? '-'
        : '';
    final percent = comparison.volumePercentChange;

    if (percent != null) {
      final formattedPercent = '$sign${percent.abs().toStringAsFixed(0)}';
      return l10n.trainingVolumePercent(formattedPercent);
    }

    final formattedDelta = '$sign${delta.abs().toStringAsFixed(1)}';
    return l10n.trainingVolumeDelta(formattedDelta);
  }
}

// ── Catalog Card ─────────────────────────────────────────────────────

class _CatalogCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CatalogCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Row(
            children: [
              Icon(icon, size: 32, color: colorScheme.primary),
              const Gap(AthlosSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    const Gap(AthlosSpacing.xs),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
