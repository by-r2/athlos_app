import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/exercise_name_match.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
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
        heroTag: 'training_exercises_fab',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                border: OutlineInputBorder(borderRadius: AthlosRadius.mdAll),
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
              final filtered = isLoading
                  ? exercises
                  : _filterExercises(exercises, l10n);
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
                          color: colorScheme.onSurfaceVariant.withAlpha(100),
                        ),
                        const Gap(AthlosSpacing.md),
                        Text(
                          l10n.emptyExercises,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(AthlosSpacing.xs),
                        Text(
                          l10n.emptyExercisesHint,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(AthlosSpacing.lg),
                        FilledButton.icon(
                          onPressed: () => _showAddSheet(
                            context,
                            initialName: _searchQuery.trim().isNotEmpty
                                ? _searchQuery.trim()
                                : '',
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addExercise),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Skeletonizer(
                enabled: isLoading,
                child: ListView.separated(
                  padding: const EdgeInsets.only(
                    bottom: AthlosSpacing.fabClearance,
                  ),
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
                        exercise.muscleGroup,
                        l10n,
                      ),
                      targetMusclesLabel: musclesSummary.isNotEmpty
                          ? musclesSummary
                          : null,
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

  void _showAddSheet(BuildContext context, {String initialName = ''}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddExerciseSheet(initialName: initialName),
    );
  }

  List<Exercise> _filterExercises(
    List<Exercise> exercises,
    AppLocalizations l10n,
  ) {
    var filtered = exercises.toList();

    if (_selectedGroup != null) {
      filtered = filtered
          .where((e) => e.muscleGroup == _selectedGroup)
          .toList();
    }

    final searchTrimmed = _searchQuery.trim();
    if (searchTrimmed.isNotEmpty) {
      filtered = filtered.where((e) {
        return exerciseCatalogSearchMatches(
          localizedDisplay: localizedExerciseName(
            e.name,
            isVerified: e.isVerified,
            l10n: l10n,
          ),
          canonicalKey: e.name,
          rawQuery: _searchQuery,
        );
      }).toList();
    }

    filtered.sort((a, b) {
      final nameA = localizedExerciseName(
        a.name,
        isVerified: a.isVerified,
        l10n: l10n,
      );
      final nameB = localizedExerciseName(
        b.name,
        isVerified: b.isVerified,
        l10n: l10n,
      );
      return nameA.compareTo(nameB);
    });

    return filtered;
  }
}

/// Bottom sheet to create a user-defined exercise with progressive disclosure.
///
/// Visible (required): name, muscle group, type.
/// Collapsible "Advanced details": primary/secondary muscles, regions,
/// movement pattern, description.
class _AddExerciseSheet extends ConsumerStatefulWidget {
  final String initialName;

  const _AddExerciseSheet({this.initialName = ''});

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
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

  /// When non-null, the sheet shows similar-name review instead of the form.
  List<Exercise>? _pendingSimilarReview;

  @override
  void initState() {
    super.initState();
    if (widget.initialName.isNotEmpty) {
      _nameController.text = widget.initialName;
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

    ref.listen(exerciseListProvider, (previous, next) {
      if (next.hasValue && mounted) {
        _formKey.currentState?.validate();
      }
    });

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
                    AthlosSpacing.sm,
                    AthlosSpacing.md,
                    AthlosSpacing.sm,
                    0,
                  ),
                  child: _pendingSimilarReview != null
                      ? Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  setState(() => _pendingSimilarReview = null),
                              icon: const Icon(Icons.arrow_back),
                              tooltip: l10n.back,
                            ),
                            Expanded(
                              child: Text(
                                l10n.exerciseSimilarTitle,
                                style: textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        )
                      : Row(
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
                  child: _pendingSimilarReview != null
                      ? _buildSimilarReview(
                          l10n,
                          textTheme,
                          colorScheme,
                          scrollController,
                          _pendingSimilarReview!,
                        )
                      : ListView(
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
                                final exercises = ref
                                    .watch(exerciseListProvider)
                                    .value;
                                if (exercises == null) return null;
                                final conflict = ExerciseNameMatch.findConflict(
                                  value,
                                  exercises,
                                );
                                if (conflict != null) {
                                  final display = localizedExerciseName(
                                    conflict.name,
                                    isVerified: conflict.isVerified,
                                    l10n: l10n,
                                  );
                                  return l10n.exerciseDuplicateWithName(
                                    display,
                                  );
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
                              onSelectionChanged: (v) => setState(() {
                                _selectedType = v.first;
                                if (_selectedType == ExerciseType.cardio) {
                                  _isIsometric = false;
                                }
                              }),
                            ),
                            if (_selectedType == ExerciseType.strength) ...[
                              const Gap(AthlosSpacing.sm),
                              SwitchListTile(
                                title: Text(l10n.isometricLabel),
                                subtitle: Text(l10n.isometricHint),
                                value: _isIsometric,
                                onChanged: (v) =>
                                    setState(() => _isIsometric = v),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                            const Gap(AthlosSpacing.sm),
                            _buildAdvancedSection(
                              l10n,
                              textTheme,
                              colorScheme,
                            ),
                            const Gap(AthlosSpacing.xl),
                          ],
                        ),
                ),
                if (_pendingSimilarReview != null)
                  Padding(
                    padding: const EdgeInsets.all(AthlosSpacing.md),
                    child: AthlosDialogButtonTheme.wrap(
                      context,
                      AthlosStackedDialogActions(
                        children: [
                          OutlinedButton(
                            style: AthlosDialogButtonStyles.stackedGhost(
                              context,
                            ),
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            style: AthlosDialogButtonStyles.stackedFilled(
                              context,
                            ),
                            onPressed: _isSaving ? null : _onCreateAnyway,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.exerciseCreateAnyway),
                          ),
                        ],
                      ),
                    ),
                  )
                else
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
    );
  }

  Widget _buildSimilarReview(
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
    ScrollController scrollController,
    List<Exercise> similar,
  ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
      children: [
        const Gap(AthlosSpacing.sm),
        Text(
          l10n.exerciseSimilarMessage,
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
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
        const Gap(AthlosSpacing.xl),
      ],
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
          excludedMuscles: _secondaryMuscles.map((m) => m.muscle).toSet(),
          query: _primaryMuscleQuery,
          onQueryChanged: (value) =>
              setState(() => _primaryMuscleQuery = value),
          l10n: l10n,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const Gap(AthlosSpacing.md),
        _buildMuscleSection(
          label: l10n.secondaryMusclesLabel,
          muscles: _secondaryMuscles,
          excludedMuscles: _primaryMuscles.map((m) => m.muscle).toSet(),
          query: _secondaryMuscleQuery,
          onQueryChanged: (value) =>
              setState(() => _secondaryMuscleQuery = value),
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
          onChanged: (v) => setState(() => _selectedMovementPattern = v),
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
    required String query,
    required ValueChanged<String> onQueryChanged,
    required AppLocalizations l10n,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
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
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.xs),
        if (muscles.isNotEmpty) ...[
          Wrap(
            spacing: AthlosSpacing.xs,
            runSpacing: AthlosSpacing.xs,
            children: muscles.map((focus) {
              return InputChip(
                label: Text(localizedTargetMuscle(focus.muscle, l10n)),
                onDeleted: () => setState(() {
                  muscles.removeWhere((f) => f.muscle == focus.muscle);
                }),
              );
            }).toList(),
          ),
          const Gap(AthlosSpacing.sm),
        ],
        TextField(
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
            border: const OutlineInputBorder(),
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
      setState(() => _pendingSimilarReview = similar);
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
        Navigator.of(context).pop();
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
}
