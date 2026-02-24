import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// A card representing a module on the Hub screen.
///
/// Example of a reusable feature-specific widget following conventions:
/// - Colors from Theme, never hardcoded
/// - Strings received as parameters (caller uses AppLocalizations)
/// - const constructor
/// - SizedBox/Gap for spacing instead of Padding
class ModuleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isEnabled;
  final String? disabledLabel;
  final VoidCallback? onTap;

  const ModuleCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.isEnabled = true,
    this.disabledLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Always get colors and text styles from the theme
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isEnabled ? AthlosElevation.sm : AthlosElevation.none,
      color: isEnabled
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLow.withAlpha(128),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Row(
            children: [
              // Module icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: AthlosRadius.lgAll,
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isEnabled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.md),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: isEnabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AthlosSpacing.xs),
                    Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow or "coming soon" badge
              if (isEnabled)
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                )
              else if (disabledLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.smd,
                    vertical: AthlosSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AthlosRadius.mdAll,
                  ),
                  child: Text(
                    disabledLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
