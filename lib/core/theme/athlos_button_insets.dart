import 'package:flutter/material.dart';

import 'athlos_spacing.dart';

/// Default padding on [FilledButton], [OutlinedButton], [TextButton], etc.
/// ([AthlosTheme] and dialogs via [AthlosDialogButtonTheme]).
abstract final class AthlosButtonInsets {
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: AthlosSpacing.xl,
    vertical: AthlosSpacing.md,
  );
}
