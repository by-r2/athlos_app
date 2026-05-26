import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_spacing.dart';

/// Section header with optional icon and subtitle.
class KleosSection extends StatelessWidget {
  const KleosSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.icon,
  });

  final String title;
  final String? hint;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: colorScheme.primary),
              const Gap(AthlosSpacing.xs),
            ],
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (hint != null) ...[
          const Gap(AthlosSpacing.xxs),
          Text(
            hint!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const Gap(AthlosSpacing.md),
        child,
      ],
    );
  }
}
