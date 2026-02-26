import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../widgets/equipment_search_picker.dart';
import '../widgets/exercise_tile.dart';
import '../widgets/muscle_group_filter.dart';

final _placeholderExercises = List.generate(
  8,
  (i) => Exercise(
    id: -(i + 1),
    name: BoneMock.name,
    muscleGroup: MuscleGroup.chest,
    muscles: [],
  ),
);

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
            child: () {
              if (exercisesAsync.hasError) {
                return Center(child: Text(l10n.genericError));
              }
              final isLoading = exercisesAsync.isLoading;
              final exercises = exercisesAsync.value ?? [];
              final filtered =
                  isLoading ? exercises : _filterExercises(exercises, l10n);
              final displayList = isLoading ? _placeholderExercises : filtered;

              if (!isLoading && filtered.isEmpty) {
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

              return Skeletonizer(
                enabled: isLoading,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.fabClearance),
                  itemCount: displayList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = displayList[index];
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
                      onTap: isLoading
                          ? null
                          : () => context.push(
                                '${RoutePaths.trainingExercises}/${exercise.id}',
                              ),
                    );
                  },
                ),
              );
            }(),
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

/// Bottom sheet to create a user-defined exercise with progressive disclosure.
///
/// Visible (required): name, muscle group, type.
/// Collapsible "Advanced details": primary/secondary muscles, regions,
/// movement pattern, equipment, description.
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
  ExerciseType _selectedType = ExerciseType.strength;
  MovementPattern? _selectedMovementPattern;
  final Set<int> _selectedEquipmentIds = {};
  final List<({TargetMuscle muscle, MuscleRegion? region})> _primaryMuscles =
      [];
  final List<({TargetMuscle muscle, MuscleRegion? region})>
      _secondaryMuscles = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<({TargetMuscle muscle, MuscleRegion? region, MuscleRole role})>
      get _allMuscles => [
            ..._primaryMuscles.map(
                (m) => (muscle: m.muscle, region: m.region, role: MuscleRole.primary)),
            ..._secondaryMuscles.map(
                (m) => (muscle: m.muscle, region: m.region, role: MuscleRole.secondary)),
          ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      borderRadius: AthlosRadius.xsAll,
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
                            setState(() => _selectedGroup = value);
                          }
                        },
                      ),
                      const Gap(AthlosSpacing.md),
                      SegmentedButton<ExerciseType>(
                        segments: [
                          ButtonSegment(
                            value: ExerciseType.strength,
                            label: Text(l10n.exerciseTypeStrength),
                          ),
                          ButtonSegment(
                            value: ExerciseType.cardio,
                            label: Text(l10n.exerciseTypeCardio),
                          ),
                        ],
                        selected: {_selectedType},
                        onSelectionChanged: (v) =>
                            setState(() => _selectedType = v.first),
                      ),
                      const Gap(AthlosSpacing.sm),
                      _buildAdvancedSection(l10n, textTheme, colorScheme),
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

  Widget _buildAdvancedSection(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return ExpansionTile(
      title: Text(l10n.advancedDetails),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      children: [
        _buildMuscleSection(
          label: l10n.primaryMusclesLabel,
          muscles: _primaryMuscles,
          excludedMuscles:
              _secondaryMuscles.map((m) => m.muscle).toSet(),
          l10n: l10n,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const Gap(AthlosSpacing.md),
        _buildMuscleSection(
          label: l10n.secondaryMusclesLabel,
          muscles: _secondaryMuscles,
          excludedMuscles:
              _primaryMuscles.map((m) => m.muscle).toSet(),
          l10n: l10n,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        ..._buildRegionDropdowns(l10n),
        const Gap(AthlosSpacing.md),
        DropdownButtonFormField<MovementPattern?>(
          initialValue: _selectedMovementPattern,
          decoration: InputDecoration(
            labelText: l10n.movementPatternLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<MovementPattern?>(
              value: null,
              child: Text(
                '—',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ...MovementPattern.values.map(
              (p) => DropdownMenuItem(
                value: p,
                child: Text(localizedMovementPattern(p, l10n)),
              ),
            ),
          ],
          onChanged: (v) =>
              setState(() => _selectedMovementPattern = v),
        ),
        const Gap(AthlosSpacing.md),
        EquipmentSearchPicker(
          selectedIds: _selectedEquipmentIds,
          onChanged: (ids) => setState(() {
            _selectedEquipmentIds
              ..clear()
              ..addAll(ids);
          }),
        ),
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
      ],
    );
  }

  Widget _buildMuscleSection({
    required String label,
    required List<({TargetMuscle muscle, MuscleRegion? region})> muscles,
    required Set<TargetMuscle> excludedMuscles,
    required AppLocalizations l10n,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final grouped = <MuscleGroup, List<TargetMuscle>>{};
    for (final m in TargetMuscle.values) {
      if (m.muscleGroup == MuscleGroup.cardio ||
          m.muscleGroup == MuscleGroup.fullBody) {
        continue;
      }
      grouped.putIfAbsent(m.muscleGroup, () => []).add(m);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleSmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const Gap(AthlosSpacing.xs),
        ...grouped.entries.map((entry) {
          final groupMuscles = entry.value
              .where((m) => !excludedMuscles.contains(m))
              .toList();
          if (groupMuscles.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
            child: Wrap(
              spacing: AthlosSpacing.xs,
              runSpacing: 0,
              children: groupMuscles.map((muscle) {
                final isSelected =
                    muscles.any((f) => f.muscle == muscle);
                return FilterChip(
                  label: Text(
                    localizedTargetMuscle(muscle, l10n),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        muscles
                            .add((muscle: muscle, region: null));
                      } else {
                        muscles.removeWhere(
                            (f) => f.muscle == muscle);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildRegionDropdowns(AppLocalizations l10n) {
    final all = [
      ..._primaryMuscles,
      ..._secondaryMuscles,
    ];
    final musclesWithRegions =
        all.where((f) => f.muscle.validRegions.isNotEmpty).toList();

    if (musclesWithRegions.isEmpty) return [];

    return [
      const Gap(AthlosSpacing.md),
      ...musclesWithRegions.map((focus) {
        final inPrimary =
            _primaryMuscles.any((f) => f.muscle == focus.muscle);
        final list = inPrimary ? _primaryMuscles : _secondaryMuscles;
        final idx = list.indexWhere((f) => f.muscle == focus.muscle);
        return Padding(
          padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
          child: DropdownButtonFormField<MuscleRegion?>(
            initialValue: focus.region,
            decoration: InputDecoration(
              labelText: l10n.muscleWithSeparator(
                localizedTargetMuscle(focus.muscle, l10n),
                l10n.muscleRegionLabel,
              ),
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
                list[idx] = (muscle: focus.muscle, region: value);
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
            muscles: _allMuscles,
          );

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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

