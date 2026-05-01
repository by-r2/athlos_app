import 'package:flutter/material.dart';

import 'athlos_button_insets.dart';
import 'athlos_button_sizes.dart';

/// Athlos dialogs stack actions in [AlertDialog.content] via
/// [AthlosStackedDialogActions] (`core/widgets/feedback/athlos_dialog_actions.dart`):
/// **one row per button**, ghost (secondary/dismiss) on **top**, [FilledButton] primary on
/// **bottom**. Prefer [AthlosDialogButtonStyles.stackedGhost] /
/// [AthlosDialogButtonStyles.stackedFilled] for full-width minimum height.
/// Inset above the buttons uses [AthlosSpacing.dialogBodyToActions].
///
/// Applies [AthlosButtonInsets.dialog] and tighter [AthlosButtonSizes.dialogMinHeight]
/// while keeping [MaterialTapTargetSize.padded] for touch targets.
final class AthlosDialogButtonTheme {
  AthlosDialogButtonTheme._();

  static Widget wrap(BuildContext context, Widget child) {
    return Theme(
      data: _withDialogButtonInsets(Theme.of(context)),
      child: child,
    );
  }

  static ThemeData _withDialogButtonInsets(ThemeData base) {
    const pad = WidgetStatePropertyAll<EdgeInsetsGeometry>(
      AthlosButtonInsets.dialog,
    );
    const minSz = WidgetStatePropertyAll<Size>(
      Size(AthlosButtonSizes.minWidth, AthlosButtonSizes.dialogMinHeight),
    );
    ButtonStyle merge(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          padding: pad,
          minimumSize: minSz,
          tapTargetSize: MaterialTapTargetSize.padded,
        );

    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: merge(base.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: merge(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: merge(base.textButtonTheme.style),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: merge(base.elevatedButtonTheme.style),
      ),
    );
  }
}

/// Like [showDialog], but action buttons use [AthlosButtonInsets.dialog].
Future<T?> showAthlosDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    fullscreenDialog: fullscreenDialog,
    requestFocus: requestFocus,
    animationStyle: animationStyle,
    builder: (BuildContext dialogContext) {
      return AthlosDialogButtonTheme.wrap(
        dialogContext,
        builder(dialogContext),
      );
    },
  );
}
