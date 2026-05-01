import 'package:flutter/material.dart';

import '../../theme/athlos_button_sizes.dart';
import '../../theme/athlos_spacing.dart';

/// One action widget per row, full width — use under [AlertDialog.content].
///
/// Order **top → bottom**: secondary / dismiss [TextButton] (ghost) first,
/// [FilledButton] primary **last**. Ghost actions use neutral theme foreground
/// (no error tint). Spacing between rows matches [AthlosSpacing.sm];
/// inset above the stack uses [AthlosSpacing.dialogBodyToActions] so body copy
/// does not need extra [SizedBox] before this widget.
final class AthlosStackedDialogActions extends StatelessWidget {
  const AthlosStackedDialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AthlosSpacing.dialogBodyToActions),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AthlosSpacing.sm),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Full-width stacking styles on top of the dialog [ThemeData] button themes.
abstract final class AthlosDialogButtonStyles {
  AthlosDialogButtonStyles._();

  static const WidgetStatePropertyAll<Size> _stackedMinSize =
      WidgetStatePropertyAll<Size>(
    Size(double.infinity, AthlosButtonSizes.dialogMinHeight),
  );

  static ButtonStyle stackedGhost(BuildContext context) =>
      (Theme.of(context).textButtonTheme.style ?? const ButtonStyle()).merge(
        const ButtonStyle(
          alignment: Alignment.center,
          minimumSize: _stackedMinSize,
        ),
      );

  static ButtonStyle stackedFilled(BuildContext context) =>
      (Theme.of(context).filledButtonTheme.style ?? const ButtonStyle()).merge(
        const ButtonStyle(
          alignment: Alignment.center,
          minimumSize: _stackedMinSize,
        ),
      );
}
