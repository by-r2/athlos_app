/// Spacing tokens for consistent padding, margins, and gaps.
///
/// Usage: `EdgeInsets.all(AthlosSpacing.md)` or `SizedBox(height: AthlosSpacing.sm)`
abstract class AthlosSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  /// Intermediate value between [sm] and [md] for compact layouts.
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Bottom padding to clear floating action buttons.
  static const double fabClearance = 80;
}
