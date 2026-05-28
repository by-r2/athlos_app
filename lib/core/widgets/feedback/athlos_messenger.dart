import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../theme/athlos_custom_colors.dart';
import '../../theme/athlos_durations.dart';
import '../../theme/athlos_elevation.dart';
import '../../theme/athlos_radius.dart';
import '../../theme/athlos_spacing.dart';

/// Semantic tone for transient [AthlosMessenger] feedback.
enum AthlosSnackTone {
  info,
  success,
  error,
  warning,
}

/// Top-aligned, themed transient messages (replaces default bottom [SnackBar]s).
///
/// Floating at the top avoids clashing with the training bottom bar and FAB.
abstract final class AthlosMessenger {
  AthlosMessenger._();

  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  /// Shows a single message; replaces any message already visible.
  static void show(
    BuildContext context, {
    required String message,
    AthlosSnackTone tone = AthlosSnackTone.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (message.isEmpty) return;

    _hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (overlayContext) => _AthlosSnackOverlay(
        message: message,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: _hide,
      ),
    );

    overlay.insert(_entry!);
    _dismissTimer = Timer(duration ?? _defaultDuration(tone), _hide);
  }

  static void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }

  static Duration _defaultDuration(AthlosSnackTone tone) => switch (tone) {
    AthlosSnackTone.error => const Duration(seconds: 5),
    AthlosSnackTone.warning => const Duration(seconds: 4),
    AthlosSnackTone.success || AthlosSnackTone.info => const Duration(seconds: 3),
  };
}

extension AthlosMessengerContext on BuildContext {
  void showAthlosSnack(
    String message, {
    AthlosSnackTone tone = AthlosSnackTone.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AthlosMessenger.show(
      this,
      message: message,
      tone: tone,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void showAthlosErrorSnack(String message) =>
      showAthlosSnack(message, tone: AthlosSnackTone.error);

  void showAthlosSuccessSnack(String message) =>
      showAthlosSnack(message, tone: AthlosSnackTone.success);

  void showAthlosWarningSnack(String message) =>
      showAthlosSnack(message, tone: AthlosSnackTone.warning);
}

class _AthlosSnackOverlay extends StatefulWidget {
  const _AthlosSnackOverlay({
    required this.message,
    required this.tone,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AthlosSnackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  State<_AthlosSnackOverlay> createState() => _AthlosSnackOverlayState();
}

class _AthlosSnackOverlayState extends State<_AthlosSnackOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AthlosDurations.normal,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>();
    final style = _resolveStyle(colorScheme, customColors, widget.tone);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              0,
            ),
            child: Material(
              elevation: AthlosElevation.md,
              shadowColor: Colors.black.withValues(alpha: 0.28),
              color: style.background,
              shape: RoundedRectangleBorder(
                borderRadius: AthlosRadius.mdAll,
                side: BorderSide(color: style.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.smd,
                  vertical: AthlosSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.tone.icon, size: 22, color: style.icon),
                    const Gap(AthlosSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: textTheme.bodyMedium?.copyWith(
                          color: style.foreground,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const Gap(AthlosSpacing.xs),
                      TextButton(
                        onPressed: () {
                          widget.onAction!();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: style.icon,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AthlosSpacing.sm,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(widget.actionLabel!),
                      ),
                    ],
                    IconButton(
                      onPressed: _dismiss,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: style.foreground.withValues(alpha: 0.7),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static ({Color background, Color border, Color foreground, Color icon})
  _resolveStyle(
    ColorScheme colorScheme,
    AthlosCustomColors? customColors,
    AthlosSnackTone tone,
  ) {
    switch (tone) {
      case AthlosSnackTone.success:
        return (
          background: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surfaceContainerHigh,
          ),
          border: colorScheme.primary.withValues(alpha: 0.35),
          foreground: colorScheme.onSurface,
          icon: colorScheme.primary,
        );
      case AthlosSnackTone.error:
        return (
          background: colorScheme.errorContainer.withValues(alpha: 0.85),
          border: colorScheme.error.withValues(alpha: 0.4),
          foreground: colorScheme.onErrorContainer,
          icon: colorScheme.error,
        );
      case AthlosSnackTone.warning:
        final warning = customColors?.warning ?? colorScheme.tertiary;
        return (
          background: Color.alphaBlend(
            warning.withValues(alpha: 0.14),
            colorScheme.surfaceContainerHigh,
          ),
          border: warning.withValues(alpha: 0.45),
          foreground: colorScheme.onSurface,
          icon: warning,
        );
      case AthlosSnackTone.info:
        return (
          background: colorScheme.surfaceContainerHigh,
          border: colorScheme.outlineVariant,
          foreground: colorScheme.onSurface,
          icon: colorScheme.onSurfaceVariant,
        );
    }
  }
}

extension on AthlosSnackTone {
  IconData get icon => switch (this) {
    AthlosSnackTone.success => Icons.check_circle_outline,
    AthlosSnackTone.error => Icons.error_outline,
    AthlosSnackTone.warning => Icons.warning_amber_rounded,
    AthlosSnackTone.info => Icons.info_outline,
  };
}
