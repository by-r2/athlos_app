import 'package:flutter/material.dart';

import 'athlos_color_scheme.dart';
import 'athlos_custom_colors.dart';
import 'athlos_elevation.dart';
import 'athlos_radius.dart';
import 'athlos_text_theme.dart';

/// Main ThemeData factory for Athlos.
class AthlosTheme {
  AthlosTheme._();

  static ThemeData get light =>
      _buildTheme(AthlosColorScheme.light, AthlosCustomColors.light);
  static ThemeData get dark =>
      _buildTheme(AthlosColorScheme.dark, AthlosCustomColors.dark);

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    AthlosCustomColors customColors,
  ) =>
      ThemeData(
        extensions: [customColors],
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: AthlosTextTheme.textTheme,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: AthlosElevation.none,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        navigationBarTheme: NavigationBarThemeData(
          height: 64,
          elevation: AthlosElevation.none,
          backgroundColor: colorScheme.surfaceContainer,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: AthlosRadius.lgAll,
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: colorScheme.primary, size: 24);
            }
            return IconThemeData(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              size: 24,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              );
            }
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            );
          }),
          overlayColor: WidgetStatePropertyAll(
            colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
      );
}
