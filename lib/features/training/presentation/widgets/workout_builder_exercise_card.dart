import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import 'workout_exercise_tile.dart' show supersetColorFor;

/// Compact exercise row for workout create/edit (aligned with ad-hoc overview cards).
class WorkoutBuilderExerciseCard extends StatelessWidget {
  final String exerciseName;
  final String muscleGroup;
  final String? prescriptionSummary;
  final bool isAmrap;
  final bool isUnilateral;
  final bool isGroupedWithPrevious;
  final bool isGroupedWithNext;
  final int? groupColorIndex;
  final bool isSupersetSelectionActive;
  final bool isSupersetSelected;
  final bool isSupersetSelectionLocked;
  final int? reorderListIndex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const WorkoutBuilderExerciseCard({
    super.key,
    required this.exerciseName,
    required this.muscleGroup,
    this.prescriptionSummary,
    this.isAmrap = false,
    this.isUnilateral = false,
    this.isGroupedWithPrevious = false,
    this.isGroupedWithNext = false,
    this.groupColorIndex,
    this.isSupersetSelectionActive = false,
    this.isSupersetSelected = false,
    this.isSupersetSelectionLocked = false,
    this.reorderListIndex,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isInGroup = isGroupedWithPrevious || isGroupedWithNext;

    final groupColor = isInGroup && groupColorIndex != null
        ? supersetColorFor(groupColorIndex!, colorScheme)
        : null;

    final IconData leadingIcon;
    final Color leadingColor;
    if (isSupersetSelectionActive) {
      if (isSupersetSelectionLocked) {
        leadingIcon = Icons.lock_outline;
        leadingColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
      } else {
        leadingIcon = isSupersetSelected
            ? Icons.check_circle
            : Icons.circle_outlined;
        leadingColor = isSupersetSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
      }
    } else {
      leadingIcon = Icons.fitness_center_outlined;
      leadingColor = colorScheme.onSurfaceVariant;
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm + 2,
      ),
      child: Row(
        children: [
          if (reorderListIndex != null)
            ReorderableDragStartListener(
              index: reorderListIndex!,
              child: Padding(
                padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                child: Icon(
                  Icons.drag_handle,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Icon(leadingIcon, color: leadingColor, size: 28),
          const SizedBox(width: AthlosSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isInGroup &&
                        !isGroupedWithPrevious &&
                        groupColor != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.xs,
                            vertical: AthlosSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.15),
                            borderRadius: AthlosRadius.xsAll,
                            border: Border.all(
                              color: groupColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.link, size: 10, color: groupColor),
                              const SizedBox(width: AthlosSpacing.xs),
                              Text(
                                l10n.supersetLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: groupColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: AthlosTruncatedText(
                        exerciseName,
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (muscleGroup.isNotEmpty || isUnilateral)
                  Row(
                    children: [
                      if (muscleGroup.isNotEmpty)
                        Flexible(
                          child: Text(
                            muscleGroup,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (isUnilateral) ...[
                        if (muscleGroup.isNotEmpty)
                          const SizedBox(width: AthlosSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.xs,
                            vertical: AthlosSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: AthlosRadius.fullAll,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 10,
                                color: colorScheme.onSecondaryContainer,
                              ),
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
                      ],
                    ],
                  ),
                if (prescriptionSummary != null &&
                    prescriptionSummary!.isNotEmpty) ...[
                  const SizedBox(height: AthlosSpacing.xxs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          prescriptionSummary!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isAmrap) ...[
                        const SizedBox(width: AthlosSpacing.xs),
                        Icon(
                          Icons.whatshot,
                          size: 12,
                          color: colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!isSupersetSelectionActive) ...[
            const SizedBox(width: AthlosSpacing.xs),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ],
      ),
    );

    BorderSide? cardBorder;
    if (isSupersetSelectionActive && isSupersetSelected) {
      cardBorder = BorderSide(color: colorScheme.primary, width: 2);
    } else if (groupColor != null) {
      cardBorder = BorderSide(color: groupColor.withValues(alpha: 0.4));
    }

    final card = Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.xs,
      ),
      shape: cardBorder != null
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: cardBorder,
            )
          : RoundedRectangleBorder(borderRadius: AthlosRadius.mdAll),
      child: Container(
        decoration: groupColor != null
            ? BoxDecoration(
                borderRadius: AthlosRadius.mdAll,
                border: Border(left: BorderSide(color: groupColor, width: 4)),
              )
            : null,
        child: InkWell(
          onTap: isSupersetSelectionLocked ? null : onTap,
          onLongPress: isSupersetSelectionLocked ? null : onLongPress,
          borderRadius: AthlosRadius.mdAll,
          child: content,
        ),
      ),
    );

    if (!isSupersetSelectionLocked) return card;

    return Opacity(opacity: 0.45, child: card);
  }
}
