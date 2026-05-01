import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/athlos_durations.dart';

/// Shared [CustomTransitionPage] helpers for go_router routes.
abstract final class AthlosRouterPages {
  /// Material Motion **fade-through** for peer swaps (e.g. training bottom-nav
  /// roots): outgoing fades out, incoming fades in with a slight scale-in.
  static CustomTransitionPage<void> fadeThroughBottomNavPeers(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      name: state.name ?? state.path,
      arguments: <String, String>{
        ...state.pathParameters,
        ...state.uri.queryParameters,
      },
      restorationId: state.pageKey.value,
      transitionDuration: AthlosDurations.normal,
      reverseTransitionDuration: AthlosDurations.normal,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: Theme.of(context).colorScheme.surface,
            child: child,
          ),
    );
  }
}
