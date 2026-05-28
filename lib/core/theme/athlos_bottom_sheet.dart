import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'athlos_radius.dart';
import 'athlos_spacing.dart';

/// Semantic bottom-sheet surfaces — elevated above [ColorScheme.surface] scaffold.
extension AthlosBottomSheetColors on ColorScheme {
  /// Light: white sheet on [#E0E0E0] scaffold.
  /// Dark: [#2A2A2A] sheet on near-black scaffold.
  Color get bottomSheet => surfaceBright;

  /// Nested blocks on [bottomSheet] — subtle contrast vs the sheet surface.
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

/// Title + optional subtitle for modal bottom sheets (filters, forms, lists).
class AthlosBottomSheetHeader extends StatelessWidget {
  const AthlosBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AthlosSpacing.md,
      AthlosSpacing.sm,
      AthlosSpacing.md,
      AthlosSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Trailing control on the title row (e.g. close).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final titleStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: colorScheme.primary),
                const Gap(AthlosSpacing.xs),
              ],
              Expanded(child: Text(title, style: titleStyle)),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const Gap(AthlosSpacing.xs),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Contrasting inset block on [ColorScheme.bottomSheet].
class AthlosBottomSheetContainer extends StatelessWidget {
  const AthlosBottomSheetContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.bottomSheetContainer,
      borderRadius: AthlosRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AthlosSpacing.smd,
          AthlosSpacing.md,
          AthlosSpacing.smd,
          AthlosSpacing.md,
        ),
        child: child,
      ),
    );
  }
}

/// Standard horizontal insets + safe-area / keyboard bottom for sheet bodies.
EdgeInsets athlosBottomSheetBodyPadding(BuildContext context) {
  return EdgeInsets.only(
    left: AthlosSpacing.md,
    right: AthlosSpacing.md,
    top: AthlosSpacing.sm,
    bottom:
        MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom +
        AthlosSpacing.md,
  );
}

/// Like [showModalBottomSheet], with Athlos surface color and shape.
///
/// The route background stays transparent so theme switches while the sheet is
/// open do not freeze the previous [ColorScheme.surface]. Content is wrapped in
/// [AthlosBottomSheetShell] unless [wrapInShell] is false (e.g. outer
/// [DraggableScrollableSheet] — put the shell inside its builder instead).
///
/// [useRootNavigator] defaults to true so sheets paint above module shells that
/// use [Scaffold.bottomNavigationBar] (e.g. training tabs).
Future<T?> showAthlosModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool useRootNavigator = true,
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
