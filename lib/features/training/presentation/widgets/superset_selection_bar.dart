import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_elevation.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';

/// Floating cancel / confirm controls while picking superset members.
class SupersetSelectionBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const SupersetSelectionBar({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        elevation: AthlosElevation.md,
        borderRadius: AthlosRadius.fullAll,
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'superset-cancel',
                onPressed: onCancel,
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurface,
                child: const Icon(Icons.close),
              ),
              const SizedBox(width: AthlosSpacing.sm),
              FloatingActionButton.small(
                heroTag: 'superset-confirm',
                onPressed: onConfirm,
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
