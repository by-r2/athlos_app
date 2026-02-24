import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/equipment.dart';
import '../helpers/equipment_l10n.dart';
import '../providers/equipment_notifier.dart';

/// Search-based equipment picker with removable badges for selected items.
///
/// Displays a search field that filters equipment, shows matching results
/// as tappable list tiles, and renders selected items as removable [InputChip]s.
class EquipmentSearchPicker extends ConsumerStatefulWidget {
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  const EquipmentSearchPicker({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  ConsumerState<EquipmentSearchPicker> createState() =>
      _EquipmentSearchPickerState();
}

class _EquipmentSearchPickerState extends ConsumerState<EquipmentSearchPicker> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _hasFocus) {
        setState(() => _hasFocus = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final allEquipmentAsync = ref.watch(equipmentListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exerciseDetailEquipment,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        allEquipmentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (error, _) => Text('$error'),
          data: (equipments) =>
              _buildContent(equipments, l10n, colorScheme, textTheme),
        ),
      ],
    );
  }

  Widget _buildContent(
    List<Equipment> equipments,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (equipments.isEmpty) {
      return Text(
        l10n.exerciseNoEquipment,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final selected = equipments
        .where((eq) => widget.selectedIds.contains(eq.id))
        .toList();

    final showResults = _hasFocus || _query.isNotEmpty;
    final available = equipments
        .where((eq) => !widget.selectedIds.contains(eq.id))
        .toList();
    final filtered = !showResults
        ? <Equipment>[]
        : (_query.isEmpty
            ? available
            : available.where((eq) {
                final name = localizedEquipmentName(
                  eq.name,
                  isVerified: eq.isVerified,
                  l10n: l10n,
                ).toLowerCase();
                return name.contains(_query.toLowerCase());
              }).toList())
      ..sort((a, b) {
        final nameA = localizedEquipmentName(
          a.name, isVerified: a.isVerified, l10n: l10n,
        );
        final nameB = localizedEquipmentName(
          b.name, isVerified: b.isVerified, l10n: l10n,
        );
        return nameA.compareTo(nameB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: AthlosSpacing.sm,
            runSpacing: AthlosSpacing.xs,
            children: selected.map((eq) {
              final name = localizedEquipmentName(
                eq.name,
                isVerified: eq.isVerified,
                l10n: l10n,
              );
              return InputChip(
                key: ValueKey(eq.id),
                label: Text(name),
                onDeleted: () => _remove(eq.id),
              );
            }).toList(),
          ),
          const Gap(AthlosSpacing.sm),
        ],
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: l10n.searchEquipment,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: AthlosRadius.mdAll,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.sm,
              vertical: AthlosSpacing.sm,
            ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (filtered.isNotEmpty) ...[
          const Gap(AthlosSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final eq = filtered[index];
                final name = localizedEquipmentName(
                  eq.name,
                  isVerified: eq.isVerified,
                  l10n: l10n,
                );
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.sm,
                  ),
                  leading: const Icon(Icons.fitness_center, size: 18),
                  title: Text(name, style: textTheme.bodyMedium),
                  onTap: () => _add(eq.id),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _add(int id) {
    final updated = {...widget.selectedIds, id};
    widget.onChanged(updated);
    _searchController.clear();
    setState(() => _query = '');
  }

  void _remove(int id) {
    final updated = {...widget.selectedIds}..remove(id);
    widget.onChanged(updated);
  }
}
