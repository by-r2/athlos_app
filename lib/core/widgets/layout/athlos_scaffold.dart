import 'package:flutter/material.dart';

import 'athlos_scroll_top_fade.dart';

/// [Scaffold] that applies [AthlosScrollTopFade] when an [appBar] is present.
class AthlosScaffold extends StatelessWidget {
  const AthlosScaffold({
    required this.body,
    super.key,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.scrollFadeKey,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  /// Resets scroll-fade state when this identity changes (e.g. tab index).
  final Object? scrollFadeKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBody,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: appBar != null
          ? AthlosScrollTopFade(
              key: scrollFadeKey != null ? ValueKey(scrollFadeKey) : null,
              child: body,
            )
          : body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
