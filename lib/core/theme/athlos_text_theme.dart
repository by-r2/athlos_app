import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom typography for Athlos.
/// Cinzel for display/headline (Greek-inspired serif),
/// Inter for body/label (clean and readable).
class AthlosTextTheme {
  AthlosTextTheme._();

  static TextTheme get textTheme => TextTheme(
    displayLarge: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
    displayMedium: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
    displaySmall: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
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
}
