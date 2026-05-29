import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// Fixed width for label balloons in [ExpandableFabActionRow] (all actions align).
const double kExpandableFabLabelWidth = 212;

/// One action shown above an expandable FAB (small FAB + readable label).
class ExpandableFabAction {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;

  const ExpandableFabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
  });
}

/// Label + [FloatingActionButton.small] row used by expandable training FABs.
class ExpandableFabActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final double labelWidth;

  const ExpandableFabActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.labelWidth = kExpandableFabLabelWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                elevation: AthlosElevation.md,
                shadowColor: colorScheme.shadow,
                color: colorScheme.surface,
                borderRadius: AthlosRadius.mdAll,
                child: SizedBox(
                  width: labelWidth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.md,
                      vertical: AthlosSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AthlosRadius.mdAll,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: AthlosSpacing.xxs),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AthlosSpacing.sm),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: onPressed,
                tooltip: label,
                child: Icon(icon),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated stack of [ExpandableFabActionRow] above a primary FAB.
class ExpandableFabMenu extends StatelessWidget {
  final bool expanded;
  final List<ExpandableFabAction> actions;
  final void Function(VoidCallback action) onActionSelected;
  final double labelWidth;

  const ExpandableFabMenu({
    required this.expanded,
    required this.actions,
    required this.onActionSelected,
    this.labelWidth = kExpandableFabLabelWidth,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AthlosDurations.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: AthlosSpacing.sm),
                    ExpandableFabActionRow(
                      icon: actions[i].icon,
                      label: actions[i].label,
                      subtitle: actions[i].subtitle,
                      labelWidth: labelWidth,
                      onPressed: () => onActionSelected(actions[i].onPressed),
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
