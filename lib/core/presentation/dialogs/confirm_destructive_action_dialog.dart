import 'package:flutter/material.dart';

import '../../theme/athlos_dialog.dart';
import '../../widgets/feedback/athlos_dialog_actions.dart';
import '../../../l10n/app_localizations.dart';

/// Confirms a destructive or irreversible action before proceeding.
///
/// Actions are stacked per [AthlosStackedDialogActions]: destructive confirm
/// ([TextButton]) first, safe cancel ([FilledButton]) last.
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showAthlosDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(message)],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(ctx),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
