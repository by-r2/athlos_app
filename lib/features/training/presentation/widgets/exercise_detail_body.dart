import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/muscle_role.dart';
import '../helpers/exercise_l10n.dart';
import '../helpers/load_mode_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/training_metrics_provider.dart';
import 'program_settings_section_card.dart';

/// Scrollable body for [ExerciseDetailScreen]: header, specs, PR, variations.
class ExerciseDetailBody extends ConsumerWidget {
  const ExerciseDetailBody({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      children: [
        _ExerciseDetailHeader(exercise: exercise),
        const Gap(AthlosSpacing.lg),
        _ExercisePerformanceSection(exerciseId: exercise.id),
        const Gap(AthlosSpacing.lg),
        _ExerciseClassificationSection(exercise: exercise),
        const Gap(AthlosSpacing.lg),
        _ExerciseMusclesSection(exercise: exercise),
        if (!exercise.isCardio) ...[
          const Gap(AthlosSpacing.lg),
          _ExerciseLoadSection(exercise: exercise),
        ],
        if (exercise.description != null && exercise.description!.isNotEmpty) ...[
          const Gap(AthlosSpacing.lg),
          _ExerciseDescriptionSection(description: exercise.description!),
        ],
        const Gap(AthlosSpacing.lg),
        _ExerciseVariationsSection(exerciseId: exercise.id),
        const Gap(AthlosSpacing.md),
      ],
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────

class _ExerciseDetailHeader extends StatelessWidget {
  const _ExerciseDetailHeader({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final chips = <Widget>[
      _HeaderChip(
        icon: exercise.isVerified
            ? Icons.verified_outlined
            : Icons.person_outline,
        label: exercise.isVerified
            ? l10n.conflictCenterVerifiedBadge
            : l10n.exerciseCatalogFilterSourceCustom,
        color: exercise.isVerified
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
      ),
      _HeaderChip(
        icon: exercise.type == ExerciseType.strength
            ? Icons.fitness_center_outlined
            : Icons.directions_run_outlined,
        label: exercise.type == ExerciseType.strength
            ? l10n.exerciseTypeStrength
            : l10n.exerciseTypeCardio,
      ),
      if (exercise.isIsometric)
        _HeaderChip(icon: Icons.timer_outlined, label: l10n.isometricLabel),
      if (!exercise.isCardio)
        _HeaderChip(
          icon: Icons.scale_outlined,
          label: localizedLoadModeShort(exercise.defaultLoadMode, l10n),
        ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AthlosRadius.mdAll,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AthlosSpacing.xs,
              runSpacing: AthlosSpacing.xs,
              children: chips,
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              localizedMuscleGroupName(exercise.muscleGroup, l10n),
              style: textTheme.titleSmall,
            ),
            if (exercise.movementPattern != null) ...[
              const Gap(AthlosSpacing.xxs),
              Text(
                localizedMovementPattern(exercise.movementPattern!, l10n),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.sm,
        vertical: AthlosSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: AthlosRadius.smAll,
        border: Border.all(color: chipColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const Gap(AthlosSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spec rows ────────────────────────────────────────────────────────

class _DetailSpecRow extends StatelessWidget {
  const _DetailSpecRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Gap(AthlosSpacing.sm),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

List<Widget> _specRowsFromEntries(List<({String label, String value})> entries) {
  return [
    for (var i = 0; i < entries.length; i++)
      _DetailSpecRow(
        label: entries[i].label,
        value: entries[i].value,
        isLast: i == entries.length - 1,
      ),
  ];
}

// ── Classification ───────────────────────────────────────────────────

class _ExerciseClassificationSection extends StatelessWidget {
  const _ExerciseClassificationSection({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final typeLabel = exercise.type == ExerciseType.strength
        ? l10n.exerciseTypeStrength
        : l10n.exerciseTypeCardio;

    final movementLabel = exercise.movementPattern != null
        ? localizedMovementPattern(exercise.movementPattern!, l10n)
        : l10n.exerciseDetailValueNotSet;

    final sourceLabel = exercise.isVerified
        ? l10n.exerciseCatalogFilterSourceVerified
        : l10n.exerciseCatalogFilterSourceCustom;

    final entries = <({String label, String value})>[
      (label: l10n.exerciseDetailSourceLabel, value: sourceLabel),
      (
        label: l10n.exerciseDetailMuscleGroup,
        value: localizedMuscleGroupName(exercise.muscleGroup, l10n),
      ),
      (label: l10n.exerciseDetailType, value: typeLabel),
      (label: l10n.movementPatternLabel, value: movementLabel),
    ];

    if (exercise.type == ExerciseType.strength) {
      entries.add((
        label: l10n.isometricLabel,
        value: exercise.isIsometric ? l10n.yes : l10n.no,
      ));
    }

    return ProgramSettingsSectionCard(
      icon: Icons.category_outlined,
      title: l10n.exerciseFormSectionClassification,
      subtitle: l10n.exerciseFormSectionClassificationSubtitle,
      child: Column(children: _specRowsFromEntries(entries)),
    );
  }
}

// ── Muscles ──────────────────────────────────────────────────────────

class _ExerciseMusclesSection extends StatelessWidget {
  const _ExerciseMusclesSection({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final primary = exercise.muscles
        .where((m) => m.role == MuscleRole.primary)
        .toList();
    final secondary = exercise.muscles
        .where((m) => m.role == MuscleRole.secondary)
        .toList();

    Widget? musclesChild;
    if (exercise.muscles.isEmpty) {
      musclesChild = Text(
        l10n.exerciseDetailMusclesEmpty,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      musclesChild = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primary.isNotEmpty)
            _MuscleRoleBlock(
              title: l10n.primaryMusclesLabel,
              muscles: primary,
            ),
          if (primary.isNotEmpty && secondary.isNotEmpty)
            const Gap(AthlosSpacing.md),
          if (secondary.isNotEmpty)
            _MuscleRoleBlock(
              title: l10n.secondaryMusclesLabel,
              muscles: secondary,
            ),
        ],
      );
    }

    return ProgramSettingsSectionCard(
      icon: Icons.accessibility_new_outlined,
      title: l10n.exerciseDetailTargetMuscles,
      subtitle: l10n.exerciseFormSectionMusclesSubtitle,
      child: musclesChild,
    );
  }
}

class _MuscleRoleBlock extends StatelessWidget {
  const _MuscleRoleBlock({required this.title, required this.muscles});

  final String title;
  final List<ExerciseMuscleFocus> muscles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.xs),
        ...muscles.map((focus) => _MuscleFocusTile(focus: focus, l10n: l10n)),
      ],
    );
  }
}

class _MuscleFocusTile extends StatelessWidget {
  const _MuscleFocusTile({required this.focus, required this.l10n});

  final ExerciseMuscleFocus focus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final muscleName = localizedTargetMuscle(focus.muscle, l10n);
    final subtitle = focus.region != null
        ? localizedMuscleRegion(focus.region!, l10n)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.xs),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: focus.role == MuscleRole.primary
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          const Gap(AthlosSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(muscleName, style: textTheme.bodyMedium),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Load ─────────────────────────────────────────────────────────────

class _ExerciseLoadSection extends StatelessWidget {
  const _ExerciseLoadSection({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final entries = <({String label, String value})>[
      (
        label: l10n.workoutFormLoadModeFieldLabel,
        value: localizedLoadModeOptionTitle(exercise.defaultLoadMode, l10n),
      ),
    ];

    if (exercise.bodyweightLoadFactor != null) {
      final percent = (exercise.bodyweightLoadFactor! * 100).round();
      entries.add((
        label: l10n.exerciseDetailBodyweightFactor,
        value: l10n.exerciseDetailBodyweightFactorValue('$percent'),
      ));
    }

    if (exercise.supportsLoadModeOverride) {
      entries.add((
        label: l10n.exerciseDetailLoadModeAdjustable,
        value: l10n.exerciseDetailLoadModeAdjustableValue,
      ));
    }

    return ProgramSettingsSectionCard(
      icon: Icons.scale_outlined,
      title: l10n.exerciseDetailSectionLoad,
      subtitle: l10n.exerciseDetailSectionLoadSubtitle,
      child: Column(children: _specRowsFromEntries(entries)),
    );
  }
}

// ── Description ──────────────────────────────────────────────────────

class _ExerciseDescriptionSection extends StatelessWidget {
  const _ExerciseDescriptionSection({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ProgramSettingsSectionCard(
      icon: Icons.notes_outlined,
      title: l10n.exerciseDescriptionLabel,
      child: Text(
        description,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.45,
        ),
      ),
    );
  }
}

// ── Performance (PR) ───────────────────────────────────────────────────

class _ExercisePerformanceSection extends ConsumerWidget {
  const _ExercisePerformanceSection({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prAsync = ref.watch(exercisePRProvider(exerciseId));

    return prAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pr) {
        if (pr == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final e1rmStr = pr.best1RM.toStringAsFixed(1);
        final weightStr = pr.weight % 1 == 0
            ? pr.weight.toInt().toString()
            : pr.weight.toStringAsFixed(1);

        return ProgramSettingsSectionCard(
          icon: Icons.emoji_events_outlined,
          title: l10n.exerciseDetailSectionPerformance,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AthlosRadius.smAll,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: colorScheme.primary, size: 32),
                  const Gap(AthlosSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.prBadge,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.prEstimated1rm(e1rmStr),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          l10n.prBestSet(weightStr, pr.reps),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.show_chart,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    tooltip: l10n.loadChartTitle,
                    onPressed: () => context.push(
                      RoutePaths.trainingExerciseLoadChart(exerciseId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Variations ─────────────────────────────────────────────────────────

class _ExerciseVariationsSection extends ConsumerWidget {
  const _ExerciseVariationsSection({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final variationsAsync = ref.watch(exerciseVariationsProvider(exerciseId));

    return ProgramSettingsSectionCard(
      icon: Icons.swap_horiz_outlined,
      title: l10n.exerciseDetailVariations,
      child: variationsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AthlosSpacing.md),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => Text(
          l10n.genericError,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
        ),
        data: (variations) {
          if (variations.isEmpty) {
            return Text(
              l10n.exerciseNoVariations,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            );
          }

          return Column(
            children: [
              for (var i = 0; i < variations.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                _VariationTile(variation: variations[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _VariationTile extends StatelessWidget {
  const _VariationTile({required this.variation});

  final Exercise variation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = localizedExerciseName(
      variation.name,
      isVerified: variation.isVerified,
      l10n: l10n,
    );

    return InkWell(
      onTap: () => context.push('${RoutePaths.trainingExercises}/${variation.id}'),
      borderRadius: AthlosRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: textTheme.bodyMedium),
                  const Gap(AthlosSpacing.xxs),
                  Text(
                    localizedMuscleGroupName(variation.muscleGroup, l10n),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
