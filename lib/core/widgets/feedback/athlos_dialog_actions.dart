import 'package:flutter/material.dart';

import '../../theme/athlos_button_insets.dart';
import '../../theme/athlos_button_sizes.dart';
import '../layout/athlos_stacked_actions.dart';

/// One action widget per row, full width — pass in [AlertDialog.actions].
/// Vertical separation from [AlertDialog.content] comes from the Material
/// dialog layout; no extra top gap is applied here.
///
/// Declares actions **top → bottom**. Prefer destructive or low-commitment
/// actions **first**, [FilledButton] primary / safe action **last** (Material
/// pattern: thumb reach for confirmation).
///
/// Set [invertStackOrder] to true only when actions are peers listed in logical
/// order that must render bottom-up. Ghost actions use neutral theme foreground
/// (no error tint). Spacing between stacked rows matches [AthlosSpacing.xs].
final class AthlosStackedDialogActions extends StatelessWidget {
  const AthlosStackedDialogActions({
    super.key,
    required this.children,
    this.invertStackOrder = false,
  });

  final List<Widget> children;

  /// When true, shows [children] in reverse vertical order.
  final bool invertStackOrder;

  @override
  Widget build(BuildContext context) {
    return AthlosStackedActions(
      invertStackOrder: invertStackOrder,
      children: children,
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

  static const WidgetStatePropertyAll<EdgeInsetsGeometry> _padding =
      WidgetStatePropertyAll<EdgeInsetsGeometry>(AthlosButtonInsets.screen);

  /// Prefer [copyWith] over [merge]: [merge] preserves the base style's fields
  /// when non-null, so dialog theme defaults (e.g. [minimumSize] width 64)
  /// would block full-width stacking and fixes from [AthlosDialogButtonTheme].
  ///
  /// Always set [ButtonStyle.padding] to [AthlosButtonInsets.screen] here: the
  /// button resolver reads [widget.style.padding] first; if it were null, the
  /// icon button path would fall through to M3 default padding and changing
  /// [AthlosButtonInsets.screen] alone would appear to have no effect.
  static ButtonStyle stackedGhost(BuildContext context) =>
      (Theme.of(context).textButtonTheme.style ?? const ButtonStyle()).copyWith(
        alignment: Alignment.center,
        minimumSize: _stackedMinSize,
        padding: _padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  static ButtonStyle stackedFilled(BuildContext context) =>
      (Theme.of(context).filledButtonTheme.style ?? const ButtonStyle())
          .copyWith(
        alignment: Alignment.center,
        minimumSize: _stackedMinSize,
        padding: _padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
