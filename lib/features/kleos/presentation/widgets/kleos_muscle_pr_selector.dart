import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training/domain/enums/muscle_group.dart';
import '../../../training/presentation/helpers/exercise_l10n.dart';
import '../../../training/presentation/providers/training_metrics_provider.dart';

/// Horizontal chip picker for muscle groups; PR detail below.
class KleosMusclePrSelector extends StatefulWidget {
  const KleosMusclePrSelector({
    super.key,
    required this.l10n,
    required this.entries,
    required this.allPrs,
  });

  final AppLocalizations l10n;
  final List<MapEntry<String, ExercisePRRecord>> entries;
  final List<ExercisePRRecord> allPrs;

  @override
  State<KleosMusclePrSelector> createState() => _KleosMusclePrSelectorState();
}

class _KleosMusclePrSelectorState extends State<KleosMusclePrSelector> {
  String? _selectedKey;

  static String _localizedMuscle(
    AppLocalizations l10n,
    String muscleGroupKey,
  ) {
    final enumMatch = MuscleGroup.values
        .where((g) => g.name == muscleGroupKey)
        .firstOrNull;
    return enumMatch != null
        ? localizedMuscleGroupName(enumMatch, l10n)
        : muscleGroupKey;
  }

  @override
  void initState() {
    super.initState();
    if (widget.entries.isNotEmpty) {
      _selectedKey = widget.entries.first.key;
    }
  }

  @override
  void didUpdateWidget(covariant KleosMusclePrSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.isEmpty) {
      if (_selectedKey != null) {
        _selectedKey = null;
      }
      return;
    }
    final stillValid =
        _selectedKey != null &&
        widget.entries.any((e) => e.key == _selectedKey);
    if (!stillValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedKey = widget.entries.first.key;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.entries.isEmpty || _selectedKey == null) {
      return const SizedBox.shrink();
    }

    ExercisePRRecord? bestLift;
    for (final MapEntry<String, ExercisePRRecord> e in widget.entries) {
      if (e.key == _selectedKey) {
        bestLift = e.value;
        break;
      }
    }
    if (bestLift == null) return const SizedBox.shrink();

    final selected = bestLift;
    final prCount =
        widget.allPrs.where((p) => p.muscleGroup == _selectedKey).length;

    final name = localizedExerciseName(
      selected.exerciseName,
      isVerified: selected.isVerified,
      l10n: widget.l10n,
    );

    final weightStr = selected.weight % 1 == 0
        ? selected.weight.toInt().toString()
        : selected.weight.toStringAsFixed(1);
    final e1rmStr = selected.best1RM % 1 == 0
        ? selected.best1RM.toInt().toString()
        : selected.best1RM.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.entries.map((MapEntry<String, ExercisePRRecord> e) {
              final label = _localizedMuscle(widget.l10n, e.key);
              final isSelected = e.key == _selectedKey;
              return Padding(
                padding: const EdgeInsets.only(right: AthlosSpacing.xs),
                child: FilterChip(
                  key: ValueKey<String>(e.key),
                  label: Text(label),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedKey = e.key),
                  labelStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  selectedColor: colorScheme.primaryContainer,
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Gap(AthlosSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(
              '${RoutePaths.trainingExercises}/${selected.exerciseId}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AthlosSpacing.smd),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer
                              .withValues(alpha: 0.65),
                          borderRadius: AthlosRadius.mdAll,
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          color: colorScheme.tertiary,
                          size: 28,
                        ),
                      ),
                      const Gap(AthlosSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(AthlosSpacing.xxs),
                            Text(
                              '$weightStr kg × ${selected.reps}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Gap(AthlosSpacing.xxs),
                            Text(
                              widget.l10n.kleosPrCountInMuscle(prCount),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.l10n.kleosMuscleEstimated1rmValue(e1rmStr),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            widget.l10n.kleosMuscleEstimated1rmLegend,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Gap(AthlosSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const Gap(AthlosSpacing.xxs),
                      Text(
                        widget.l10n.kleosOpenExerciseHint,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
