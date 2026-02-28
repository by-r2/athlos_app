import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
import '../helpers/equipment_l10n.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/equipment_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../widgets/equipment_search_picker.dart';

const _placeholderExercise = Exercise(
  id: 0,
  name: '',
  muscleGroup: MuscleGroup.chest,
  isVerified: true,
);

/// Detail screen for a single exercise.
///
/// For custom exercises (isVerified = false), shows edit/delete actions.
class ExerciseDetailScreen extends ConsumerWidget {
  final int exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final allExercisesAsync = ref.watch(exerciseListProvider);

    final exercise = allExercisesAsync.value
        ?.where((e) => e.id == exerciseId)
        .firstOrNull;

    if (allExercisesAsync.hasError) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!allExercisesAsync.isLoading && exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.exerciseNotFound)),
      );
    }

    final displayExercise = exercise ?? _placeholderExercise;
    final displayName = localizedExerciseName(
      displayExercise.name,
      isVerified: displayExercise.isVerified,
      l10n: l10n,
    );

    return Scaffold(
          appBar: AppBar(
            title: Text(displayName),
            actions: [
              if (!displayExercise.isVerified) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.edit,
                  onPressed: () => _showEditSheet(context, ref, displayExercise),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  tooltip: l10n.delete,
                  onPressed: () =>
                      _confirmDelete(context, ref, displayExercise, l10n),
                ),
              ],
            ],
          ),
          body: Skeletonizer(
            enabled: allExercisesAsync.isLoading,
            child: ListView(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              children: [
                if (displayExercise.description != null &&
                    displayExercise.description!.isNotEmpty) ...[
                  Text(
                    displayExercise.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(AthlosSpacing.lg),
              ],
              _buildInfoSection(
                context,
                icon: Icons.sports_gymnastics,
                title: l10n.exerciseDetailMuscleGroup,
                value: localizedMuscleGroupName(displayExercise.muscleGroup, l10n),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const Gap(AthlosSpacing.md),
              _buildInfoSection(
                context,
                icon: Icons.category,
                title: l10n.exerciseDetailType,
                value: displayExercise.type == ExerciseType.strength
                    ? l10n.exerciseTypeStrength
                    : l10n.exerciseTypeCardio,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              if (displayExercise.movementPattern != null) ...[
                const Gap(AthlosSpacing.md),
                _buildInfoSection(
                  context,
                  icon: Icons.swap_horiz,
                  title: l10n.movementPatternLabel,
                  value: localizedMovementPattern(
                    displayExercise.movementPattern!,
                    l10n,
                  ),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
              if (displayExercise.muscles.isNotEmpty) ...[
                const Gap(AthlosSpacing.md),
                _buildMusclesSection(
                  context,
                  muscles: displayExercise.muscles,
                  l10n: l10n,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ],
              const Gap(AthlosSpacing.lg),
              _EquipmentSection(exerciseId: exerciseId),
              const Gap(AthlosSpacing.lg),
              _VariationsSection(
                exerciseId: exerciseId,
                currentExerciseName: displayName,
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildMusclesSection(
    BuildContext context, {
    required List<ExerciseMuscleFocus> muscles,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.my_location, size: 20, color: colorScheme.primary),
        const Gap(AthlosSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.exerciseDetailTargetMuscles,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.xs),
              ...muscles.map((focus) {
                final muscleName = localizedTargetMuscle(focus.muscle, l10n);
                if (focus.region != null) {
                  final regionName = localizedMuscleRegion(focus.region!, l10n);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
                    child: Text(l10n.muscleWithRegion(muscleName, regionName),
                        style: textTheme.bodyLarge),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
                  child: Text(muscleName, style: textTheme.bodyLarge),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditSheet(
      BuildContext context, WidgetRef ref, Exercise exercise) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditExerciseSheet(exercise: exercise),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Exercise exercise,
      AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteExerciseTitle),
        content: Text(l10n.deleteExerciseMessage(exercise.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref
                    .read(exerciseListProvider.notifier)
                    .deleteExercise(exercise.id);
                if (context.mounted) {
                  context.pop();
                }
              } on Exception catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.genericError),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const Gap(AthlosSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.xs),
              Text(value, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for editing a custom exercise with progressive disclosure.
class _EditExerciseSheet extends ConsumerStatefulWidget {
  final Exercise exercise;

  const _EditExerciseSheet({required this.exercise});

  @override
  ConsumerState<_EditExerciseSheet> createState() => _EditExerciseSheetState();
}

class _EditExerciseSheetState extends ConsumerState<_EditExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late MuscleGroup _selectedGroup;
  late ExerciseType _selectedType;
  MovementPattern? _selectedMovementPattern;
  final Set<int> _selectedEquipmentIds = {};
  final List<({TargetMuscle muscle, MuscleRegion? region})> _primaryMuscles =
      [];
  final List<({TargetMuscle muscle, MuscleRegion? region})>
      _secondaryMuscles = [];
  bool _isSaving = false;
  bool _isEquipmentLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _descriptionController =
        TextEditingController(text: widget.exercise.description ?? '');
    _selectedGroup = widget.exercise.muscleGroup;
    _selectedType = widget.exercise.type;
    _selectedMovementPattern = widget.exercise.movementPattern;
    for (final f in widget.exercise.muscles) {
      final entry = (muscle: f.muscle, region: f.region);
      if (f.role == MuscleRole.secondary) {
        _secondaryMuscles.add(entry);
      } else {
        _primaryMuscles.add(entry);
      }
    }
  }

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
    final currentEqIdsAsync =
        ref.watch(exerciseEquipmentIdsProvider(widget.exercise.id));

    if (!_isEquipmentLoaded && currentEqIdsAsync.hasValue) {
      _selectedEquipmentIds.addAll(currentEqIdsAsync.value!);
      _isEquipmentLoaded = true;
    }

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
                          l10n.editExercise,
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
                            child:
                                Text(localizedMuscleGroupName(group, l10n)),
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
      initiallyExpanded: _primaryMuscles.isNotEmpty ||
          _secondaryMuscles.isNotEmpty ||
          _selectedMovementPattern != null,
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

      final updated = Exercise(
        id: widget.exercise.id,
        name: _nameController.text.trim(),
        muscleGroup: _selectedGroup,
        type: _selectedType,
        movementPattern: _selectedMovementPattern,
        description: description.isEmpty ? null : description,
      );

      await ref.read(exerciseListProvider.notifier).updateExercise(
            updated,
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

/// Shows equipment required for the exercise.
class _EquipmentSection extends ConsumerWidget {
  final int exerciseId;

  const _EquipmentSection({required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final equipmentIdsAsync =
        ref.watch(exerciseEquipmentIdsProvider(exerciseId));
    final allEquipmentAsync = ref.watch(equipmentListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fitness_center, size: 20, color: colorScheme.primary),
            const Gap(AthlosSpacing.sm),
            Text(
              l10n.exerciseDetailEquipment,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        equipmentIdsAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => Text('$error'),
          data: (eqIds) {
            if (eqIds.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: AthlosSpacing.lg),
                child: Text(
                  l10n.exerciseNoEquipment,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return allEquipmentAsync.when(
              loading: () => const SizedBox(
                height: 32,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, _) => Text('$error'),
              data: (allEquipment) {
                final linked = allEquipment
                    .where((eq) => eqIds.contains(eq.id))
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(left: AthlosSpacing.lg),
                  child: Wrap(
                    spacing: AthlosSpacing.sm,
                    runSpacing: AthlosSpacing.xs,
                    children: linked
                        .map((eq) => Chip(
                              label: Text(
                                localizedEquipmentName(
                                  eq.name,
                                  isVerified: eq.isVerified,
                                  l10n: l10n,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Shows exercise variations.
class _VariationsSection extends ConsumerWidget {
  final int exerciseId;
  final String currentExerciseName;

  const _VariationsSection({
    required this.exerciseId,
    required this.currentExerciseName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final variationsAsync = ref.watch(exerciseVariationsProvider(exerciseId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz, size: 20, color: colorScheme.primary),
            const Gap(AthlosSpacing.sm),
            Text(
              l10n.exerciseDetailVariations,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        variationsAsync.when(
          loading: () => const SizedBox(
            height: 32,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, _) => Text('$error'),
          data: (variations) {
            if (variations.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(left: AthlosSpacing.lg),
                child: Text(
                  l10n.exerciseNoVariations,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(left: AthlosSpacing.lg),
              child: Column(
                children: variations.map((v) {
                  final name = localizedExerciseName(
                    v.name,
                    isVerified: v.isVerified,
                    l10n: l10n,
                  );
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    subtitle: Text(
                      localizedMuscleGroupName(v.muscleGroup, l10n),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      context.push(
                        '${RoutePaths.trainingExercises}/${v.id}',
                      );
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}
