import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom typography for Athlos.
/// Cinzel only on [AppBar] titles; Inter everywhere else.
class AthlosTextTheme {
  AthlosTextTheme._();

  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.inter(fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.inter(fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.inter(fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w500),
    bodyLarge: GoogleFonts.inter(),
    bodyMedium: GoogleFonts.inter(),
    bodySmall: GoogleFonts.inter(),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.inter(),
  );

  /// App bar titles — sole Cinzel usage in the app chrome.
  static TextStyle appBarTitle(ColorScheme colorScheme) => GoogleFonts.cinzel(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: colorScheme.onSurface,
  );
}
