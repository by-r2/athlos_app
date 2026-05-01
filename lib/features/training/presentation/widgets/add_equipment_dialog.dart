import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/equipment_category.dart';
import '../helpers/equipment_l10n.dart';
import '../providers/equipment_notifier.dart';

Future<int?> showAddEquipmentDialog(
  BuildContext context, {
  String initialName = '',
}) {
  return showAthlosDialog<int>(
    context: context,
    builder: (context) => _AddEquipmentDialog(
      initialName: initialName,
    ),
  );
}

/// Dialog to add a user-created equipment.
class _AddEquipmentDialog extends ConsumerStatefulWidget {
  final String initialName;

  const _AddEquipmentDialog({required this.initialName});

  @override
  ConsumerState<_AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends ConsumerState<_AddEquipmentDialog> {
  late final TextEditingController _nameController;
  EquipmentCategory _selectedCategory = EquipmentCategory.accessories;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.addEquipment),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.equipmentNameLabel,
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            enabled: !_isSaving,
          ),
          const Gap(AthlosSpacing.md),
          DropdownButtonFormField<EquipmentCategory>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(
              labelText: l10n.equipmentCategoryLabel,
            ),
            items: EquipmentCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(localizedCategoryName(category, l10n)),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
          ),
          const Gap(AthlosSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: AthlosSpacing.xs),
              Expanded(
                child: Text(
                  localizedCategoryDescription(_selectedCategory, l10n),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(context),
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(context),
                onPressed: _isSaving ? null : _onSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final id = await ref
          .read(equipmentListProvider.notifier)
          .addUserEquipmentAndReturnId(
            name: name,
            category: _selectedCategory,
          );

      if (mounted) {
        Navigator.of(context).pop(id);
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    }
  }
}
