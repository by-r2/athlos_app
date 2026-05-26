import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../training/presentation/providers/training_metrics_provider.dart';

/// Cycle streak, weekly frequency streak, and current-week rhythm.
class KleosConsistencyPanel extends StatelessWidget {
  const KleosConsistencyPanel({
    super.key,
    required this.profile,
    required this.thisWeekCount,
    required this.weeklyTarget,
    required this.consistency,
    required this.l10n,
  });

  final UserProfile profile;
  final int thisWeekCount;
  final int weeklyTarget;
  final ConsistencyStatus consistency;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cycle = profile.currentCycleStreak;
    final freq = profile.currentFrequencyStreak;
    final bestCycle = profile.bestCycleStreak;
    final bestFreq = profile.bestFrequencyStreak;
    final dotCount =
        thisWeekCount > weeklyTarget ? thisWeekCount : weeklyTarget;
    final isCycleActive = cycle > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StreakCard(
                  icon: Icons.repeat_rounded,
                  iconColor: isCycleActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  title: l10n.dashboardCycleTitle,
                  value: l10n.dashboardCycleStreakCount(cycle),
                  subtitle: bestCycle > 0
                      ? l10n.dashboardStreakBestCycle(bestCycle)
                      : null,
                ),
              ),
              const Gap(AthlosSpacing.sm),
              Expanded(
                child: _StreakCard(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: consistency.isCurrentWeekSecured
                      ? colorScheme.error
                      : colorScheme.tertiary,
                  title: l10n.dashboardFrequencyTitle,
                  value: l10n.dashboardConsistencyStreak(freq),
                  subtitle: bestFreq > 0
                      ? l10n.dashboardStreakBestFrequency(bestFreq)
                      : null,
                ),
              ),
            ],
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const Gap(AthlosSpacing.xs),
                    Text(
                      l10n.kleosWeeklyRhythmTitle,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.dashboardFrequencyProgress(
                        thisWeekCount,
                        weeklyTarget,
                      ),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: thisWeekCount >= weeklyTarget
                            ? colorScheme.primary
                            : null,
                      ),
                    ),
                  ],
                ),
                const Gap(AthlosSpacing.md),
                Wrap(
                  spacing: AthlosSpacing.xs,
                  runSpacing: AthlosSpacing.xs,
                  children: List.generate(dotCount, (i) {
                    final isFilled = i < thisWeekCount;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: isFilled
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                    );
                  }),
                ),
                if (consistency.isCurrentWeekSecured) ...[
                  const Gap(AthlosSpacing.sm),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const Gap(AthlosSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.kleosWeeklyTargetMet,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AthlosSpacing.xs),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: AthlosRadius.smAll,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              title,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AthlosSpacing.xxs),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const Gap(AthlosSpacing.xxs),
              Text(
                subtitle!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
