import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_truncated_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';

final _placeholderExercises = List.generate(
  8,
  (i) => Exercise(
    id: 'placeholder-$i',
    name: 'Placeholder exercise',
    muscleGroup: MuscleGroup.chest,
    isVerified: true,
  ),
);

/// Bottom sheet that lets the user search and pick an exercise.
///
/// Returns the selected [Exercise] or `null` if cancelled.
Future<Exercise?> showExercisePickerSheet(BuildContext context) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AthlosRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: _ExercisePickerBody(scrollController: scrollController),
        ),
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

    return Column(
      children: [
        const SizedBox(height: AthlosSpacing.sm),
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: AthlosRadius.xsAll,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Text(l10n.selectExercise, style: textTheme.titleMedium),
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
            final exercises = exercisesAsync.value ?? _placeholderExercises;

            final filtered = exercises.where((ex) {
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

            return Skeletonizer(
              enabled: exercisesAsync.isLoading,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.emptyExercises,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ex = filtered[index];
                        final displayName = localizedExerciseName(
                          ex.name,
                          isVerified: ex.isVerified,
                          l10n: l10n,
                        );
                        final groupName = localizedMuscleGroupName(
                          ex.muscleGroup,
                          l10n,
                        );

                        return ListTile(
                          minTileHeight: AthlosComponentSizes.listItemMinHeight,
                          title: Text(displayName),
                          subtitle: AthlosTruncatedText(groupName, maxLines: 2),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => Navigator.of(context).pop(ex),
                        );
                      },
                    ),
            );
          }(),
        ),
      ],
    );
  }
}
