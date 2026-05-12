import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/training_metrics_provider.dart';

/// Dedicated screen listing personal records across all exercises.
class PRHistoryScreen extends ConsumerWidget {
  const PRHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final prsAsync = ref.watch(allExercisePRsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prHistoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.prTooltip,
            onPressed: () => showAthlosDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.prHistoryTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Text(l10n.prHistoryDescription)],
                ),
                actions: [
                  AthlosStackedDialogActions(
                    children: [
                      FilledButton(
                        style: AthlosDialogButtonStyles.stackedFilled(
                          dialogContext,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.okButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: prsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (prs) {
          if (prs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.xl),
                child: Text(
                  l10n.prHistoryEmpty,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Group by muscle group.
          final grouped = <String, List<ExercisePRRecord>>{};
          for (final pr in prs) {
            grouped.putIfAbsent(pr.muscleGroup, () => []).add(pr);
          }
          final groups = grouped.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          return ListView.builder(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            itemCount: groups.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                  child: Text(
                    l10n.prHistorySubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final idx = i - 1;
              final group = groups[idx];
              final groupEnum = MuscleGroup.values
                  .where((g) => g.name == group.key)
                  .firstOrNull;
              final groupLabel = groupEnum != null
                  ? localizedMuscleGroupName(groupEnum, l10n)
                  : group.key;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) const Gap(AthlosSpacing.md),
                  Text(
                    groupLabel,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const Gap(AthlosSpacing.xs),
                  ...group.value.map((pr) => _PRTile(pr: pr)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PRTile extends StatelessWidget {
  final ExercisePRRecord pr;

  const _PRTile({required this.pr});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = localizedExerciseName(
      pr.exerciseName,
      isVerified: pr.isVerified,
      l10n: l10n,
    );

    final weightStr = pr.weight % 1 == 0
        ? pr.weight.toInt().toString()
        : pr.weight.toStringAsFixed(1);
    final e1rmStr = pr.best1RM % 1 == 0
        ? pr.best1RM.toInt().toString()
        : pr.best1RM.toStringAsFixed(1);

    return Card(
      child: ListTile(
        minTileHeight: AthlosComponentSizes.listItemMinHeight,
        leading: Icon(
          Icons.emoji_events,
          color: colorScheme.tertiary,
          size: 28,
        ),
        title: Text(name),
        subtitle: Text(
          '$weightStr kg × ${pr.reps}  •  ${l10n.prEstimated1rm(e1rmStr)}',
          style: textTheme.bodySmall,
        ),
        onTap: () =>
            context.push('${RoutePaths.trainingExercises}/${pr.exerciseId}'),
      ),
    );
  }
}
