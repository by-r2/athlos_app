import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/progression_rule.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/program_focus.dart';
import '../../domain/enums/progression_type.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/program_notifier.dart';

/// Advanced settings for a training program: header, progression, deload, actions.
class ProgramDetailScreen extends ConsumerWidget {
  final int programId;

  const ProgramDetailScreen({super.key, required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(programListProvider);
    final program = programsAsync.value
        ?.where((p) => p.id == programId)
        .firstOrNull;

    if (program == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      children: [
        _ProgramHeader(program: program),
        const Gap(AthlosSpacing.lg),
        _ProgressionSection(programId: programId),
        const Gap(AthlosSpacing.lg),
        _DeloadSection(program: program),
        const Gap(AthlosSpacing.lg),
        _ActionsSection(program: program),
        const Gap(AthlosSpacing.fabClearance),
      ],
    );
  }
}

// ── Program Header ───────────────────────────────────────────────────

class _ProgramHeader extends ConsumerWidget {
  final TrainingProgram program;

  const _ProgramHeader({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final focusLabel = switch (program.focus) {
      ProgramFocus.hypertrophy => l10n.programFocusHypertrophy,
      ProgramFocus.strength => l10n.programFocusStrength,
      ProgramFocus.endurance => l10n.programFocusEndurance,
      ProgramFocus.custom => l10n.programFocusCustom,
    };

    final progressAsync = ref.watch(programProgressProvider(program.id));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AthlosRadius.mdAll,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: colorScheme.primary, size: 20),
                const Gap(AthlosSpacing.sm),
                Expanded(
                  child: Text(program.name, style: textTheme.titleMedium),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.sm,
                    vertical: AthlosSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: AthlosRadius.smAll,
                  ),
                  child: Text(
                    focusLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (program.isInDeload) ...[
              const Gap(AthlosSpacing.sm),
              Chip(
                avatar:
                    Icon(Icons.spa, size: 16, color: colorScheme.tertiary),
                label: Text(l10n.deloadActiveChip),
                backgroundColor: colorScheme.tertiaryContainer,
                labelStyle: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
            const Gap(AthlosSpacing.md),
            progressAsync.when(
              data: (progress) => Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.programProgressLabel,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        l10n.programSessionsProgress(
                          progress.completedSessions,
                          progress.totalSessions,
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Gap(AthlosSpacing.xs),
                  ClipRRect(
                    borderRadius: AthlosRadius.smAll,
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progression Section ──────────────────────────────────────────────

class _ProgressionSection extends ConsumerStatefulWidget {
  final int programId;

  const _ProgressionSection({required this.programId});

  @override
  ConsumerState<_ProgressionSection> createState() =>
      _ProgressionSectionState();
}

class _ProgressionSectionState extends ConsumerState<_ProgressionSection> {
  List<ProgressionRule>? _rules;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final repo = ref.read(progressionRuleRepositoryProvider);
    final result = await repo.getByProgram(widget.programId);
    if (mounted && result.isSuccess) {
      setState(() => _rules = result.getOrThrow());
    }
  }

  Future<void> _removeRuleAt(int index) async {
    final rules = [...?_rules];
    rules.removeAt(index);
    setState(() => _rules = rules);
    final repo = ref.read(progressionRuleRepositoryProvider);
    await repo.replaceAllForProgram(widget.programId, rules);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exercises = ref.watch(exerciseListProvider).value ?? [];

    final rules = _rules ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.progressionSectionTitle,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.xs),
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            child: Text(
              l10n.progressionEmptyHint,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...rules.asMap().entries.map((entry) {
          final idx = entry.key;
          final rule = entry.value;
          final exerciseName = exercises
                  .where((e) => e.id == rule.exerciseId)
                  .map((e) => localizedExerciseName(
                        e.name,
                        isVerified: e.isVerified,
                        l10n: l10n,
                      ))
                  .firstOrNull ??
              '#${rule.exerciseId}';
          final typeLabel = switch (rule.type) {
            ProgressionType.incrementWeight =>
              l10n.progressionTypeIncrementWeight,
            ProgressionType.incrementReps =>
              l10n.progressionTypeIncrementReps,
            ProgressionType.incrementSets =>
              l10n.progressionTypeIncrementSets,
          };
          final unit = switch (rule.type) {
            ProgressionType.incrementWeight => 'kg',
            ProgressionType.incrementReps => 'reps',
            ProgressionType.incrementSets => 'sets',
          };
          return Card(
            key: ValueKey('prog-$idx-${rule.exerciseId}'),
            margin: const EdgeInsets.only(bottom: AthlosSpacing.xs),
            child: ListTile(
              title: Text(exerciseName),
              subtitle: Text(
                '$typeLabel: +${rule.value % 1 == 0 ? rule.value.toInt() : rule.value} $unit',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _removeRuleAt(idx),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Deload Section ───────────────────────────────────────────────────

class _DeloadSection extends StatelessWidget {
  final TrainingProgram program;

  const _DeloadSection({required this.program});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final config = program.deloadConfig;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.deloadSectionTitle,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.xs),
        if (config == null)
          Text(
            l10n.deloadEnableLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (config.strategy) {
                      DeloadStrategy.reduceVolume =>
                        l10n.deloadStrategyReduceVolume,
                      DeloadStrategy.reduceIntensity =>
                        l10n.deloadStrategyReduceIntensity,
                      DeloadStrategy.reduceBoth =>
                        l10n.deloadStrategyReduceBoth,
                    },
                    style: textTheme.bodyMedium,
                  ),
                  if (config.frequency != null)
                    Text(
                      '${l10n.deloadFrequencyLabel}: ${config.frequency}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Actions Section ──────────────────────────────────────────────────

class _ActionsSection extends ConsumerWidget {
  final TrainingProgram program;

  const _ActionsSection({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              context.push(RoutePaths.trainingProgramEdit(program.id)),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.trainingEditProgram),
        ),
        const Gap(AthlosSpacing.sm),
        if (program.isInDeload)
          OutlinedButton.icon(
            onPressed: () => _confirmEndDeload(context, ref),
            icon: const Icon(Icons.spa_outlined),
            label: Text(l10n.deloadEndAction),
          ),
        if (!program.isInDeload && program.deloadConfig != null)
          OutlinedButton.icon(
            onPressed: () async {
                await ref
                    .read(programActionsProvider.notifier)
                    .enterDeload(program.id);
                ref.invalidate(programListProvider);
                ref.invalidate(activeProgramProvider);
              },
            icon: const Icon(Icons.spa),
            label: Text(l10n.deloadAccept),
          ),
        const Gap(AthlosSpacing.sm),
        if (program.isActive && !program.isInDeload)
          OutlinedButton.icon(
            onPressed: () => _confirmArchive(context, ref),
            icon: const Icon(Icons.archive_outlined),
            label: Text(l10n.archiveProgramAction),
          ),
        const Gap(AthlosSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.programDeleteAction),
        ),
        const Gap(AthlosSpacing.sm),
        TextButton(
          onPressed: () => context.go(RoutePaths.trainingPrograms),
          child: Text(l10n.trainingViewArchivedPrograms),
        ),
      ],
    );
  }

  void _confirmEndDeload(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deloadEndConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deloadEndConfirmMessage),
            AthlosStackedDialogActions(
              children: [
                TextButton(
                  style: AthlosDialogButtonStyles.stackedGhost(ctx),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
                FilledButton(
                  style: AthlosDialogButtonStyles.stackedFilled(ctx),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(programActionsProvider.notifier)
                        .exitDeload(program.id);
                    ref.invalidate(programListProvider);
                    ref.invalidate(activeProgramProvider);
                  },
                  child: Text(l10n.deloadEndAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.programDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.programDeleteMessage),
            AthlosStackedDialogActions(
              children: [
                TextButton(
                  style: AthlosDialogButtonStyles.stackedGhost(ctx),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(programActionsProvider.notifier)
                          .deleteProgram(program.id);
                      ref.invalidate(programListProvider);
                      ref.invalidate(activeProgramProvider);
                      if (context.mounted) {
                        context.go(RoutePaths.trainingHome);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.programDeleted)),
                        );
                      }
                    } on Exception catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.genericError)),
                        );
                      }
                    }
                  },
                  child: Text(l10n.programDeleteAction),
                ),
                FilledButton(
                  style: AthlosDialogButtonStyles.stackedFilled(ctx),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.programCompletedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.programCompletedMessage(program.name)),
            AthlosStackedDialogActions(
              children: [
                TextButton(
                  style: AthlosDialogButtonStyles.stackedGhost(ctx),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(programActionsProvider.notifier)
                        .archiveProgram(program.id);
                    ref.invalidate(programListProvider);
                    ref.invalidate(activeProgramProvider);
                    if (context.mounted) {
                      context.go(RoutePaths.trainingHome);
                    }
                  },
                  child: Text(l10n.programCompletedArchive),
                ),
                FilledButton(
                  style: AthlosDialogButtonStyles.stackedFilled(ctx),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
