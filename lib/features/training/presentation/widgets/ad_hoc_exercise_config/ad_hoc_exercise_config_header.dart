import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/theme/athlos_radius.dart';
import '../../../../../core/theme/athlos_spacing.dart';
import '../../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../helpers/exercise_l10n.dart';
import '../../../domain/entities/exercise.dart';

/// Exercise identity block for the improvised-workout config sheet.
class AdHocExerciseConfigHeader extends StatelessWidget {
  final Exercise exercise;

  const AdHocExerciseConfigHeader({required this.exercise, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final displayName = localizedExerciseName(
      exercise.name,
      isVerified: exercise.isVerified,
      l10n: l10n,
    );
    final muscleName = localizedMuscleGroupName(exercise.muscleGroup, l10n);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.fitness_center,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const Gap(AthlosSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AthlosTruncatedText(
                displayName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ),
              const Gap(AthlosSpacing.xxs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                  vertical: AthlosSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AthlosRadius.fullAll,
                ),
                child: Text(
                  muscleName,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
