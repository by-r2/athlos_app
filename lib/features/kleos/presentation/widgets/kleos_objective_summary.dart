import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'kleos_metric_tile.dart';

/// Snapshot KPI grid: totals that do not duplicate the Consistency section
/// (weekly rhythm and targets live there).
class KleosObjectiveSummary extends StatelessWidget {
  const KleosObjectiveSummary({
    super.key,
    required this.l10n,
    required this.finishedSessions,
    required this.estimatedPrCount,
    required this.muscleGroupsWithPr,
  });

  final AppLocalizations l10n;
  final int finishedSessions;
  final int estimatedPrCount;
  final int muscleGroupsWithPr;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: KleosMetricTile(
                  icon: Icons.fitness_center_outlined,
                  label: l10n.kleosMetricSessionsLabel,
                  value: finishedSessions.toString(),
                ),
              ),
              const Gap(AthlosSpacing.sm),
              Expanded(
                child: KleosMetricTile(
                  icon: Icons.emoji_events_outlined,
                  iconColor: colorScheme.tertiary,
                  label: l10n.kleosMetricPrsLabel,
                  value: estimatedPrCount.toString(),
                ),
              ),
            ],
          ),
        ),
        if (muscleGroupsWithPr > 0) ...[
          const Gap(AthlosSpacing.sm),
          KleosMetricTile(
            icon: Icons.accessibility_new_outlined,
            iconColor: colorScheme.primary,
            label: l10n.kleosMetricMuscleGroupsLabel,
            value: l10n.kleosMetricMuscleGroupsValue(muscleGroupsWithPr),
          ),
        ],
      ],
    );
  }
}
