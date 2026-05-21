import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/athlos_assets.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/execution_set.dart';
import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_execution.dart';
import '../helpers/duration_format.dart';
import '../helpers/workout_share_metrics.dart';

/// Shareable workout summary card (wrapped in [RepaintBoundary] via [captureKey]).
class WorkoutExecutionShareSummary extends StatelessWidget {
  final GlobalKey captureKey;
  final WorkoutExecution execution;
  final List<ExecutionSet> sets;
  final String workoutName;
  final Map<String, Exercise>? exerciseById;
  final Map<String, WorkoutExercise>? workoutExerciseByExerciseId;
  final double? profileBodyWeightOnExecutionDate;
  final double? latestBodyWeight;

  const WorkoutExecutionShareSummary({
    super.key,
    required this.captureKey,
    required this.execution,
    required this.sets,
    required this.workoutName,
    this.exerciseById,
    this.workoutExerciseByExerciseId,
    this.profileBodyWeightOnExecutionDate,
    this.latestBodyWeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final metrics = computeWorkoutShareMetrics(
      sets,
      exerciseById: exerciseById,
      workoutExerciseByExerciseId: workoutExerciseByExerciseId,
      profileBodyWeightOnExecutionDate: profileBodyWeightOnExecutionDate,
      latestBodyWeight: latestBodyWeight,
    );
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMd(
      locale,
    ).add_Hm().format(execution.startedAt);
    final durationStr = formatWorkoutTotalDuration(execution.duration, l10n);

    return Center(
      child: RepaintBoundary(
        key: captureKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: AthlosRadius.lgAll,
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.07),
                    blurRadius: AthlosElevation.md,
                    offset: const Offset(0, AthlosSpacing.xs),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AthlosRadius.lgAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AthlosSpacing.lg,
                        AthlosSpacing.lg,
                        AthlosSpacing.lg,
                        AthlosSpacing.smd,
                      ),
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            AthlosAssets.athlosIconFlat,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                          const Gap(AthlosSpacing.sm),
                          Text(
                            l10n.workoutShareSummaryCardHint,
                            textAlign: TextAlign.center,
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Gap(AthlosSpacing.smd),
                          Text(
                            workoutName,
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(AthlosSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color: colorScheme.secondary,
                              ),
                              const Gap(AthlosSpacing.xs),
                              Flexible(
                                child: Text(
                                  dateStr,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.lg,
                      ),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AthlosSpacing.md),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (durationStr != null) ...[
                                      _ShareStatTile(
                                        icon: Icons.schedule_rounded,
                                        label: durationStr,
                                        isTertiaryTone: false,
                                        colorScheme: colorScheme,
                                        textTheme: textTheme,
                                      ),
                                      const Gap(AthlosSpacing.sm),
                                    ],
                                    _ShareStatTile(
                                      icon: Icons.check_circle_outline_rounded,
                                      label: l10n.setsCompletedOf(
                                        metrics.totalCompletedSets,
                                        metrics.totalPlannedSets,
                                      ),
                                      isTertiaryTone: false,
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    ),
                                    const Gap(AthlosSpacing.sm),
                                    _ShareStatTile(
                                      icon: Icons.fitness_center_rounded,
                                      label: l10n.volumeLabel(
                                        metrics.totalVolume.toStringAsFixed(0),
                                      ),
                                      isTertiaryTone: true,
                                      colorScheme: colorScheme,
                                      textTheme: textTheme,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AthlosAssets.athlosIconFlat,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                          const Gap(AthlosSpacing.xs),
                          Text(
                            'Athlos',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stat row: neutral tile + solid brand “badge” for the icon (high contrast).
class _ShareStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isTertiaryTone;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ShareStatTile({
    required this.icon,
    required this.label,
    required this.isTertiaryTone,
    required this.colorScheme,
    required this.textTheme,
  });

  static const double _badgeSize = 44;

  @override
  Widget build(BuildContext context) {
    final badgeBg = isTertiaryTone ? colorScheme.tertiary : colorScheme.primary;
    final badgeFg = isTertiaryTone
        ? colorScheme.onTertiary
        : colorScheme.onPrimary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AthlosRadius.mdAll,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: AthlosRadius.smAll,
              ),
              child: SizedBox(
                width: _badgeSize,
                height: _badgeSize,
                child: Icon(icon, size: 22, color: badgeFg),
              ),
            ),
            const Gap(AthlosSpacing.md),
            Expanded(
              child: AthlosTruncatedText(
                label,
                textAlign: TextAlign.start,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
