import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';

class AttributeMergeResult {
  final String winnerId;
  final Map<String, dynamic> mergedAttributes;

  const AttributeMergeResult({
    required this.winnerId,
    required this.mergedAttributes,
  });
}

Future<AttributeMergeResult?> showAttributeMergeDialog({
  required BuildContext context,
  required BackupConflictType entityType,
  required Map<String, dynamic> itemA,
  required Map<String, dynamic> itemB,
  required String idA,
  required String idB,
}) {
  return showAthlosModalBottomSheet<AttributeMergeResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AttributeMergeSheet(
      entityType: entityType,
      itemA: itemA,
      itemB: itemB,
      idA: idA,
      idB: idB,
    ),
  );
}

class _AttributeMergeSheet extends StatefulWidget {
  final BackupConflictType entityType;
  final Map<String, dynamic> itemA;
  final Map<String, dynamic> itemB;
  final String idA;
  final String idB;

  const _AttributeMergeSheet({
    required this.entityType,
    required this.itemA,
    required this.itemB,
    required this.idA,
    required this.idB,
  });

  @override
  State<_AttributeMergeSheet> createState() => _AttributeMergeSheetState();
}

class _AttributeMergeSheetState extends State<_AttributeMergeSheet> {
  final Map<String, _Side> _selections = {};

  List<_MergeField> get _fields {
    final l10n = AppLocalizations.of(context)!;
    return [
      _MergeField('name', l10n.conflictCenterMergeFieldName),
      _MergeField('muscle_group', l10n.conflictCenterMergeFieldMuscleGroup),
      _MergeField('type', l10n.conflictCenterMergeFieldType),
      _MergeField(
        'movement_pattern',
        l10n.conflictCenterMergeFieldMovementPattern,
      ),
      _MergeField('description', l10n.conflictCenterMergeFieldDescription),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final field in _fields) {
        _selections[field.key] = _Side.a;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final emptyLabel = l10n.conflictCenterMergeFieldEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(AthlosSpacing.md),
            Text(
              l10n.conflictCenterMergeDialogTitle,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Gap(AthlosSpacing.md),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _fields.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  final valA = widget.itemA[field.key]?.toString() ?? '';
                  final valB = widget.itemB[field.key]?.toString() ?? '';
                  final selected = _selections[field.key] ?? _Side.a;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      RadioGroup<_Side>(
                        groupValue: selected,
                        onChanged: (_Side? v) {
                          if (v != null) {
                            setState(() => _selections[field.key] = v);
                          }
                        },
                        child: Column(
                          children: [
                            RadioListTile<_Side>(
                              title: Text(
                                valA.isEmpty ? emptyLabel : valA,
                                style: valA.isEmpty
                                    ? textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      )
                                    : null,
                              ),
                              subtitle: const Text('A'),
                              value: _Side.a,
                              dense: true,
                            ),
                            RadioListTile<_Side>(
                              title: Text(
                                valB.isEmpty ? emptyLabel : valB,
                                style: valB.isEmpty
                                    ? textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      )
                                    : null,
                              ),
                              subtitle: const Text('B'),
                              value: _Side.b,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Gap(AthlosSpacing.md),
            FilledButton(
              onPressed: _onConfirm,
              child: Text(l10n.conflictCenterMergeDialogConfirm),
            ),
            const Gap(AthlosSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _onConfirm() {
    final merged = <String, dynamic>{};
    for (final field in _fields) {
      final side = _selections[field.key] ?? _Side.a;
      merged[field.key] = side == _Side.a
          ? widget.itemA[field.key]
          : widget.itemB[field.key];
    }
    Navigator.of(
      context,
    ).pop(AttributeMergeResult(winnerId: widget.idA, mergedAttributes: merged));
  }
}

enum _Side { a, b }

class _MergeField {
  final String key;
  final String label;
  const _MergeField(this.key, this.label);
}
