import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_section.dart';

/// Grouped settings block for program detail / form screens.
///
/// Section title and icon sit on the page background; [child] is wrapped in a
/// [Card], matching the Kleos section layout pattern.
class ProgramSettingsSectionCard extends StatelessWidget {
  const ProgramSettingsSectionCard({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.child,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AthlosSection(
      title: title,
      subtitle: subtitle,
      icon: icon,
      child: child == null
          ? null
          : Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: child,
              ),
            ),
    );
  }
}
