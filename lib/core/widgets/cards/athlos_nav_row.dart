import 'package:flutter/material.dart';

import '../../theme/athlos_component_sizes.dart';
import '../../theme/athlos_radius.dart';
import '../../theme/athlos_spacing.dart';

/// Tappable navigation row with filled surface and chevron.
///
/// Pair with [AthlosStatusCallout] for read-only status above a destination row.
class AthlosNavRow extends StatelessWidget {
  const AthlosNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: AthlosRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          minTileHeight: AthlosComponentSizes.listItemMinHeight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.md,
            vertical: AthlosSpacing.xs,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AthlosRadius.mdAll,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
