import 'package:flutter/material.dart';

import '../../theme/athlos_component_sizes.dart';
import '../../utils/display_name_initials.dart';

/// Circular avatar showing [displayName] initials until a real photo exists.
///
/// When [displayName] is missing or yields no initials, shows a neutral
/// [Icons.person_outline] placeholder.
class AthlosInitialsAvatar extends StatelessWidget {
  const AthlosInitialsAvatar({
    super.key,
    this.displayName,
    this.radius = AthlosComponentSizes.avatarRadiusLg,
  });

  final String? displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initials = displayNameInitials(displayName);
    final fontSize = radius * 0.72;

    final (backgroundColor, foregroundColor) = initials != null
        ? _colorsForInitials(colorScheme, initials)
        : (
            colorScheme.surfaceContainerHighest,
            colorScheme.onSurfaceVariant,
          );

    return Semantics(
      label: displayName?.trim().isNotEmpty == true ? displayName : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: initials != null
            ? Text(
                initials,
                style: textTheme.titleLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  height: 1,
                  letterSpacing: initials.length > 1 ? 0.5 : 0,
                ),
              )
            : Icon(
                Icons.person_outline_rounded,
                size: radius * 1.05,
                color: foregroundColor,
              ),
      ),
    );
  }

  /// Stable accent from initials so the same user keeps the same tint.
  (Color background, Color foreground) _colorsForInitials(
    ColorScheme colorScheme,
    String initials,
  ) {
    final hash = initials.codeUnits.fold<int>(0, (h, c) => h + c * 31);
    final variants = [
      (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
      (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
    ];
    return variants[hash.abs() % variants.length];
  }
}
