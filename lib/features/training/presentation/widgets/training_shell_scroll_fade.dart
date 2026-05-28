import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// Softens content disappearing under the training shell app bar while scrolling.
///
/// Fade sits at the top of the body (below the app bar) and only appears once the
/// active tab has scrolled (`pixels > 0`).
class TrainingShellScrollFade extends StatefulWidget {
  const TrainingShellScrollFade({required this.child, super.key});

  final Widget child;

  @override
  State<TrainingShellScrollFade> createState() => _TrainingShellScrollFadeState();
}

class _TrainingShellScrollFadeState extends State<TrainingShellScrollFade> {
  static const _fadeScrollThreshold = 1.0;

  bool _showTopFade = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final shouldShow = notification.metrics.pixels > _fadeScrollThreshold;
    if (shouldShow == _showTopFade) return false;
    setState(() => _showTopFade = shouldShow);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AthlosSpacing.xl,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showTopFade ? 1 : 0,
              duration: AthlosDurations.fast,
              curve: Curves.easeOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      surface,
                      surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
