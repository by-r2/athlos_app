import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/services/ghost_exercise_remap_providers.dart';
import '../../../../core/services/ghost_exercise_remap_service.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/repositories/training_providers.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/active_execution_notifier.dart';
import '../providers/exercise_notifier.dart';
import '../providers/workout_notifier.dart';
import 'exercise_picker_sheet.dart';

/// Recovery UI when a workout references exercise ids missing from the catalog.
///
/// Lets the user pick a replacement exercise and remaps **all** of their rows
/// that still reference the ghost id (workouts, execution history, rules).
class GhostExerciseRecoveryPanel extends ConsumerStatefulWidget {
  const GhostExerciseRecoveryPanel({
    super.key,
    required this.missingExerciseIds,
    required this.workoutId,
    required this.onResolved,
    this.onCancelExecution,
  });

  final List<String> missingExerciseIds;
  final String workoutId;
  final VoidCallback onResolved;
  final VoidCallback? onCancelExecution;

  @override
  ConsumerState<GhostExerciseRecoveryPanel> createState() =>
      _GhostExerciseRecoveryPanelState();
}

class _GhostExerciseRecoveryPanelState
    extends ConsumerState<GhostExerciseRecoveryPanel> {
  String? _processingGhostId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.ghostExerciseRecoveryTitle,
          style: textTheme.titleMedium,
        ),
        const Gap(AthlosSpacing.sm),
        Text(
          l10n.ghostExerciseRecoveryDescription,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.lg),
        Expanded(
          child: ListView.separated(
            itemCount: widget.missingExerciseIds.length,
            separatorBuilder: (_, _) => const Gap(AthlosSpacing.sm),
            itemBuilder: (context, index) {
              final ghostId = widget.missingExerciseIds[index];
              return _GhostExerciseCard(
                ghostExerciseId: ghostId,
                isProcessing: _processingGhostId == ghostId,
                onLink: () => _linkGhostExercise(context, ghostId),
              );
            },
          ),
        ),
        if (widget.onCancelExecution != null) ...[
          const Gap(AthlosSpacing.sm),
          OutlinedButton(
            onPressed: _processingGhostId == null
                ? widget.onCancelExecution
                : null,
            child: Text(l10n.cancelExecution),
          ),
        ],
      ],
    );
  }

  Future<void> _linkGhostExercise(
    BuildContext context,
    String ghostId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.read(authProvider).value?.id;
    if (userId == null) return;

    final picked = await showExercisePickerSheet(context);
    if (picked == null || !context.mounted) return;
    if (picked.id == ghostId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ghostExerciseRecoverySameExercise)),
      );
      return;
    }

    final service = ref.read(ghostExerciseRemapServiceProvider);
    GhostExerciseRemapPreview preview;
    try {
      preview = await service.previewForUser(
        userId: userId,
        ghostExerciseId: ghostId,
      );
    } on Exception catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showAthlosDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ghostExerciseRecoveryConfirmTitle),
        content: Text(
          l10n.ghostExerciseRecoveryConfirmMessage(
            preview.workoutExercises,
            preview.executionSets,
            preview.progressionRules,
            localizedExerciseName(
              picked.name,
              isVerified: picked.isVerified,
              l10n: l10n,
            ),
          ),
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.ghostExerciseRecoveryConfirmAction),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _processingGhostId = ghostId);
    try {
      await service.remapForUser(
        userId: userId,
        ghostExerciseId: ghostId,
        targetExerciseId: picked.id,
      );
      await _reloadActiveExecution();
      ref.invalidate(exerciseListProvider);
      ref.invalidate(workoutExercisesProvider(widget.workoutId));
      ref.invalidate(workoutListProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ghostExerciseRecoverySuccess)),
      );
      widget.onResolved();
    } on Exception catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    } finally {
      if (mounted) setState(() => _processingGhostId = null);
    }
  }

  Future<void> _reloadActiveExecution() async {
    final exec = ref.read(activeExecutionProvider);
    if (exec == null) return;

    final wRepo = ref.read(workoutRepositoryProvider);
    final pRepo = ref.read(programRepositoryProvider);
    final exercises = (await wRepo.getExercises(widget.workoutId)).getOrThrow();
    final program = (await pRepo.getActive()).getOrThrow();
    final allExercises = ref.read(exerciseListProvider).value ?? [];
    final isometricIds = {
      for (final e in allExercises)
        if (e.isIsometric) e.id,
    };

    await ref.read(activeExecutionProvider.notifier).resumeExecution(
          exec.executionId,
          widget.workoutId,
          exercises,
          programId: exec.exercises.isNotEmpty ? program?.id : null,
          defaultRestSeconds: program?.defaultRestSeconds ?? 0,
          isometricExerciseIds: isometricIds,
        );
  }
}

class _GhostExerciseCard extends ConsumerWidget {
  const _GhostExerciseCard({
    required this.ghostExerciseId,
    required this.isProcessing,
    required this.onLink,
  });

  final String ghostExerciseId;
  final bool isProcessing;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final service = ref.watch(ghostExerciseRemapServiceProvider);
    final userId = ref.watch(authProvider).value?.id;

    return FutureBuilder<GhostExerciseCatalogRow?>(
      future: service.lookupExerciseRow(ghostExerciseId),
      builder: (context, snapshot) {
        final row = snapshot.data;
        final displayLabel = row == null
            ? l10n.unknownExerciseId(ghostExerciseId)
            : localizedExerciseName(
                row.name,
                isVerified: row.isVerified,
                l10n: l10n,
              );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(displayLabel, style: textTheme.titleSmall),
                const Gap(AthlosSpacing.xs),
                Text(
                  l10n.ghostExerciseRecoveryMissingId(ghostExerciseId),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                if (userId != null) ...[
                  const Gap(AthlosSpacing.xs),
                  FutureBuilder<GhostExerciseUsageSummary>(
                    future: service.usageSummaryForUser(
                      userId: userId,
                      ghostExerciseId: ghostExerciseId,
                    ),
                    builder: (context, usageSnap) {
                      final usage = usageSnap.data;
                      if (usage == null) return const SizedBox.shrink();

                      final names = usage.workoutNames.where((e) => e.trim().isNotEmpty).toList();
                      final sample = names.isEmpty ? null : names.join(', ');
                      final suffix = usage.workoutCount > names.length
                          ? l10n.ghostExerciseRecoveryWorkoutListMore(
                              usage.workoutCount - names.length,
                            )
                          : null;
                      final workoutsLabel = sample == null
                          ? l10n.ghostExerciseRecoveryWorkoutListUnknown
                          : [
                              sample,
                              if (suffix != null) suffix,
                            ].join(' ');

                      return Text(
                        l10n.ghostExerciseRecoveryUsedInWorkouts(workoutsLabel),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
                if (row?.isDeleted == true) ...[
                  const Gap(AthlosSpacing.xs),
                  Text(
                    l10n.ghostExerciseRecoveryDeletedHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                const Gap(AthlosSpacing.md),
                FilledButton(
                  onPressed: isProcessing ? null : onLink,
                  child: isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(l10n.ghostExerciseRecoveryLinkAction),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
