import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/program_focus.dart';
import '../providers/program_notifier.dart';
import '../providers/training_analytics_provider.dart';

/// Screen listing all training programs (active + archived).
class ProgramListScreen extends ConsumerWidget {
  const ProgramListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final programsAsync = ref.watch(programListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.programListTitle),
      ),
      body: programsAsync.when(
        data: (programs) {
          if (programs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AthlosSpacing.md),
                  Text(
                    l10n.programEmpty,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AthlosSpacing.sm),
                  Text(
                    l10n.programEmptyHint,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final active = programs.where((p) => p.isActive).toList();
          final archived = programs.where((p) => !p.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            children: [
              ...active.map((p) => _ProgramCard(
                    program: p,
                    isActive: true,
                  )),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: AthlosSpacing.md),
                Text(
                  l10n.archivedSection,
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AthlosSpacing.sm),
                ...archived.map((p) => _ProgramCard(
                      program: p,
                      isActive: false,
                    )),
              ],
              const SizedBox(height: AthlosSpacing.fabClearance),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'programs_fab',
        onPressed: () => context.push(RoutePaths.trainingProgramNew),
        tooltip: l10n.programCreateTitle,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  final TrainingProgram program;
  final bool isActive;

  const _ProgramCard({required this.program, required this.isActive});

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

    return Card(
      margin: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: AthlosRadius.mdAll,
              side: BorderSide(color: colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => context.push(
          '${RoutePaths.trainingPrograms}/${program.id}/edit',
        ),
        borderRadius: AthlosRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      program.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive) ...[
                    if (program.isInDeload)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AthlosSpacing.sm,
                          vertical: AthlosSpacing.xxs,
                        ),
                        margin:
                            const EdgeInsets.only(right: AthlosSpacing.xs),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: AthlosRadius.mdAll,
                        ),
                        child: Text(
                          l10n.deloadActiveChip,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.sm,
                        vertical: AthlosSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: AthlosRadius.mdAll,
                      ),
                      child: Text(
                        l10n.programActiveBadge,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AthlosSpacing.xs),
              Text(
                focusLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AthlosSpacing.sm),
              if (isActive)
                _ProgramProgressBar(programId: program.id)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, ref, program),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(l10n.programDeleteAction),
                    ),
                    const SizedBox(width: AthlosSpacing.xs),
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(programActionsProvider.notifier)
                              .activateProgram(program.id);
                          ref.invalidate(programListProvider);
                          ref.invalidate(activeProgramProvider);
                          ref.invalidate(cycleStepsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.programActivated),
                              ),
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
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.programActivate),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TrainingProgram program,
  ) {
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
                      if (context.mounted) {
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
}

class _ProgramProgressBar extends ConsumerWidget {
  final int programId;

  const _ProgramProgressBar({required this.programId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progressAsync = ref.watch(programProgressProvider(programId));

    return progressAsync.when(
      data: (progress) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: AthlosSpacing.xs),
            ClipRRect(
              borderRadius: AthlosRadius.smAll,
              child: LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
