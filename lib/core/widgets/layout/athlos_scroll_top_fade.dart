import 'package:flutter/material.dart';

import '../../theme/athlos_durations.dart';
import '../../theme/athlos_spacing.dart';

/// Softens content disappearing under an app bar while scrolling.
///
/// Place at the top of [Scaffold.body] (or wrap the body). The fade only appears
/// once a descendant scrollable has moved (`pixels > 0`). When the scroll view
/// does not start at the top of [child] (e.g. a fixed search bar above a list),
/// the fade aligns to that scroll view's top edge.
///
/// Prefer the deepest [ScrollNotification] so parent scrollables do not steal
/// the overlay. Pair with a stable [Key] (route URI, tab index, etc.) when the
/// wrapper survives navigation so fade state resets per screen.
class AthlosScrollTopFade extends StatefulWidget {
  const AthlosScrollTopFade({
    required this.child,
    super.key,
    this.fadeExtent = AthlosSpacing.xl,
    this.backgroundColor,
  });

  final Widget child;
  final double fadeExtent;
  final Color? backgroundColor;

  @override
  State<AthlosScrollTopFade> createState() => _AthlosScrollTopFadeState();
}

class _AthlosScrollTopFadeState extends State<AthlosScrollTopFade> {
  static const _fadeScrollThreshold = 1.0;

  bool _showTopFade = false;
  double _fadeTop = 0;
  int _activeScrollDepth = 0;

  void _syncFade(ScrollNotification notification) {
    final scrolled = notification.metrics.pixels > _fadeScrollThreshold;
    final depth = notification.depth;

    if (!scrolled) {
      if (_showTopFade && depth >= _activeScrollDepth) {
        setState(() {
          _showTopFade = false;
          _activeScrollDepth = 0;
        });
      }
      return;
    }

    // A nested list scrolled; ignore shallower ancestors still reporting offset.
    if (_showTopFade && depth < _activeScrollDepth) {
      return;
    }

    final fadeTop = _measureFadeTop(notification.context);
    if (fadeTop == null) return;

    if (!_showTopFade ||
        depth >= _activeScrollDepth ||
        (_fadeTop - fadeTop).abs() >= 0.5) {
      setState(() {
        _showTopFade = true;
        _activeScrollDepth = depth;
        _fadeTop = fadeTop;
      });
    }
  }

  /// Top offset of the scroll view within this overlay, or null if not ready.
  double? _measureFadeTop(BuildContext? scrollContext) {
    if (scrollContext == null) return null;

    final scrollBox = scrollContext.findRenderObject() as RenderBox?;
    final stackBox = context.findRenderObject() as RenderBox?;
    if (scrollBox == null ||
        stackBox == null ||
        !scrollBox.hasSize ||
        !stackBox.hasSize) {
      return null;
    }

    final offset = scrollBox.localToGlobal(Offset.zero, ancestor: stackBox);
    return offset.dy.clamp(0.0, stackBox.size.height);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    _syncFade(notification);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        widget.backgroundColor ?? Theme.of(context).colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: _fadeTop,
          left: 0,
          right: 0,
          height: widget.fadeExtent,
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
