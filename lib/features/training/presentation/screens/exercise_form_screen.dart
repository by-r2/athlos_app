import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_button_sizes.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_section.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';
import '../../domain/exercise_name_match.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../widgets/program_settings_section_card.dart';

String _optionalFieldLabel(AppLocalizations l10n, String label) =>
    '$label ${l10n.formFieldOptionalSuffix}';

String? _optionalSectionSubtitle(AppLocalizations l10n, String body) =>
    '${l10n.formSectionOptionalHint} · $body';

/// Navigates to the full-screen create-exercise form inside [TrainingShell].
void pushTrainingExerciseForm(
  BuildContext context, {
  String initialName = '',
}) {
  final uri = Uri(
    path: RoutePaths.trainingExerciseNew,
    queryParameters:
        initialName.isEmpty ? null : {'name': initialName},
  );
  context.push(uri.toString());
}

/// Full-screen form to create a user-defined exercise.
///
/// Rendered inside [TrainingShell]. Grouped into section cards matching
/// [ProgramFormScreen] (header on background, fields in [Card]).
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.initialName = ''});

  final String initialName;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  MuscleGroup _selectedGroup = MuscleGroup.chest;
  ExerciseType _selectedType = ExerciseType.strength;
  bool _isIsometric = false;
  MovementPattern? _selectedMovementPattern;
  final List<({TargetMuscle muscle, MuscleRegion? region})> _primaryMuscles =
      [];
  final List<({TargetMuscle muscle, MuscleRegion? region})> _secondaryMuscles =
      [];
  String _primaryMuscleQuery = '';
  String _secondaryMuscleQuery = '';
  bool _isSaving = false;
  bool _dirty = false;

  /// When non-null, shows similar-name review instead of the form.
  List<Exercise>? _pendingSimilarReview;

  @override
  void initState() {
    super.initState();
    if (widget.initialName.isNotEmpty) {
      _nameController.text = widget.initialName;
      _dirty = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _touchDirty() {
    if (!_dirty) setState(() => _dirty = true);
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

  Future<void> _onCancel() async {
    if (!_dirty && _pendingSimilarReview == null) {
      context.pop();
      return;
    }
    final discard = await confirmDiscardUnsavedEdits(context);
    if (!mounted) return;
    if (discard) context.pop();
  }

  Widget _buildSimilarReview(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
    List<Exercise> similar,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AthlosSection(
          title: l10n.exerciseSimilarTitle,
          icon: Icons.warning_amber_rounded,
          trailing: IconButton(
            onPressed: () => setState(() => _pendingSimilarReview = null),
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.back,
          ),
        ),
        const Gap(AthlosSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.exerciseSimilarMessage,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const Gap(AthlosSpacing.md),
                for (var i = 0; i < similar.length; i++) ...[
                  if (i > 0) const Gap(AthlosSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.fitness_center,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const Gap(AthlosSpacing.xs),
                      Expanded(
                        child: Text(
                          localizedExerciseName(
                            similar[i].name,
                            isVerified: similar[i].isVerified,
                            l10n: l10n,
                          ),
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameSection(AppLocalizations l10n) {
    return ProgramSettingsSectionCard(
      icon: Icons.badge_outlined,
      title: l10n.exerciseNameLabel,
      child: TextFormField(
        controller: _nameController,
        decoration: InputDecoration(hintText: l10n.exerciseNameLabel),
        textCapitalization: TextCapitalization.words,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: true,
        onChanged: (_) => _touchDirty(),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return l10n.fieldRequired;
          }
          final exercises = ref.watch(exerciseListProvider).value;
          if (exercises == null) return null;
          final conflict = ExerciseNameMatch.findConflict(value, exercises);
          if (conflict != null) {
            final display = localizedExerciseName(
              conflict.name,
              isVerified: conflict.isVerified,
              l10n: l10n,
            );
            return l10n.exerciseDuplicateWithName(display);
          }
          return null;
        },
      ),
    );
  }

  Widget _buildClassificationSection(AppLocalizations l10n) {
    return ProgramSettingsSectionCard(
      icon: Icons.category_outlined,
      title: l10n.exerciseFormSectionClassification,
      subtitle: l10n.exerciseFormSectionClassificationSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _selectedGroup,
            decoration: InputDecoration(
              labelText: l10n.exerciseMuscleGroupLabel,
            ),
            items: MuscleGroup.values.map((group) {
              return DropdownMenuItem(
                value: group,
                child: Text(localizedMuscleGroupName(group, l10n)),
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
          Text(
            l10n.exerciseDetailType,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const Gap(AthlosSpacing.sm),
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
              title: Text(_optionalFieldLabel(l10n, l10n.isometricLabel)),
              subtitle: Text(l10n.isometricHint),
              value: _isIsometric,
              onChanged: (v) {
                _touchDirty();
                setState(() => _isIsometric = v);
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMusclesSection(AppLocalizations l10n, ColorScheme colorScheme) {
    return ProgramSettingsSectionCard(
      icon: Icons.accessibility_new_outlined,
      title: l10n.exerciseDetailTargetMuscles,
      subtitle: _optionalSectionSubtitle(
        l10n,
        l10n.exerciseFormSectionMusclesSubtitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMusclePicker(
            label: l10n.primaryMusclesLabel,
            muscles: _primaryMuscles,
            excludedMuscles: _secondaryMuscles.map((m) => m.muscle).toSet(),
            query: _primaryMuscleQuery,
            onQueryChanged: (value) {
              _touchDirty();
              setState(() => _primaryMuscleQuery = value);
            },
            l10n: l10n,
          ),
          const Gap(AthlosSpacing.lg),
          _buildMusclePicker(
            label: l10n.secondaryMusclesLabel,
            muscles: _secondaryMuscles,
            excludedMuscles: _primaryMuscles.map((m) => m.muscle).toSet(),
            query: _secondaryMuscleQuery,
            onQueryChanged: (value) {
              _touchDirty();
              setState(() => _secondaryMuscleQuery = value);
            },
            l10n: l10n,
          ),
          ..._buildRegionDropdowns(l10n, colorScheme),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return ProgramSettingsSectionCard(
      icon: Icons.notes_outlined,
      title: l10n.exerciseFormSectionDetails,
      subtitle: _optionalSectionSubtitle(
        l10n,
        l10n.exerciseFormSectionDetailsSubtitle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<MovementPattern?>(
            initialValue: _selectedMovementPattern,
            decoration: InputDecoration(
              labelText: _optionalFieldLabel(l10n, l10n.movementPatternLabel),
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
              labelText: _optionalFieldLabel(l10n, l10n.exerciseDescriptionLabel),
              hintText: l10n.exerciseDescriptionHint,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _touchDirty(),
          ),
        ],
      ),
    );
  }

  Widget _buildMusclePicker({
    required String label,
    required List<({TargetMuscle muscle, MuscleRegion? region})> muscles,
    required Set<TargetMuscle> excludedMuscles,
    required String query,
    required ValueChanged<String> onQueryChanged,
    required AppLocalizations l10n,
  }) {
    final selectedSet = muscles.map((m) => m.muscle).toSet();
    final normalizedQuery = query.trim().toLowerCase();
    final available =
        TargetMuscle.values.where((m) {
          if (m.muscleGroup == MuscleGroup.cardio ||
              m.muscleGroup == MuscleGroup.fullBody) {
            return false;
          }
          if (excludedMuscles.contains(m) || selectedSet.contains(m)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => localizedTargetMuscle(
            a,
            l10n,
          ).compareTo(localizedTargetMuscle(b, l10n)),
        );

    final filtered = normalizedQuery.isEmpty
        ? const <TargetMuscle>[]
        : available.where((m) {
            final name = localizedTargetMuscle(m, l10n).toLowerCase();
            return name.contains(normalizedQuery);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const Gap(AthlosSpacing.sm),
        if (muscles.isNotEmpty) ...[
          Wrap(
            spacing: AthlosSpacing.xs,
            runSpacing: AthlosSpacing.xs,
            children: muscles.map((focus) {
              return InputChip(
                label: Text(localizedTargetMuscle(focus.muscle, l10n)),
                onDeleted: () {
                  _touchDirty();
                  setState(() {
                    muscles.removeWhere((f) => f.muscle == focus.muscle);
                  });
                },
              );
            }).toList(),
          ),
          const Gap(AthlosSpacing.sm),
        ],
        TextField(
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: l10n.searchMuscles,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => onQueryChanged(''),
                  )
                : null,
            isDense: true,
          ),
          onChanged: onQueryChanged,
        ),
        if (query.trim().isNotEmpty && filtered.isNotEmpty) ...[
          const Gap(AthlosSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final muscle = filtered[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.sm,
                  ),
                  title: Text(localizedTargetMuscle(muscle, l10n)),
                  onTap: () {
                    _touchDirty();
                    setState(() {
                      muscles.add((muscle: muscle, region: null));
                    });
                    onQueryChanged('');
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildRegionDropdowns(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final all = [..._primaryMuscles, ..._secondaryMuscles];
    final musclesWithRegions = all
        .where((f) => f.muscle.validRegions.isNotEmpty)
        .toList();

    if (musclesWithRegions.isEmpty) return [];

    return [
      const Gap(AthlosSpacing.lg),
      Text(
        _optionalFieldLabel(l10n, l10n.exerciseDetailMuscleRegion),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const Gap(AthlosSpacing.sm),
      ...musclesWithRegions.map((focus) {
        final inPrimary = _primaryMuscles.any((f) => f.muscle == focus.muscle);
        final list = inPrimary ? _primaryMuscles : _secondaryMuscles;
        final idx = list.indexWhere((f) => f.muscle == focus.muscle);
        return Padding(
          padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
          child: DropdownButtonFormField<MuscleRegion?>(
            initialValue: focus.region,
            decoration: InputDecoration(
              labelText: _optionalFieldLabel(
                l10n,
                l10n.muscleWithSeparator(
                  localizedTargetMuscle(focus.muscle, l10n),
                  l10n.muscleRegionLabel,
                ),
              ),
            ),
            items: [
              DropdownMenuItem<MuscleRegion?>(
                value: null,
                child: Text(
                  '—',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
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

  Widget _buildFormIntro(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      l10n.addExerciseFormIntro,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }

  List<Widget> _buildFormSections(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return [
      _buildFormIntro(context, l10n),
      const Gap(AthlosSpacing.md),
      _buildNameSection(l10n),
      const Gap(AthlosSpacing.md),
      _buildClassificationSection(l10n),
      const Gap(AthlosSpacing.md),
      _buildMusclesSection(l10n, colorScheme),
      const Gap(AthlosSpacing.md),
      _buildDetailsSection(l10n, colorScheme),
    ];
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;
    final exercises =
        ref.read(exerciseListProvider).value ?? const <Exercise>[];
    final similar = ExerciseNameMatch.findSimilar(
      _nameController.text,
      exercises,
      displayLabel: (e) =>
          localizedExerciseName(e.name, isVerified: e.isVerified, l10n: l10n),
    );
    if (similar.isNotEmpty) {
      FocusScope.of(context).unfocus();
      setState(() {
        _pendingSimilarReview = similar;
        _dirty = true;
      });
      return;
    }
    await _executeCreate();
  }

  Future<void> _onCreateAnyway() async {
    await _executeCreate();
  }

  Future<void> _executeCreate() async {
    setState(() => _isSaving = true);

    try {
      final description = _descriptionController.text.trim();

      await ref
          .read(exerciseListProvider.notifier)
          .addCustomExercise(
            name: _nameController.text.trim(),
            muscleGroup: _selectedGroup,
            type: _selectedType,
            movementPattern: _selectedMovementPattern,
            description: description.isEmpty ? null : description,
            isIsometric: _isIsometric,
            muscles: _allMuscles,
          );

      if (mounted) {
        context.pop();
      }
    } on ConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exerciseDuplicateGeneric,
            ),
          ),
        );
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final similar = _pendingSimilarReview;

    ref.listen(exerciseListProvider, (previous, next) {
      if (next.hasValue && mounted) {
        _formKey.currentState?.validate();
      }
    });

    return ConfirmNavigationScope(
      guardActive: _dirty || similar != null,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      onLeaveConfirmed: (ctx) {
        if (ctx.mounted) ctx.pop();
      },
      child: Column(
        children: [
          Expanded(
            child: similar != null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AthlosSpacing.md,
                      AthlosSpacing.sm,
                      AthlosSpacing.md,
                      AthlosSpacing.md,
                    ),
                    children: [
                      _buildSimilarReview(
                        l10n,
                        textTheme,
                        colorScheme,
                        similar,
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AthlosSpacing.md,
                        AthlosSpacing.sm,
                        AthlosSpacing.md,
                        AthlosSpacing.md,
                      ),
                      children: _buildFormSections(l10n, colorScheme),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AthlosSpacing.md,
                AthlosSpacing.sm,
                AthlosSpacing.md,
                AthlosSpacing.sm,
              ),
              child: similar != null
                  ? AthlosStackedActions(
                      children: [
                        TextButton(
                          style: AthlosScreenButtonStyles.stackedGhost(
                            context,
                          ),
                          onPressed: _isSaving ? null : _onCancel,
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          style: AthlosScreenButtonStyles.stackedFilled(
                            context,
                          ),
                          onPressed: _isSaving ? null : _onCreateAnyway,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.exerciseCreateAnyway),
                        ),
                      ],
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AthlosButtonSizes.screenMinHeight,
                        ),
                      ),
                      onPressed: _isSaving ? null : _onSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.save),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
