import 'package:flutter/material.dart';

import 'athlos_radius.dart';
import 'athlos_spacing.dart';

/// Semantic bottom-sheet surfaces — elevated above [ColorScheme.surface] scaffold.
extension AthlosBottomSheetColors on ColorScheme {
  /// Light: [surfaceBright] (white) on gray scaffold.
  /// Dark: [surfaceBright] (#2A2A2A) on near-black scaffold.
  Color get bottomSheet => surfaceBright;

  /// Cards / tappable rows on [bottomSheet] — must contrast with [bottomSheet],
  /// not with [surface] (e.g. [surfaceContainerHigh] blends on [surfaceBright]).
  Color get bottomSheetContainer => brightness == Brightness.light
      ? surfaceContainerLow
      : surfaceContainer;
}

/// Drag handle rendered **inside** [AthlosBottomSheetShell] so the top band uses
/// [ColorScheme.bottomSheet], not the transparent modal route background.
class AthlosBottomSheetDragHandle extends StatelessWidget {
  const AthlosBottomSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        top: AthlosSpacing.md,
        bottom: AthlosSpacing.sm,
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Rounded [Material] shell for modal bottom sheet content.
///
/// Use inside [DraggableScrollableSheet] builders when the modal route uses a
/// transparent background (see [showAthlosModalBottomSheet]).
class AthlosBottomSheetShell extends StatelessWidget {
  const AthlosBottomSheetShell({
    super.key,
    required this.child,
    this.showDragHandle = true,
    this.expand = false,
  });

  final Widget child;

  /// When true, draws [AthlosBottomSheetDragHandle] on the sheet surface.
  final bool showDragHandle;

  /// Set true when [child] contains [Expanded] (e.g. [DraggableScrollableSheet]).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AthlosRadius.lg),
      ),
      child: Material(
        color: colorScheme.bottomSheet,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle) const AthlosBottomSheetDragHandle(),
            child,
          ],
        ),
      ),
    );
  }
}

/// Like [showModalBottomSheet], with Athlos surface color and shape.
///
/// The route background stays transparent so theme switches while the sheet is
/// open do not freeze the previous [ColorScheme.surface]. Content is wrapped in
/// [AthlosBottomSheetShell] unless [wrapInShell] is false (e.g. outer
/// [DraggableScrollableSheet] — put the shell inside its builder instead).
Future<T?> showAthlosModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  bool showDragHandle = true,
  bool wrapInShell = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    // Handle is drawn inside [AthlosBottomSheetShell], not on the transparent route.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      final child = builder(sheetContext);
      if (!wrapInShell) return child;
      return AthlosBottomSheetShell(
        showDragHandle: showDragHandle,
        child: child,
      );
    },
  );
}
