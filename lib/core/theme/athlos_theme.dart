import 'package:flutter/material.dart';

import 'athlos_button_insets.dart';
import 'athlos_button_sizes.dart';
import 'athlos_color_scheme.dart';
import 'athlos_custom_colors.dart';
import 'athlos_elevation.dart';
import 'athlos_radius.dart';
import 'athlos_spacing.dart';
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
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;

    /// Dark mode: softer than plain [onSurface] body text so ghost/outline read
    /// as controls, not paragraphs.
    const darkFgAlpha = 0.78;
    const darkOutlineBorderAlpha = 0.42;
    final inputAccentColor = isDark
        ? colorScheme.secondary
        : colorScheme.primary;
    final inputBorderRadius = BorderRadius.circular(AthlosRadius.md);

    Color outlineGhostForeground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.38);
      }
      return isDark
          ? colorScheme.onSurface.withValues(alpha: darkFgAlpha)
          : colorScheme.primary;
    }

    Color outlineGhostBorder(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.38);
      }
      return isDark
          ? colorScheme.onSurface.withValues(alpha: darkOutlineBorderAlpha)
          : colorScheme.primary;
    }

    return ThemeData(
      extensions: [customColors],
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AthlosTextTheme.textTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: inputAccentColor,
        selectionColor: inputAccentColor.withValues(alpha: 0.24),
        selectionHandleColor: inputAccentColor,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: AthlosElevation.none,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceBright,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AthlosRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        // Lateral and bottom of the actions pane; content↔actions gap is Material.
        actionsPadding: const EdgeInsets.fromLTRB(
          AthlosSpacing.lg,
          0,
          AthlosSpacing.lg,
          AthlosSpacing.md,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.smd,
          vertical: AthlosSpacing.smd,
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: inputAccentColor,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.36),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: inputAccentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AthlosButtonInsets.screen,
          minimumSize: const Size(
            AthlosButtonSizes.minWidth,
            AthlosButtonSizes.screenMinHeight,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              padding: AthlosButtonInsets.screen,
              minimumSize: const Size(
                AthlosButtonSizes.minWidth,
                AthlosButtonSizes.screenMinHeight,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                outlineGhostForeground,
              ),
              side: WidgetStateProperty.resolveWith<BorderSide>((
                Set<WidgetState> states,
              ) {
                return BorderSide(color: outlineGhostBorder(states));
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              padding: AthlosButtonInsets.screen,
              minimumSize: const Size(
                AthlosButtonSizes.minWidth,
                AthlosButtonSizes.screenMinHeight,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                outlineGhostForeground,
              ),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: AthlosButtonInsets.screen,
          minimumSize: const Size(
            AthlosButtonSizes.minWidth,
            AthlosButtonSizes.screenMinHeight,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
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
}
