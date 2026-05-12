import 'package:flutter/material.dart';

import 'athlos_button_insets.dart';
import 'athlos_button_sizes.dart';

/// Full-width [TextButton] patterns on **screens**. Dialogs use
/// [AthlosDialogButtonStyles] (different min height / tap target trade-offs).
abstract final class AthlosScreenButtonStyles {
  AthlosScreenButtonStyles._();

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
