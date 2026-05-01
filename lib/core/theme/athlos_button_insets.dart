import 'package:flutter/material.dart';

import 'athlos_spacing.dart';

/// Default padding on [FilledButton], [OutlinedButton], [TextButton],
/// etc. outside modal dialogs ([AthlosTheme]).
abstract final class AthlosButtonInsets {
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: AthlosSpacing.md,
    vertical: AthlosSpacing.md,
  );

  /// Tighter padding for buttons shown inside dialogs ([showAthlosDialog]).
  static const EdgeInsets dialog = EdgeInsets.symmetric(
    horizontal: AthlosSpacing.sm,
    vertical: AthlosSpacing.xs,
  );
}
