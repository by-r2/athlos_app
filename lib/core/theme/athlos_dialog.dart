import 'package:flutter/material.dart';

import 'athlos_button_insets.dart';
import 'athlos_button_sizes.dart';

/// Athlos dialogs pass [AthlosStackedDialogActions] in [AlertDialog.actions]
/// (`core/widgets/feedback/athlos_dialog_actions.dart`): **one row per button**;
/// default stack mirrors order so [FilledButton] primary is **on top** when
/// declared after ghost. Prefer [AthlosDialogButtonStyles.stackedGhost] /
/// [AthlosDialogButtonStyles.stackedFilled] for full-width minimum height.
/// [DialogThemeData.actionsPadding] provides lateral and bottom inset for the
/// actions region; separation from [AlertDialog.content] is from Material layout
/// ([AthlosTheme]).
///
/// Applies [AthlosButtonInsets.screen] and tighter [AthlosButtonSizes.dialogMinHeight].
///
/// Uses [MaterialTapTargetSize.shrinkWrap] so layout height can go below
/// [kMinInteractiveDimension]: [MaterialTapTargetSize.padded] would wrap buttons
/// in extra padding and visually lock rows to 48 dp regardless of [minimumSize].
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
      AthlosButtonInsets.screen,
    );
    const minSz = WidgetStatePropertyAll<Size>(
      Size(AthlosButtonSizes.minWidth, AthlosButtonSizes.dialogMinHeight),
    );
    ButtonStyle merge(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(
          padding: pad,
          minimumSize: minSz,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

    return base.copyWith(
      // Ensures M3 defaults (e.g. [TextButton.defaults] reading
      // [ThemeData.materialTapTargetSize]) resolve to shrinkWrap when a style
      // omits [ButtonStyle.tapTargetSize].
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Like [showDialog], but merges dialog-scoped button theme (same insets as
/// [AthlosButtonInsets.screen], tighter [AthlosButtonSizes.dialogMinHeight]).
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
