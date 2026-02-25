import 'package:flutter/material.dart';

/// Custom semantic colors not covered by Material 3 [ColorScheme].
class AthlosCustomColors extends ThemeExtension<AthlosCustomColors> {
  final Color warning;
  final Color onWarning;

  const AthlosCustomColors({
    required this.warning,
    required this.onWarning,
  });

  static const light = AthlosCustomColors(
    warning: Color(0xFFE8A317),
    onWarning: Color(0xFF442B00),
  );

  static const dark = AthlosCustomColors(
    warning: Color(0xFFE8A317),
    onWarning: Color(0xFF442B00),
  );

  @override
  AthlosCustomColors copyWith({Color? warning, Color? onWarning}) =>
      AthlosCustomColors(
        warning: warning ?? this.warning,
        onWarning: onWarning ?? this.onWarning,
      );

  @override
  AthlosCustomColors lerp(AthlosCustomColors? other, double t) {
    if (other is! AthlosCustomColors) return this;
    return AthlosCustomColors(
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
