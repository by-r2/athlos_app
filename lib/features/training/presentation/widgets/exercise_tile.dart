import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';

/// List tile for displaying an exercise in the catalog.
class ExerciseTile extends StatelessWidget {
  final String displayName;
  final String muscleGroupLabel;
  final String? targetMusclesLabel;
  final VoidCallback? onTap;

  const ExerciseTile({
    super.key,
    required this.displayName,
    required this.muscleGroupLabel,
    this.targetMusclesLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      title: Text(displayName),
      subtitle: targetMusclesLabel != null && targetMusclesLabel!.isNotEmpty
          ? AthlosTruncatedText(
              targetMusclesLabel!,
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.xs,
      ),
      onTap: onTap,
    );
  }
}
