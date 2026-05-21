import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/athlos_assets.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

class AthlosAuthScaffold extends StatelessWidget {
  const AthlosAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
    this.heroHeightFactor = 0.34,
    this.symbolSize = 124,
    this.panelPadding = const EdgeInsets.fromLTRB(
      AthlosSpacing.lg,
      AthlosSpacing.xl,
      AthlosSpacing.lg,
      AthlosSpacing.lg,
    ),
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double heroHeightFactor;
  final double symbolSize;
  final EdgeInsetsGeometry panelPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * heroHeightFactor,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AthlosSpacing.lg,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, AthlosSpacing.sm),
                                child: SvgPicture.asset(
                                  AthlosAssets.athlosSymbol,
                                  width: symbolSize,
                                  height: symbolSize,
                                ),
                              ),
                              const Gap(AthlosSpacing.xxs),
                              Text(
                                title,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Gap(AthlosSpacing.xs),
                              Text(
                                subtitle,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.84,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: panelPadding,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AthlosRadius.lg),
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
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
