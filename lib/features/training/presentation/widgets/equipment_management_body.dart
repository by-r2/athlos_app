import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/enums/equipment_category.dart';
import '../helpers/equipment_l10n.dart';
import '../providers/equipment_notifier.dart';
import 'add_equipment_dialog.dart';
import 'equipment_tile.dart';

final _placeholderEquipment = List.generate(
  8,
  (i) => Equipment(
    id: i,
    name: 'Placeholder equipment',
    category: EquipmentCategory.accessories,
    isVerified: true,
  ),
);

class EquipmentManagementBody extends ConsumerStatefulWidget {
  final bool showInlineAddButton;
  final ValueChanged<Equipment>? onEquipmentTap;
  final bool defaultCatalogOpen;
  final bool catalogOnly;
  final bool allowCustomManagement;

  const EquipmentManagementBody({
    super.key,
    this.showInlineAddButton = false,
    this.onEquipmentTap,
    this.defaultCatalogOpen = false,
    this.catalogOnly = false,
    this.allowCustomManagement = true,
  });

  @override
  ConsumerState<EquipmentManagementBody> createState() =>
      _EquipmentManagementBodyState();
}

class _EquipmentManagementBodyState extends ConsumerState<EquipmentManagementBody> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isCatalogOpen = false;

  @override
  void initState() {
    super.initState();
    _isCatalogOpen = widget.defaultCatalogOpen || widget.catalogOnly;
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_isCatalogOpen && !widget.catalogOnly) {
        setState(() => _isCatalogOpen = true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeCatalog() {
    _searchController.clear();
    _searchFocus.unfocus();
    if (widget.catalogOnly) {
      setState(() => _searchQuery = '');
      return;
    }
    setState(() {
      _searchQuery = '';
      _isCatalogOpen = false;
    });
  }

  List<Equipment> _sortAlphabetically(
      List<Equipment> items, AppLocalizations l10n) {
    return items
      ..sort((a, b) {
        final nameA =
            localizedEquipmentName(a.name, isVerified: a.isVerified, l10n: l10n);
        final nameB =
            localizedEquipmentName(b.name, isVerified: b.isVerified, l10n: l10n);
        return nameA.compareTo(nameB);
      });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final equipmentAsync = ref.watch(equipmentListProvider);
    final userIdsAsync = ref.watch(userEquipmentIdsProvider);
    final allEquipment = equipmentAsync.value ?? _placeholderEquipment;
    final userIds = userIdsAsync.value ?? <int>{};

    if (equipmentAsync.hasError) {
      return Center(child: Text(l10n.genericError));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            AthlosSpacing.sm,
            AthlosSpacing.md,
            0,
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            decoration: InputDecoration(
              hintText: l10n.searchEquipment,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isCatalogOpen
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _closeCatalog,
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: AthlosRadius.mdAll,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (widget.showInlineAddButton && !_isCatalogOpen && !widget.catalogOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              0,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.addEquipment),
              ),
            ),
          ),
        const Gap(AthlosSpacing.sm),
        Expanded(
          child: Skeletonizer(
            enabled: equipmentAsync.isLoading,
            child: widget.catalogOnly
                ? _buildCatalog(
                    allEquipment,
                    userIds,
                    l10n,
                    colorScheme,
                    textTheme,
                  )
                : _isCatalogOpen
                ? _buildCatalog(
                    allEquipment,
                    userIds,
                    l10n,
                    colorScheme,
                    textTheme,
                  )
                : _buildUserList(
                    allEquipment,
                    userIds,
                    l10n,
                    colorScheme,
                    textTheme,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(
    List<Equipment> allEquipment,
    Set<int> userIds,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final owned = _sortAlphabetically(
      allEquipment.where((e) => userIds.contains(e.id)).toList(),
      l10n,
    );

    if (owned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 48,
                color: colorScheme.onSurfaceVariant.withAlpha(100),
              ),
              const Gap(AthlosSpacing.md),
              Text(
                l10n.emptyEquipment,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.sm),
              Text(
                l10n.emptyEquipmentHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.fabClearance),
      itemCount: owned.length,
      itemBuilder: (context, index) {
        final equipment = owned[index];
        return GestureDetector(
          onLongPress: !widget.allowCustomManagement || equipment.isVerified
              ? null
              : () => _showEditOptions(context, equipment, l10n),
          child: EquipmentTile(
            key: ValueKey(equipment.id),
            displayName: localizedEquipmentName(
              equipment.name,
              isVerified: equipment.isVerified,
              l10n: l10n,
            ),
            category: localizedCategoryName(equipment.category, l10n),
            categoryDescription:
                localizedCategoryDescription(equipment.category, l10n),
            onTap: widget.onEquipmentTap == null
                ? null
                : () => widget.onEquipmentTap!(equipment),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.allowCustomManagement && !equipment.isVerified)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: l10n.edit,
                    onPressed: () => _showEditEquipmentDialog(context, equipment),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: l10n.removeEquipment,
                  onPressed: () => _toggleEquipment(equipment.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleEquipment(int equipmentId) async {
    try {
      await ref.read(userEquipmentIdsProvider.notifier).toggle(equipmentId);
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    }
  }

  void _showEditOptions(
      BuildContext context, Equipment equipment, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEditEquipmentDialog(context, equipment);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n.delete),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeleteEquipment(context, equipment, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEquipmentDialog(BuildContext context, Equipment equipment) {
    showAthlosDialog<void>(
      context: context,
      builder: (context) => _EditEquipmentDialog(equipment: equipment),
    );
  }

  void _confirmDeleteEquipment(
      BuildContext context, Equipment equipment, AppLocalizations l10n) {
    showAthlosDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteEquipmentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteEquipmentMessage(equipment.name)),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style:
                    AthlosDialogButtonStyles.stackedGhost(dialogContext),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await ref
                        .read(equipmentListProvider.notifier)
                        .deleteEquipment(equipment.id);
                    ref.invalidate(userEquipmentIdsProvider);
                  } on Exception catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.genericError),
                        ),
                      );
                    }
                  }
                },
                child: Text(l10n.delete),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(dialogContext),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog(
    List<Equipment> allEquipment,
    Set<int> userIds,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    bool isLoading = false,
  }) {
    final query = _searchQuery.toLowerCase();
    final results = _sortAlphabetically(
      allEquipment.where((e) {
        if (query.isEmpty) return true;
        final displayName = localizedEquipmentName(
          e.name,
          isVerified: e.isVerified,
          l10n: l10n,
        ).toLowerCase();
        return displayName.contains(query);
      }).toList(),
      l10n,
    );

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.handyman,
                size: 48,
                color: colorScheme.onSurfaceVariant.withAlpha(100),
              ),
              const Gap(AthlosSpacing.md),
              Text(
                l10n.equipmentCatalogEmpty,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(AthlosSpacing.xs),
              Text(
                l10n.equipmentCatalogEmptyHint,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.trim().isNotEmpty) ...[
                const Gap(AthlosSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _showAddDialog(
                    context,
                    initialName: _searchQuery.trim(),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.registerNewEquipment),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.fabClearance),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final equipment = results[index];
        final isOwned = userIds.contains(equipment.id);
        return EquipmentTile(
          key: ValueKey(equipment.id),
          displayName: localizedEquipmentName(
            equipment.name,
            isVerified: equipment.isVerified,
            l10n: l10n,
          ),
          category: localizedCategoryName(equipment.category, l10n),
          categoryDescription:
              localizedCategoryDescription(equipment.category, l10n),
          onTap: widget.onEquipmentTap == null
              ? null
              : () => widget.onEquipmentTap!(equipment),
          trailing: IconButton(
            icon: Icon(
              isOwned ? Icons.check_circle : Icons.radio_button_unchecked,
              color:
                  isOwned ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: l10n.iOwnEquipment,
            onPressed: isLoading ? null : () => _toggleEquipment(equipment.id),
          ),
        );
      },
    );
  }

  void _showAddDialog(
    BuildContext context, {
    String initialName = '',
  }) {
    showAddEquipmentDialog(
      context,
      initialName: initialName,
    );
  }
}

/// Dialog to edit a user-created equipment.
class _EditEquipmentDialog extends ConsumerStatefulWidget {
  final Equipment equipment;

  const _EditEquipmentDialog({required this.equipment});

  @override
  ConsumerState<_EditEquipmentDialog> createState() =>
      _EditEquipmentDialogState();
}

class _EditEquipmentDialogState extends ConsumerState<_EditEquipmentDialog> {
  late final TextEditingController _nameController;
  late EquipmentCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.equipment.name);
    _selectedCategory = widget.equipment.category;
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
      title: Text(l10n.editEquipment),
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
            onChanged: (value) {
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
        ],
      ),
      actions: [
        AthlosStackedDialogActions(
          children: [
            TextButton(
              style: AthlosDialogButtonStyles.stackedGhost(context),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: AthlosDialogButtonStyles.stackedFilled(context),
              onPressed: _onSave,
              child: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updated = Equipment(
      id: widget.equipment.id,
      name: name,
      category: _selectedCategory,
    );

    try {
      await ref.read(equipmentListProvider.notifier).updateEquipment(updated);
      ref.invalidate(userEquipmentIdsProvider);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    }
  }
}
