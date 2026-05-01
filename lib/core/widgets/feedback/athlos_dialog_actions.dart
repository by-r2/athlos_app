import 'package:flutter/material.dart';

import '../../theme/athlos_button_insets.dart';
import '../../theme/athlos_button_sizes.dart';
import '../../theme/athlos_spacing.dart';
import '../layout/athlos_stacked_actions.dart';

/// One action widget per row, full width — use under [AlertDialog.content].
///
/// By default (**[invertStackOrder] == true**) the vertical order is mirrored so
/// a typical declarative `[ghost, filled]` list shows [FilledButton] **on top**
/// and ghost **below**. Set [invertStackOrder] to false when every action is a
/// peer (e.g. several [TextButton] choices whose order matters). Ghost actions
/// use neutral theme foreground (no error tint). Spacing between stacked rows
/// matches [AthlosSpacing.xs]; inset above the stack uses
/// [AthlosSpacing.dialogBodyToActions] so body copy does not need extra
/// [SizedBox] before this widget.
final class AthlosStackedDialogActions extends StatelessWidget {
  const AthlosStackedDialogActions({
    super.key,
    required this.children,
    this.invertStackOrder = true,
  });

  final List<Widget> children;

  /// Mirrors [children] for layout so callers keep writing `[secondary, primary]`.
  final bool invertStackOrder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AthlosSpacing.dialogBodyToActions),
      child: AthlosStackedActions(
        invertStackOrder: invertStackOrder,
        children: children,
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

  static const WidgetStatePropertyAll<EdgeInsetsGeometry> _dialogPadding =
      WidgetStatePropertyAll<EdgeInsetsGeometry>(AthlosButtonInsets.dialog);

  /// Prefer [copyWith] over [merge]: [merge] preserves the base style's fields
  /// when non-null, so dialog theme defaults (e.g. [minimumSize] width 64)
  /// would block full-width stacking and fixes from [AthlosDialogButtonTheme].
  ///
  /// Always set [ButtonStyle.padding] to [AthlosButtonInsets.dialog] here: the
  /// button resolver reads [widget.style.padding] first; if it were null, the
  /// icon button path would fall through to M3 default padding and changing
  /// [AthlosButtonInsets.dialog] alone would appear to have no effect.
  static ButtonStyle stackedGhost(BuildContext context) =>
      (Theme.of(context).textButtonTheme.style ?? const ButtonStyle()).copyWith(
        alignment: Alignment.center,
        minimumSize: _stackedMinSize,
        padding: _dialogPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static ButtonStyle stackedFilled(BuildContext context) =>
      (Theme.of(context).filledButtonTheme.style ?? const ButtonStyle())
          .copyWith(
        alignment: Alignment.center,
        minimumSize: _stackedMinSize,
        padding: _dialogPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
