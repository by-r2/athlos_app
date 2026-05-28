import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/athlos_assets.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/theme/athlos_text_theme.dart';

/// Overlap between the hero gradient and the content sheet.
const _sheetOverlap = 20.0;

/// Top corner radius of the floating content sheet.
const _sheetTopRadius = 24.0;

/// Harmonized hero proportions per auth screen type.
class AthlosAuthHeroPreset {
  const AthlosAuthHeroPreset({
    required this.heightFactor,
    required this.symbolSize,
  });

  /// Welcome: brand mark + ATHLOS + tagline.
  static const welcome = AthlosAuthHeroPreset(
    heightFactor: 0.42,
    symbolSize: 112,
  );

  /// Sign-in / sign-up header with screen title.
  static const flow = AthlosAuthHeroPreset(
    heightFactor: 0.34,
    symbolSize: 96,
  );

  /// Chat-style sign-up with input at the bottom.
  static const chat = AthlosAuthHeroPreset(
    heightFactor: 0.31,
    symbolSize: 88,
  );

  final double heightFactor;
  final double symbolSize;
}

class AthlosAuthScaffold extends StatelessWidget {
  const AthlosAuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.tagline,
    this.brandTitle = false,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
    this.preset = AthlosAuthHeroPreset.welcome,
    this.heroHeightFactor,
    this.symbolSize,
    this.panelPadding = const EdgeInsets.fromLTRB(
      AthlosSpacing.lg,
      AthlosSpacing.xl,
      AthlosSpacing.lg,
      AthlosSpacing.lg,
    ),
  }) : assert(
         (subtitle != null) || (tagline != null),
         'Provide subtitle or tagline',
       );

  final String title;
  final String? subtitle;
  final String? tagline;
  final bool brandTitle;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final AthlosAuthHeroPreset preset;
  final double? heroHeightFactor;
  final double? symbolSize;
  final EdgeInsetsGeometry panelPadding;

  double get _resolvedHeroHeightFactor =>
      heroHeightFactor ?? preset.heightFactor;

  double get _resolvedSymbolSize => symbolSize ?? preset.symbolSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final heroGradientEnd = Color.lerp(
      colorScheme.primary,
      Colors.black,
      colorScheme.brightness == Brightness.light ? 0.28 : 0.18,
    )!;
    final heroHeight =
        MediaQuery.sizeOf(context).height * _resolvedHeroHeightFactor;
    final resolvedSymbolSize = _resolvedSymbolSize;
    final sheetShadow = colorScheme.brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.32);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, heroGradientEnd],
                ),
              ),
            ),
          ),
          Positioned(
            top: heroHeight - _sheetOverlap,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_sheetTopRadius),
                ),
                boxShadow: [
                  BoxShadow(
                    color: sheetShadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Padding(
                padding: panelPadding,
                child: child,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight - _sheetOverlap,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  if (showBackButton)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        onPressed: onBackPressed,
                        icon: const Icon(Icons.arrow_back),
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AthlosSpacing.lg,
                        showBackButton ? AthlosSpacing.sm : 0,
                        AthlosSpacing.lg,
                        AthlosSpacing.md,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _AuthHeroBranding(
                          title: title,
                          tagline: tagline,
                          subtitle: subtitle,
                          brandTitle: brandTitle,
                          symbolSize: resolvedSymbolSize,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHeroBranding extends StatelessWidget {
  const _AuthHeroBranding({
    required this.title,
    required this.tagline,
    required this.subtitle,
    required this.brandTitle,
    required this.symbolSize,
    required this.colorScheme,
    required this.textTheme,
  });

  final String title;
  final String? tagline;
  final String? subtitle;
  final bool brandTitle;
  final double symbolSize;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final secondaryLine = tagline ?? subtitle;
    final titleGap = brandTitle ? AthlosSpacing.smd : AthlosSpacing.sm;
    final subtitleGap = brandTitle ? AthlosSpacing.xs : AthlosSpacing.sm;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          AthlosAssets.athlosSymbol,
          width: symbolSize,
          height: symbolSize,
        ),
        Gap(titleGap),
        Text(
          brandTitle ? title.toUpperCase() : title,
          style: _titleStyle,
          textAlign: TextAlign.center,
        ),
        if (secondaryLine != null) ...[
          Gap(subtitleGap),
          Text(
            secondaryLine,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  TextStyle? get _titleStyle {
    if (brandTitle) {
      return AthlosTextTheme.brandDisplay(
        colorScheme.onPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.8,
        height: 1.15,
      );
    }
    return textTheme.headlineSmall?.copyWith(
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }
}

class AthlosAuthOfflinePanel extends StatelessWidget {
  const AthlosAuthOfflinePanel({
    super.key,
    required this.message,
    this.actionLabel,
    this.onContinue,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: AthlosRadius.lgAll,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              color: colorScheme.primary,
              size: 32,
            ),
          ),
        ),
        const Gap(AthlosSpacing.lg),
        Text(
          message,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onContinue != null) ...[
          const Gap(AthlosSpacing.xl),
          FilledButton(onPressed: onContinue, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class AthlosAuthCheckingPanel extends StatelessWidget {
  const AthlosAuthCheckingPanel({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (message != null) ...[
            const Gap(AthlosSpacing.md),
            Text(
              message!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
