import 'package:flutter/material.dart';

import 'athlos_spacing.dart';

/// Minimum button dimensions aligned with accessibility norms.
///
/// Material / Flutter exposes [kMinInteractiveDimension] (48 dp) as the
/// default minimum **touch target** height. Buttons can use a visually shorter
/// **layout** minimum (e.g. 32 dp in dialogs) when [MaterialTapTargetSize.padded]
/// is kept so expanded hit-testing still honours the gesture target baseline.
///
/// Dialog layout height stays below 48 dp visually; pairing with
/// [AthlosButtonInsets.dialog] keeps stacked actions compact.
abstract final class AthlosButtonSizes {
  /// Typical minimum width for compact M3 buttons.
  static const double minWidth = AthlosSpacing.xxl + AthlosSpacing.md;

  /// Full-app buttons ([AthlosTheme]): height matches common touch-guideline baselines.
  static const double screenMinHeight = kMinInteractiveDimension;

  /// Modal actions: tighter layout height while theme keeps padded tap targets.
  static const double dialogMinHeight = AthlosSpacing.xl; // 32
}
