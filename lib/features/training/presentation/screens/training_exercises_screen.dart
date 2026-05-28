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
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../widgets/exercise_catalog_filters.dart';
import '../widgets/exercise_tile.dart';
import 'exercise_form_screen.dart';

final _placeholderExercises = List.generate(
  8,
  (i) => Exercise(
    id: 'placeholder-$i',
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
  ExerciseCatalogSourceFilter _sourceFilter = ExerciseCatalogSourceFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  int get _catalogActiveFilterCount {
    var count = 0;
    if (_selectedGroup != null) count++;
    if (_sourceFilter != ExerciseCatalogSourceFilter.all) count++;
    return count;
  }

  Future<void> _openCatalogFilters(AppLocalizations l10n) {
    return showExerciseCatalogFiltersSheet(
      context: context,
      l10n: l10n,
      initialMuscleGroup: _selectedGroup,
      initialSource: _sourceFilter,
      onApply: (muscle, source) {
        setState(() {
          _selectedGroup = muscle;
          _sourceFilter = source;
        });
      },
    );
  }

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
                suffixIcon: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    Tooltip(
                      message: _catalogActiveFilterCount > 0
                          ? '${l10n.exerciseCatalogFiltersButton} ($_catalogActiveFilterCount)'
                          : l10n.exerciseCatalogFiltersButton,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _openCatalogFilters(l10n),
                        icon: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            if (_catalogActiveFilterCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const SizedBox.square(dimension: 8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                suffixIconConstraints: BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                  maxHeight: kMinInteractiveDimension,
                  minWidth:
                      (_searchQuery.isNotEmpty ? 2 : 1) *
                      kMinInteractiveDimension,
                ),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AthlosRadius.mdAll),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
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
                          onPressed: () => pushTrainingExerciseForm(
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
                      onTap: isLoading || exercise.id.trim().isEmpty
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

    switch (_sourceFilter) {
      case ExerciseCatalogSourceFilter.all:
        break;
      case ExerciseCatalogSourceFilter.verifiedOnly:
        filtered = filtered.where((e) => e.isVerified).toList();
        break;
      case ExerciseCatalogSourceFilter.customOnly:
        filtered = filtered.where((e) => !e.isVerified).toList();
        break;
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
          isVerified: e.isVerified,
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
