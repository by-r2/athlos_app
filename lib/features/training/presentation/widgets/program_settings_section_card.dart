import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// Grouped settings block for program detail / form screens.
class ProgramSettingsSectionCard extends StatelessWidget {
  const ProgramSettingsSectionCard({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.child,
  });

  static const double _iconBoxSize = 48;

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final subtitleStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: subtitle == null
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Container(
                    width: _iconBoxSize,
                    height: _iconBoxSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: AthlosRadius.mdAll,
                    ),
                    child: Icon(
                      icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const Gap(AthlosSpacing.smd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: titleStyle),
                      if (subtitle != null) ...[
                        const Gap(AthlosSpacing.xs),
                        Text(subtitle!, style: subtitleStyle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) ...[
              const Gap(AthlosSpacing.md),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
