import 'package:flutter/material.dart';

/// Decides whether the user may leave (e.g. pop route or sheet) after a guarded
/// back gesture or system back.
typedef ConfirmLeaveCallback = Future<bool> Function(BuildContext context);

/// Invoked after the user confirmed leaving while [guardActive] was true.
///
/// Use this when leaving does **not** map to [Navigator.pop] — for example
/// exiting inline edit mode on the same route ([ProfileScreen]).
typedef OnLeaveConfirmedCallback = void Function(BuildContext context);

/// Intercepts back navigation when [guardActive] is true.
///
/// Shows [onConfirmLeave]; when it returns `true`, calls [onLeaveConfirmed]
/// if provided, otherwise [Navigator.pop] on the current [Navigator].
///
/// Pair with helpers in [navigation_leave_dialogs.dart] for consistent copy.
class ConfirmNavigationScope extends StatelessWidget {
  const ConfirmNavigationScope({
    super.key,
    required this.guardActive,
    required this.onConfirmLeave,
    required this.child,
    this.onLeaveConfirmed,
  });

  /// When true, pop attempts are blocked until the user confirms.
  final bool guardActive;

  /// Async confirmation (dialog). Must return `true` only if leaving is OK.
  final ConfirmLeaveCallback onConfirmLeave;

  /// Called after a successful confirmation. Defaults to [Navigator.pop].
  final OnLeaveConfirmedCallback? onLeaveConfirmed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !guardActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onConfirmLeave(context).then((confirmed) {
          if (!confirmed || !context.mounted) return;
          if (onLeaveConfirmed != null) {
            onLeaveConfirmed!(context);
          } else {
            Navigator.of(context).pop(result);
          }
        });
      },
      child: child,
    );
  }
}
