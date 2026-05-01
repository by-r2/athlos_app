import 'package:flutter/material.dart';

import '../../theme/athlos_spacing.dart';

/// Full-width vertical stack of action widgets — for screens, sheets, and any
/// layout that is not an [AlertDialog] (Athlos dialogs use this inside
/// [AlertDialog.actions] via [AthlosStackedDialogActions]; see
/// [DialogThemeData.actionsPadding] for inset around the actions pane.
///
/// When [invertStackOrder] is true (default), source order `[secondary, primary]`
/// renders the **primary on top** — same convention as [AthlosStackedDialogActions].
final class AthlosStackedActions extends StatelessWidget {
  const AthlosStackedActions({
    super.key,
    required this.children,
    this.invertStackOrder = true,
    this.padding = EdgeInsets.zero,
    this.spacing = AthlosSpacing.xs,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;

  /// Mirrors [children] for layout so callers keep writing `[secondary, primary]`.
  final bool invertStackOrder;

  final EdgeInsetsGeometry padding;

  /// Vertical gap between stacked children.
  final double spacing;

  final CrossAxisAlignment crossAxisAlignment;

  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final ordered = invertStackOrder
        ? children.reversed.toList(growable: false)
        : children;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            ordered[i],
          ],
        ],
      ),
    );
  }
}
