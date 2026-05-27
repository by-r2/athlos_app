import 'package:flutter/material.dart';

import '../../theme/athlos_durations.dart';
import '../../theme/athlos_spacing.dart';

/// Chat list with solid top inset and a scroll-linked fade at the list top edge.
///
/// The fade only appears when [scrollController] has scrolled content above the
/// viewport (`offset > 0`), so the first messages are not dimmed at rest.
class AthlosChatScrollFade extends StatefulWidget {
  const AthlosChatScrollFade({
    super.key,
    required this.scrollController,
    required this.child,
    this.topSolidExtent = AthlosSpacing.xl,
    this.fadeExtent = AthlosSpacing.lg,
    this.backgroundColor,
  });

  final ScrollController scrollController;
  final Widget child;
  final double topSolidExtent;
  final double fadeExtent;
  final Color? backgroundColor;

  @override
  State<AthlosChatScrollFade> createState() => _AthlosChatScrollFadeState();
}

class _AthlosChatScrollFadeState extends State<AthlosChatScrollFade> {
  static const _fadeScrollThreshold = 1.0;

  bool _showTopFade = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_syncTopFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTopFade());
  }

  @override
  void didUpdateWidget(covariant AthlosChatScrollFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_syncTopFade);
      widget.scrollController.addListener(_syncTopFade);
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncTopFade());
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_syncTopFade);
    super.dispose();
  }

  void _syncTopFade() {
    if (!mounted) return;
    final controller = widget.scrollController;
    final shouldShow = controller.hasClients &&
        controller.offset > _fadeScrollThreshold;
    if (shouldShow == _showTopFade) return;
    setState(() => _showTopFade = shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.backgroundColor ?? Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.topSolidExtent),
        Expanded(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    _syncTopFade();
                  }
                  return false;
                },
                child: widget.child,
              ),
              Positioned(
                top: 0,
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
          ),
        ),
      ],
    );
  }
}
