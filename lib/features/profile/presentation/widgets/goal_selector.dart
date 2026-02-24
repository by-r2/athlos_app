import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/training_goal.dart';

/// Selector for [TrainingGoal].
///
/// Each goal is a selectable card with icon, title, and short description.
/// When [shouldShowHelp] is true, an animated panel expands below each card
/// explaining the impact of that option on the system.
class GoalSelector extends StatelessWidget {
  final TrainingGoal? selected;
  final ValueChanged<TrainingGoal> onSelected;
  final bool shouldShowHelp;

  const GoalSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.shouldShowHelp = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.goalSelectTitle, style: textTheme.titleMedium),
        const Gap(AthlosSpacing.md),
        ...TrainingGoal.values.map((goal) {
          final isSelected = goal == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: isSelected ? AthlosElevation.sm : AthlosElevation.none,
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: AthlosRadius.mdAll,
                side: isSelected
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => onSelected(goal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                    vertical: AthlosSpacing.smd,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconFor(goal),
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AthlosSpacing.smd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleFor(goal, l10n),
                                  style: textTheme.titleSmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _descriptionFor(goal, l10n),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),

                      // Help panel
                      AnimatedSize(
                        duration: AthlosDurations.normal,
                        curve: Curves.easeInOut,
                        child: shouldShowHelp
                            ? Padding(
                                padding: const EdgeInsets.only(top: AthlosSpacing.smd),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AthlosSpacing.smd),
                                  decoration: BoxDecoration(
                                    borderRadius: AthlosRadius.smAll,
                                    color: colorScheme.surfaceContainerHighest
                                        .withAlpha(120),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const Gap(AthlosSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _impactFor(goal, l10n),
                                          style:
                                              textTheme.bodySmall?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _iconFor(TrainingGoal goal) => switch (goal) {
        TrainingGoal.hypertrophy => Icons.fitness_center,
        TrainingGoal.weightLoss => Icons.local_fire_department,
        TrainingGoal.endurance => Icons.directions_run,
        TrainingGoal.strength => Icons.bolt,
        TrainingGoal.generalFitness => Icons.favorite,
      };

  String _titleFor(TrainingGoal goal, AppLocalizations l10n) => switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophy,
        TrainingGoal.weightLoss => l10n.goalWeightLoss,
        TrainingGoal.endurance => l10n.goalEndurance,
        TrainingGoal.strength => l10n.goalStrength,
        TrainingGoal.generalFitness => l10n.goalGeneralFitness,
      };

  String _descriptionFor(TrainingGoal goal, AppLocalizations l10n) =>
      switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophyDesc,
        TrainingGoal.weightLoss => l10n.goalWeightLossDesc,
        TrainingGoal.endurance => l10n.goalEnduranceDesc,
        TrainingGoal.strength => l10n.goalStrengthDesc,
        TrainingGoal.generalFitness => l10n.goalGeneralFitnessDesc,
      };

  String _impactFor(TrainingGoal goal, AppLocalizations l10n) => switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophyImpact,
        TrainingGoal.weightLoss => l10n.goalWeightLossImpact,
        TrainingGoal.endurance => l10n.goalEnduranceImpact,
        TrainingGoal.strength => l10n.goalStrengthImpact,
        TrainingGoal.generalFitness => l10n.goalGeneralFitnessImpact,
      };
}
