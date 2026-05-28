import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../theme/athlos_spacing.dart';

/// Section header with optional icon and subtitle, placed on the scaffold background.
///
/// Use [child] for grouped content (often wrapped in a [Card]).
class AthlosSection extends StatelessWidget {
  const AthlosSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.child,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? child;

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
        if (subtitle != null) ...[
          const Gap(AthlosSpacing.xxs),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        if (child != null) ...[
          const Gap(AthlosSpacing.md),
          child!,
        ],
      ],
    );
  }
}
