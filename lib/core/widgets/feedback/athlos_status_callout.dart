import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../theme/athlos_custom_colors.dart';
import '../../theme/athlos_radius.dart';
import '../../theme/athlos_spacing.dart';

/// Visual tone for [AthlosStatusCallout].
///
/// Status callouts are **non-interactive** — use [AthlosNavRow] for tappable
/// navigation targets so users can tell pills apart from buttons.
enum AthlosStatusCalloutTone {
  neutral,
  success,
  warning,
  error,
}

/// Non-interactive status pill (loading, empty state, warnings).
///
/// Outlined, low-emphasis surface so it does not read like [AthlosNavRow].
class AthlosStatusCallout extends StatelessWidget {
  const AthlosStatusCallout({
    super.key,
    required this.icon,
    required this.message,
    this.tone = AthlosStatusCalloutTone.neutral,
    this.iconColor,
  });

  final IconData icon;
  final String message;
  final AthlosStatusCalloutTone tone;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>();
    final style = _resolveStyle(colorScheme, customColors, tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: AthlosRadius.smAll,
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor ?? style.icon),
          const Gap(AthlosSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: style.foreground,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ({Color background, Color border, Color foreground, Color icon})
  _resolveStyle(
    ColorScheme colorScheme,
    AthlosCustomColors? customColors,
    AthlosStatusCalloutTone tone,
  ) {
    switch (tone) {
      case AthlosStatusCalloutTone.neutral:
        return (
          background: Colors.transparent,
          border: colorScheme.outlineVariant,
          foreground: colorScheme.onSurfaceVariant,
          icon: colorScheme.onSurfaceVariant,
        );
      case AthlosStatusCalloutTone.success:
        return (
          background: colorScheme.primary.withValues(alpha: 0.08),
          border: colorScheme.primary.withValues(alpha: 0.28),
          foreground: colorScheme.onSurface,
          icon: colorScheme.primary,
        );
      case AthlosStatusCalloutTone.warning:
        final warningStyle =
            customColors?.duplicateWarningCallout(colorScheme) ??
            (
              background: colorScheme.tertiaryContainer,
              foreground: colorScheme.onSurface,
              icon: colorScheme.tertiary,
              border: colorScheme.outlineVariant,
            );
        return (
          background: warningStyle.background,
          border: warningStyle.border,
          foreground: warningStyle.foreground,
          icon: warningStyle.icon,
        );
      case AthlosStatusCalloutTone.error:
        return (
          background: colorScheme.errorContainer.withValues(alpha: 0.45),
          border: colorScheme.error.withValues(alpha: 0.35),
          foreground: colorScheme.onErrorContainer,
          icon: colorScheme.error,
        );
    }
  }
}
