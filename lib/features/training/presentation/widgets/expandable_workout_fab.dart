import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';

/// Expandable FAB with Chiron and manual-create actions (workout catalog).
class ExpandableWorkoutFab extends StatefulWidget {
  final String chironLabel;
  final String createManualLabel;
  final VoidCallback onChiron;
  final VoidCallback onCreateManual;

  const ExpandableWorkoutFab({
    required this.chironLabel,
    required this.createManualLabel,
    required this.onChiron,
    required this.onCreateManual,
    super.key,
  });

  @override
  State<ExpandableWorkoutFab> createState() => _ExpandableWorkoutFabState();
}

class _ExpandableWorkoutFabState extends State<ExpandableWorkoutFab> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _onAction(VoidCallback action) {
    action();
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ExpandableFabActionChip(
                        icon: Icons.auto_awesome,
                        label: widget.chironLabel,
                        onPressed: () => _onAction(widget.onChiron),
                      ),
                      const SizedBox(height: AthlosSpacing.sm),
                      _ExpandableFabActionChip(
                        icon: Icons.edit_note,
                        label: widget.createManualLabel,
                        onPressed: () => _onAction(widget.onCreateManual),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'catalog_fab',
          onPressed: _toggle,
          tooltip: _expanded ? '' : widget.createManualLabel,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _ExpandableFabActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ExpandableFabActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: AthlosRadius.mdAll,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AthlosSpacing.sm,
                vertical: AthlosSpacing.xs,
              ),
              child: AthlosTruncatedText(
                label,
                style: textTheme.labelLarge,
                maxLines: 1,
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
    );
  }
}
