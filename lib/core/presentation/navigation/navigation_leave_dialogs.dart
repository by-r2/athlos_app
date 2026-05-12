import 'package:flutter/material.dart';

import '../../theme/athlos_dialog.dart';
import '../../widgets/feedback/athlos_dialog_actions.dart';
import '../../../l10n/app_localizations.dart';

/// Form or profile draft: unsaved edits will be lost.
Future<bool> confirmDiscardUnsavedEdits(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showAthlosDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.navigateAwayUnsavedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(l10n.navigateAwayUnsavedMessage)],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.navigateAwayDiscardAction),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(ctx),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.navigateAwayKeepEditingAction),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Chiron sheet: streaming, draft input, or an active conversation.
Future<bool> confirmLeaveChironAssistant(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showAthlosDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.navigateAwayChironTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(l10n.navigateAwayChironMessage)],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(ctx),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.navigateAwayChironLeaveAction),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(ctx),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.navigateAwayChironStayAction),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
