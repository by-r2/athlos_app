import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// Compact KPI tile used in Kleos summary grids.
class KleosMetricTile extends StatelessWidget {
  const KleosMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.footer,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AthlosSpacing.xs),
                  decoration: BoxDecoration(
                    color: (iconColor ?? colorScheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: AthlosRadius.smAll,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: iconColor ?? colorScheme.primary,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const Gap(AthlosSpacing.xxs),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (footer != null) ...[
              const Gap(AthlosSpacing.sm),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
