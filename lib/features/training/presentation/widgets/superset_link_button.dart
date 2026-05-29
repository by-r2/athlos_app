import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Pill button between two exercises to link/unlink a superset (workout builder + ad-hoc).
class SupersetLinkButton extends StatelessWidget {
  final bool isLinked;
  final VoidCallback onTap;
  final Color? linkedColor;

  const SupersetLinkButton({
    required this.isLinked,
    required this.onTap,
    this.linkedColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = linkedColor ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.xs),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.sm,
              vertical: AthlosSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: isLinked
                  ? activeColor.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isLinked
                    ? activeColor.withValues(alpha: 0.45)
                    : colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLinked ? Icons.link : Icons.link_off,
                  size: 12,
                  color: isLinked ? activeColor : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AthlosSpacing.xs),
                Text(
                  isLinked ? l10n.unlinkSuperset : l10n.linkSuperset,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isLinked
                            ? activeColor
                            : colorScheme.onSurfaceVariant,
                        fontWeight: isLinked ? FontWeight.w600 : null,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
