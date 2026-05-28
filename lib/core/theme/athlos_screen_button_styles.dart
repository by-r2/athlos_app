import 'package:flutter/material.dart';

import 'athlos_button_insets.dart';
import 'athlos_button_sizes.dart';

/// Full-width button patterns on **screens** and bottom sheets. Dialogs use
/// [AthlosDialogButtonStyles] (different min height / tap target trade-offs).
abstract final class AthlosScreenButtonStyles {
  AthlosScreenButtonStyles._();

  static const Size _stackedMinSize = Size(
    double.infinity,
    AthlosButtonSizes.screenMinHeight,
  );

  /// Full-width [FilledButton] — theme shape/radius/colors, screen min height.
  static ButtonStyle stackedFilled(BuildContext context) =>
      FilledButton.styleFrom(minimumSize: _stackedMinSize);

  /// Full-width [OutlinedButton] — theme shape/radius/colors, screen min height.
  static ButtonStyle stackedOutlined(BuildContext context) =>
      OutlinedButton.styleFrom(minimumSize: _stackedMinSize);

  /// Full-width [TextButton] — theme shape/radius/colors, screen min height.
  static ButtonStyle stackedGhost(BuildContext context) =>
      TextButton.styleFrom(minimumSize: _stackedMinSize);

  /// Theme ghost [TextButton] with [AthlosButtonInsets.screen] and screen
  /// minimum height (same stacking pattern as overview actions on execution).
  static ButtonStyle fullWidthText(BuildContext context) =>
      TextButton.styleFrom(
        padding: AthlosButtonInsets.screen,
        minimumSize: const Size(
          AthlosButtonSizes.minWidth,
          AthlosButtonSizes.screenMinHeight,
        ),
        tapTargetSize: MaterialTapTargetSize.padded,
      ).merge(Theme.of(context).textButtonTheme.style ?? const ButtonStyle());

  /// Like [fullWidthText], but forces muted foreground for secondary actions.
  static ButtonStyle fullWidthTextMuted(BuildContext context) =>
      (Theme.of(context).textButtonTheme.style ?? const ButtonStyle()).merge(
        TextButton.styleFrom(
          padding: AthlosButtonInsets.screen,
          minimumSize: const Size(
            AthlosButtonSizes.minWidth,
            AthlosButtonSizes.screenMinHeight,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}
