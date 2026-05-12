import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/profile_notifier.dart';

class OwnedEquipmentList extends ConsumerStatefulWidget {
  const OwnedEquipmentList({super.key});

  @override
  ConsumerState<OwnedEquipmentList> createState() => _OwnedEquipmentListState();
}

class _OwnedEquipmentListState extends ConsumerState<OwnedEquipmentList> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addEquipment() async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;

    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final current = profile.ownedEquipmentNames;
    if (current.contains(name)) {
      _controller.clear();
      return;
    }

    await ref
        .read(profileProvider.notifier)
        .updateProfile(
          profile.copyWith(ownedEquipmentNames: [...current, name]),
        );
    _controller.clear();
  }

  Future<void> _removeEquipment(String name) async {
    final profile = ref.read(profileProvider).value;
    if (profile == null) return;
    final updated = [...profile.ownedEquipmentNames]..remove(name);
    await ref
        .read(profileProvider.notifier)
        .updateProfile(profile.copyWith(ownedEquipmentNames: updated));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profile = ref.watch(profileProvider).value;
    final equipment = profile?.ownedEquipmentNames ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.ownedEquipmentAddHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addEquipment,
              ),
            ),
            onSubmitted: (_) => _addEquipment(),
          ),
          const Gap(AthlosSpacing.md),
          if (equipment.isEmpty)
            Text(
              l10n.ownedEquipmentEmpty,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: AthlosSpacing.sm,
              runSpacing: AthlosSpacing.sm,
              children: equipment
                  .map(
                    (item) => InputChip(
                      key: ValueKey(item),
                      label: Text(item),
                      onDeleted: () => _removeEquipment(item),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
