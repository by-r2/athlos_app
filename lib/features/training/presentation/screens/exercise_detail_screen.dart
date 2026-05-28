import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
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
import '../widgets/exercise_detail_body.dart';

const _placeholderExercise = Exercise(
  id: '',
  name: '',
  muscleGroup: MuscleGroup.chest,
  isVerified: true,
);

/// Detail screen for a single exercise.
///
/// For custom exercises (isVerified = false), shows edit/delete actions.
class ExerciseDetailScreen extends ConsumerWidget {
  final String exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final allExercisesAsync = ref.watch(exerciseListProvider);

    final exercise = allExercisesAsync.value
        ?.where((e) => e.id == exerciseId)
        .firstOrNull;

    if (allExercisesAsync.hasError) {
      return AthlosScaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.genericError)),
      );
    }

    if (!allExercisesAsync.isLoading && exercise == null) {
      return AthlosScaffold(
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

    return AthlosScaffold(
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
              icon: Icon(
                Icons.delete_outline,
                color: colorScheme.onSurfaceVariant,
              ),
              tooltip: l10n.delete,
              onPressed: () =>
                  _confirmDelete(context, ref, displayExercise, l10n),
            ),
          ],
        ],
      ),
      body: Skeletonizer(
        enabled: allExercisesAsync.isLoading,
        child: ExerciseDetailBody(exercise: displayExercise),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, Exercise exercise) {
    showAthlosModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditExerciseSheet(exercise: exercise),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
    AppLocalizations l10n,
  ) {
    showAthlosDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteExerciseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(l10n.deleteExerciseMessage(exercise.name))],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(dialogContext),
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
                      context.showAthlosErrorSnack(
                        AppLocalizations.of(context)!.genericError,
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
  late bool _isIsometric;
  MovementPattern? _selectedMovementPattern;
  final List<({TargetMuscle muscle, MuscleRegion? region})> _primaryMuscles =
      [];
  final List<({TargetMuscle muscle, MuscleRegion? region})> _secondaryMuscles =
      [];
  bool _isSaving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise.name);
    _descriptionController = TextEditingController(
      text: widget.exercise.description ?? '',
    );
    _selectedGroup = widget.exercise.muscleGroup;
    _selectedType = widget.exercise.type;
    _isIsometric = widget.exercise.isIsometric;
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

  void _touchDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _closeSheet(BuildContext context) async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDiscardUnsavedEdits(context);
    if (!context.mounted) return;
    if (discard) Navigator.of(context).pop();
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
      (m) => (muscle: m.muscle, region: m.region, role: MuscleRole.primary),
    ),
    ..._secondaryMuscles.map(
      (m) => (muscle: m.muscle, region: m.region, role: MuscleRole.secondary),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ConfirmNavigationScope(
      guardActive: _dirty,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      child: Padding(
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
                          onPressed: () => _closeSheet(context),
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
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => _touchDirty(),
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
                                localizedMuscleGroupName(group, l10n),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _touchDirty();
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
                          onSelectionChanged: (v) {
                            _touchDirty();
                            setState(() {
                              _selectedType = v.first;
                              if (_selectedType == ExerciseType.cardio) {
                                _isIsometric = false;
                              }
                            });
                          },
                        ),
                        if (_selectedType == ExerciseType.strength) ...[
                          const Gap(AthlosSpacing.sm),
                          SwitchListTile(
                            title: Text(l10n.isometricLabel),
                            subtitle: Text(l10n.isometricHint),
                            value: _isIsometric,
                            onChanged: (v) {
                              _touchDirty();
                              setState(() => _isIsometric = v);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
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
                                  strokeWidth: 2,
                                ),
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
      initiallyExpanded:
          _primaryMuscles.isNotEmpty ||
          _secondaryMuscles.isNotEmpty ||
          _selectedMovementPattern != null,
      childrenPadding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      children: [
        _buildMuscleSection(
          label: l10n.primaryMusclesLabel,
          muscles: _primaryMuscles,
          excludedMuscles: _secondaryMuscles.map((m) => m.muscle).toSet(),
          l10n: l10n,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const Gap(AthlosSpacing.md),
        _buildMuscleSection(
          label: l10n.secondaryMusclesLabel,
          muscles: _secondaryMuscles,
          excludedMuscles: _primaryMuscles.map((m) => m.muscle).toSet(),
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
          onChanged: (v) {
            _touchDirty();
            setState(() => _selectedMovementPattern = v);
          },
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
          onChanged: (_) => _touchDirty(),
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
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
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
                final isSelected = muscles.any((f) => f.muscle == muscle);
                return FilterChip(
                  label: Text(
                    localizedTargetMuscle(muscle, l10n),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) {
                    _touchDirty();
                    setState(() {
                      if (selected) {
                        muscles.add((muscle: muscle, region: null));
                      } else {
                        muscles.removeWhere((f) => f.muscle == muscle);
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
    final all = [..._primaryMuscles, ..._secondaryMuscles];
    final musclesWithRegions = all
        .where((f) => f.muscle.validRegions.isNotEmpty)
        .toList();

    if (musclesWithRegions.isEmpty) return [];

    return [
      const Gap(AthlosSpacing.md),
      ...musclesWithRegions.map((focus) {
        final inPrimary = _primaryMuscles.any((f) => f.muscle == focus.muscle);
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
              _touchDirty();
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
        isIsometric: _isIsometric,
      );

      await ref
          .read(exerciseListProvider.notifier)
          .updateExercise(updated, muscles: _allMuscles);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Exception catch (_) {
      if (mounted) {
        context.showAthlosErrorSnack(AppLocalizations.of(context)!.genericError);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
