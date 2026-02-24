import 'package:flutter/material.dart';

/// Greek mythology-inspired color palette.
/// Tyrian purple primary with gold accents — the colors of Olympus.
class AthlosColorScheme {
  AthlosColorScheme._();

  // Primary — Deep royal purple, cool-toned (blue-leaning, not pink)
  static const _primaryPurple = Color(0xFF6B2FA0);

  // Accent — Gold for secondary details (badges, highlights, icons)
  static const _accentGold = Color(0xFFD4A843);
  static const _tertiaryGold = Color(0xFFE8C86A);

  // Surfaces
  static const _lightBase = Color(0xFFF5F5F5);
  static const _darkBase = Color(0xFF010101);

  static final light = ColorScheme.fromSeed(
    seedColor: _primaryPurple,
    brightness: Brightness.light,
    primary: _primaryPurple,
    onPrimary: Colors.white,
    secondary: _accentGold,
    tertiary: _tertiaryGold,
    surface: _lightBase,
    surfaceDim: const Color(0xFFEEEEEE),
    surfaceBright: Colors.white,
    surfaceContainerLowest: const Color(0xFFFAFAFA),
    surfaceContainerLow: const Color(0xFFFCFCFC),
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: Colors.white,
  );

  static final dark = ColorScheme.fromSeed(
    seedColor: _primaryPurple,
    brightness: Brightness.dark,
    primary: _primaryPurple,
    onPrimary: Colors.white,
    secondary: _accentGold,
    tertiary: _tertiaryGold,
    surface: _darkBase,
    surfaceDim: _darkBase,
    surfaceBright: const Color(0xFF1A1A1A),
    surfaceContainerLowest: _darkBase,
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF121212),
    surfaceContainerHigh: const Color(0xFF1A1A1A),
    surfaceContainerHighest: const Color(0xFF222222),
  );
}
