import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/equipment_l10n.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/equipment_notifier.dart';
import '../providers/exercise_notifier.dart';

/// Bottom sheet that lets the user search and pick an exercise.
///
/// Returns the selected [Exercise] or `null` if cancelled.
Future<Exercise?> showExercisePickerSheet(BuildContext context) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            _ExercisePickerBody(scrollController: scrollController),
      ),
    );

class _ExercisePickerBody extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _ExercisePickerBody({required this.scrollController});

  @override
  ConsumerState<_ExercisePickerBody> createState() =>
      _ExercisePickerBodyState();
}

class _ExercisePickerBodyState extends ConsumerState<_ExercisePickerBody> {
  final _searchController = TextEditingController();
  String _query = '';
  MuscleGroup? _selectedGroup;
  bool _onlyMyEquipment = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exercisesAsync = ref.watch(exerciseListProvider);
    final equipmentMapAsync = ref.watch(exerciseEquipmentMapProvider);
    final userEquipmentAsync = ref.watch(userEquipmentIdsProvider);
    final allEquipmentAsync = ref.watch(equipmentListProvider);

    return Column(
      children: [
        const SizedBox(height: AthlosSpacing.sm),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Text(
            l10n.selectExercise,
            style: textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchExercises,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        const SizedBox(height: AthlosSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
            children: [
              FilterChip(
                avatar: Icon(
                  _onlyMyEquipment
                      ? Icons.fitness_center
                      : Icons.fitness_center_outlined,
                  size: 18,
                ),
                label: Text(l10n.filterMyEquipment),
                selected: _onlyMyEquipment,
                onSelected: (v) =>
                    setState(() => _onlyMyEquipment = v),
              ),
              const SizedBox(width: AthlosSpacing.sm),
              FilterChip(
                label: Text(l10n.filterAll),
                selected: _selectedGroup == null,
                onSelected: (_) =>
                    setState(() => _selectedGroup = null),
              ),
              const SizedBox(width: AthlosSpacing.xs),
              ...MuscleGroup.values.map(
                (g) => Padding(
                  padding:
                      const EdgeInsets.only(right: AthlosSpacing.xs),
                  child: FilterChip(
                    label: Text(localizedMuscleGroupName(g, l10n)),
                    selected: _selectedGroup == g,
                    onSelected: (_) =>
                        setState(() => _selectedGroup = g),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AthlosSpacing.sm),
        Expanded(
          child: exercisesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (exercises) {
              final equipmentMap =
                  equipmentMapAsync.value ?? <int, List<int>>{};
              final userEquipment =
                  userEquipmentAsync.value ?? <int>{};
              final allEquipment =
                  allEquipmentAsync.value ?? [];
              final equipmentById = {
                for (final e in allEquipment) e.id: e,
              };

              final filtered = exercises.where((ex) {
                if (_selectedGroup != null &&
                    ex.muscleGroup != _selectedGroup) {
                  return false;
                }
                if (_query.isNotEmpty) {
                  final name = localizedExerciseName(
                    ex.name,
                    isVerified: ex.isVerified,
                    l10n: l10n,
                  ).toLowerCase();
                  if (!name.contains(_query)) return false;
                }
                if (_onlyMyEquipment) {
                  final required = equipmentMap[ex.id] ?? [];
                  if (required.any((id) => !userEquipment.contains(id))) {
                    return false;
                  }
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    l10n.emptyExercises,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ex = filtered[index];
                  final displayName = localizedExerciseName(
                    ex.name,
                    isVerified: ex.isVerified,
                    l10n: l10n,
                  );
                  final groupName =
                      localizedMuscleGroupName(ex.muscleGroup, l10n);

                  final reqIds = equipmentMap[ex.id] ?? [];
                  final equipNames = reqIds
                      .map((id) {
                        final eq = equipmentById[id];
                        if (eq == null) return null;
                        return localizedEquipmentName(
                          eq.name,
                          isVerified: eq.isVerified,
                          l10n: l10n,
                        );
                      })
                      .whereType<String>()
                      .toList();

                  final subtitle = equipNames.isEmpty
                      ? groupName
                      : '$groupName  •  ${equipNames.join(', ')}';

                  final hasMissing = reqIds
                      .any((id) => !userEquipment.contains(id));

                  return ListTile(
                    leading: hasMissing
                        ? Icon(Icons.warning_amber_rounded,
                            color: colorScheme.error, size: 20)
                        : null,
                    title: Text(displayName),
                    subtitle: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => Navigator.of(context).pop(ex),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
