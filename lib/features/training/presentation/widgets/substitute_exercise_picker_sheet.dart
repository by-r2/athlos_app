import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';

final _placeholderExercises = List.generate(
  4,
  (i) => Exercise(
    id: 'placeholder-$i',
    name: 'Placeholder exercise',
    muscleGroup: MuscleGroup.chest,
    isVerified: true,
  ),
);

/// Picker for substituting a workout line: variations first, then full catalog search.
Future<Exercise?> showSubstituteExercisePickerSheet(
  BuildContext context, {
  required String sourceExerciseId,
  required Set<String> alreadyInWorkoutCatalogIds,
}) =>
    showAthlosModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      wrapInShell: false,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => AthlosBottomSheetShell(
          expand: true,
          child: Expanded(
            child: _SubstituteExercisePickerBody(
              sheetContext: sheetContext,
              scrollController: scrollController,
              sourceExerciseId: sourceExerciseId,
              alreadyInWorkoutCatalogIds: alreadyInWorkoutCatalogIds,
            ),
          ),
        ),
      ),
    );

class _SubstituteExercisePickerBody extends ConsumerStatefulWidget {
  final BuildContext sheetContext;
  final ScrollController scrollController;
  final String sourceExerciseId;
  final Set<String> alreadyInWorkoutCatalogIds;

  const _SubstituteExercisePickerBody({
    required this.sheetContext,
    required this.scrollController,
    required this.sourceExerciseId,
    required this.alreadyInWorkoutCatalogIds,
  });

  @override
  ConsumerState<_SubstituteExercisePickerBody> createState() =>
      _SubstituteExercisePickerBodyState();
}

class _SubstituteExercisePickerBodyState
    extends ConsumerState<_SubstituteExercisePickerBody> {
  final _searchController = TextEditingController();
  String _query = '';
  MuscleGroup? _selectedGroup;

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
    final variationsAsync = ref.watch(
      exerciseVariationsProvider(widget.sourceExerciseId),
    );

    return Column(
      children: [
        AthlosBottomSheetHeader(title: l10n.executionSubstitutePickerTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.searchExercises,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: AthlosSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
            children: [
              FilterChip(
                label: Text(l10n.filterAll),
                selected: _selectedGroup == null,
                onSelected: (_) => setState(() => _selectedGroup = null),
              ),
              const SizedBox(width: AthlosSpacing.xs),
              ...MuscleGroup.values.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                  child: FilterChip(
                    label: Text(localizedMuscleGroupName(g, l10n)),
                    selected: _selectedGroup == g,
                    onSelected: (_) => setState(() => _selectedGroup = g),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AthlosSpacing.sm),
        Expanded(
          child: () {
            if (exercisesAsync.hasError) {
              return Center(child: Text('${exercisesAsync.error}'));
            }

            final allExercises = exercisesAsync.value ?? _placeholderExercises;
            final isLoading =
                exercisesAsync.isLoading || variationsAsync.isLoading;

            final variations = variationsAsync.value ?? const <Exercise>[];
            final variationIds = variations.map((e) => e.id).toSet();

            final filteredCatalog = allExercises.where((ex) {
              if (variationIds.contains(ex.id)) return false;
              if (_selectedGroup != null && ex.muscleGroup != _selectedGroup) {
                return false;
              }
              if (!exerciseCatalogSearchMatches(
                localizedDisplay: localizedExerciseName(
                  ex.name,
                  isVerified: ex.isVerified,
                  l10n: l10n,
                ),
                canonicalKey: ex.name,
                isVerified: ex.isVerified,
                rawQuery: _query,
              )) {
                return false;
              }
              return true;
            }).toList();

            final filteredVariations = variations.where((ex) {
              if (_selectedGroup != null && ex.muscleGroup != _selectedGroup) {
                return false;
              }
              if (!exerciseCatalogSearchMatches(
                localizedDisplay: localizedExerciseName(
                  ex.name,
                  isVerified: ex.isVerified,
                  l10n: l10n,
                ),
                canonicalKey: ex.name,
                isVerified: ex.isVerified,
                rawQuery: _query,
              )) {
                return false;
              }
              return true;
            }).toList();

            final showVariations =
                _query.isEmpty && filteredVariations.isNotEmpty;

            if (!isLoading &&
                filteredVariations.isEmpty &&
                filteredCatalog.isEmpty) {
              return Center(
                child: Text(
                  l10n.emptyExercises,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return Skeletonizer(
              enabled: isLoading,
              child: ListView(
                controller: widget.scrollController,
                children: [
                  if (showVariations) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AthlosSpacing.md,
                        AthlosSpacing.xs,
                        AthlosSpacing.md,
                        AthlosSpacing.xs,
                      ),
                      child: Text(
                        l10n.executionSubstituteVariationsSection,
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...filteredVariations.map(
                      (ex) => _pickerTile(
                        ex: ex,
                        l10n: l10n,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const Divider(height: AthlosSpacing.lg),
                  ],
                  ...filteredCatalog.map(
                    (ex) => _pickerTile(
                      ex: ex,
                      l10n: l10n,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ),
                ],
              ),
            );
          }(),
        ),
      ],
    );
  }

  Widget _pickerTile({
    required Exercise ex,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final displayName = localizedExerciseName(
      ex.name,
      isVerified: ex.isVerified,
      l10n: l10n,
    );
    final groupName = localizedMuscleGroupName(ex.muscleGroup, l10n);
    final isInWorkout = widget.alreadyInWorkoutCatalogIds.contains(ex.id);

    return ListTile(
      minTileHeight: AthlosComponentSizes.listItemMinHeight,
      enabled: !isInWorkout,
      title: Text(
        displayName,
        style: isInWorkout
            ? textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: isInWorkout
          ? Text(
              l10n.workoutExerciseInWorkoutPickerLabel,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            )
          : AthlosTruncatedText(groupName, maxLines: 2),
      trailing: Icon(
        isInWorkout ? Icons.check_circle : Icons.swap_horiz,
        color: isInWorkout
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
      onTap: isInWorkout
          ? null
          : () => Navigator.of(widget.sheetContext).pop(ex),
    );
  }
}
