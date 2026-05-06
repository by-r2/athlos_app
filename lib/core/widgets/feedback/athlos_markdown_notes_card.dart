import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/athlos_dialog.dart';
import 'athlos_dialog_actions.dart';

/// Reusable card that opens markdown notes in a dialog.
class AthlosMarkdownNotesCard extends StatelessWidget {
  final String title;
  final String markdown;

  const AthlosMarkdownNotesCard({
    super.key,
    required this.title,
    required this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        onTap: () => _showNotesDialog(context),
        leading: Icon(Icons.sticky_note_2_outlined, color: colorScheme.primary),
        title: Text(title, style: textTheme.titleSmall),
        subtitle: Text(
          AppLocalizations.of(context)!.tapToOpen,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  void _showNotesDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: markdown,
              styleSheet: MarkdownStyleSheet(
                p: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                listBullet: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
