import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/equipment.dart';
import '../helpers/equipment_l10n.dart';
import '../providers/equipment_notifier.dart';

/// Shows a dialog warning that the exercise requires equipment not in the
/// user's list. Confirming automatically adds the missing equipment.
///
/// Returns `true` if the user confirmed (equipment was added), `false`/`null`
/// if cancelled.
Future<bool?> showEquipmentWarningDialog(
  BuildContext context, {
  required List<Equipment> missingEquipment,
}) =>
    showDialog<bool>(
      context: context,
      builder: (context) =>
          _EquipmentWarningDialog(missingEquipment: missingEquipment),
    );

class _EquipmentWarningDialog extends ConsumerWidget {
  final List<Equipment> missingEquipment;

  const _EquipmentWarningDialog({required this.missingEquipment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final names = missingEquipment
        .map((e) => localizedEquipmentName(
              e.name,
              isVerified: e.isVerified,
              l10n: l10n,
            ))
        .toList();

    return AlertDialog(
      title: Text(l10n.equipmentWarningTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.equipmentWarningMessage),
          const SizedBox(height: AthlosSpacing.sm),
          ...names.map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: colorScheme.error),
                  const SizedBox(width: AthlosSpacing.sm),
                  Flexible(child: Text(name)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AthlosSpacing.sm),
          Text(
            l10n.equipmentWarningAutoAdd,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              final notifier = ref.read(userEquipmentIdsProvider.notifier);
              await notifier.addAll(missingEquipment.map((e) => e.id));
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            } on Exception catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.genericError)),
                );
                Navigator.pop(context, false);
              }
            }
          },
          icon: const Icon(Icons.check),
          label: Text(l10n.confirmAndAdd),
        ),
      ],
    );
  }
}
