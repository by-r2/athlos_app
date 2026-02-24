import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/target_muscle.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../widgets/equipment_search_picker.dart';
import '../widgets/exercise_tile.dart';
import '../widgets/muscle_group_filter.dart';

/// Training module — Exercises tab (EX-01 to EX-05).
///
/// Displays the exercise catalog with muscle group filtering and search.
class TrainingExercisesScreen extends ConsumerStatefulWidget {
  const TrainingExercisesScreen({super.key});

  @override
  ConsumerState<TrainingExercisesScreen> createState() =>
      _TrainingExercisesScreenState();
}

class _TrainingExercisesScreenState
    extends ConsumerState<TrainingExercisesScreen> {
  MuscleGroup? _selectedGroup;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        tooltip: l10n.addExercise,
        child: const Icon(Icons.add),
      ),
      body: Column(
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
              decoration: InputDecoration(
                hintText: l10n.searchExercises,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
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
          const Gap(AthlosSpacing.sm),
          MuscleGroupFilter(
            selected: _selectedGroup,
            onSelected: (group) => setState(() => _selectedGroup = group),
          ),
          const Gap(AthlosSpacing.xs),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (exercises) {
                final filtered = _filterExercises(exercises, l10n);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AthlosSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_gymnastics,
                            size: 48,
                            color:
                                colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                          const Gap(AthlosSpacing.md),
                          Text(
                            l10n.emptyExercises,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = filtered[index];
                    final musclesSummary = exercise.muscles
                        .map((f) => localizedTargetMuscle(f.muscle, l10n))
                        .join(', ');

                    return ExerciseTile(
                      key: ValueKey(exercise.id),
                      displayName: localizedExerciseName(
                        exercise.name,
                        isVerified: exercise.isVerified,
                        l10n: l10n,
                      ),
                      muscleGroupLabel: localizedMuscleGroupName(
                          exercise.muscleGroup, l10n),
                      targetMusclesLabel:
                          musclesSummary.isNotEmpty ? musclesSummary : null,
                      onTap: () => context.push(
                        '${RoutePaths.trainingExercises}/${exercise.id}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _AddExerciseSheet(),
    );
  }

  List<Exercise> _filterExercises(
      List<Exercise> exercises, AppLocalizations l10n) {
    var filtered = exercises.toList();

    if (_selectedGroup != null) {
      filtered =
          filtered.where((e) => e.muscleGroup == _selectedGroup).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((e) {
        final name = localizedExerciseName(
          e.name,
          isVerified: e.isVerified,
          l10n: l10n,
        ).toLowerCase();
        return name.contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      final nameA = localizedExerciseName(a.name,
          isVerified: a.isVerified, l10n: l10n);
      final nameB = localizedExerciseName(b.name,
          isVerified: b.isVerified, l10n: l10n);
      return nameA.compareTo(nameB);
    });

    return filtered;
  }
}

/// Bottom sheet to create a user-defined exercise with enum-based muscle selection.
class _AddExerciseSheet extends ConsumerStatefulWidget {
  const _AddExerciseSheet();

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  MuscleGroup _selectedGroup = MuscleGroup.chest;
  final Set<int> _selectedEquipmentIds = {};
  final List<({TargetMuscle muscle, MuscleRegion? region})> _muscleFoci = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final availableMuscles = TargetMuscle.values
        .where((m) => m.muscleGroup == _selectedGroup)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AthlosSpacing.sm),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AthlosSpacing.md,
                    AthlosSpacing.md,
                    AthlosSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.addExercise,
                          style: textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AthlosSpacing.md,
                    ),
                    children: [
                      const Gap(AthlosSpacing.sm),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseNameLabel,
                          border: const OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.fieldRequired;
                          }
                          return null;
                        },
                      ),
                      const Gap(AthlosSpacing.md),
                      DropdownButtonFormField<MuscleGroup>(
                        initialValue: _selectedGroup,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseMuscleGroupLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: MuscleGroup.values.map((group) {
                          return DropdownMenuItem(
                            value: group,
                            child: Text(
                                localizedMuscleGroupName(group, l10n)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedGroup = value;
                              _muscleFoci.clear();
                            });
                          }
                        },
                      ),
                      const Gap(AthlosSpacing.lg),
                      Text(
                        l10n.targetMusclesLabel,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AthlosSpacing.sm),
                      Wrap(
                        spacing: AthlosSpacing.sm,
                        runSpacing: AthlosSpacing.xs,
                        children: availableMuscles.map((muscle) {
                          final isSelected =
                              _muscleFoci.any((f) => f.muscle == muscle);
                          return FilterChip(
                            label:
                                Text(localizedTargetMuscle(muscle, l10n)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _muscleFoci.add(
                                      (muscle: muscle, region: null));
                                } else {
                                  _muscleFoci.removeWhere(
                                      (f) => f.muscle == muscle);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      ..._buildRegionDropdowns(l10n),
                      const Gap(AthlosSpacing.md),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseDescriptionLabel,
                          hintText: l10n.exerciseDescriptionHint,
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const Gap(AthlosSpacing.lg),
                      EquipmentSearchPicker(
                        selectedIds: _selectedEquipmentIds,
                        onChanged: (ids) =>
                            setState(() {
                              _selectedEquipmentIds
                                ..clear()
                                ..addAll(ids);
                            }),
                      ),
                      const Gap(AthlosSpacing.xl),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AthlosSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _onSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildRegionDropdowns(AppLocalizations l10n) {
    final musclesWithRegions =
        _muscleFoci.where((f) => f.muscle.validRegions.isNotEmpty).toList();

    if (musclesWithRegions.isEmpty) return [];

    return [
      const Gap(AthlosSpacing.md),
      ...musclesWithRegions.map((focus) {
        final idx = _muscleFoci.indexWhere((f) => f.muscle == focus.muscle);
        return Padding(
          padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
          child: DropdownButtonFormField<MuscleRegion?>(
            initialValue: focus.region,
            decoration: InputDecoration(
              labelText:
                  '${localizedTargetMuscle(focus.muscle, l10n)} — ${l10n.muscleRegionLabel}',
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem<MuscleRegion?>(
                value: null,
                child: Text(
                  '—',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...focus.muscle.validRegions.map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(localizedMuscleRegion(r, l10n)),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _muscleFoci[idx] = (muscle: focus.muscle, region: value);
              });
            },
          ),
        );
      }),
    ];
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final description = _descriptionController.text.trim();

      await ref.read(exerciseListProvider.notifier).addCustomExercise(
            name: _nameController.text.trim(),
            muscleGroup: _selectedGroup,
            description: description.isEmpty ? null : description,
            equipmentIds: _selectedEquipmentIds.toList(),
            muscles: _muscleFoci,
          );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
