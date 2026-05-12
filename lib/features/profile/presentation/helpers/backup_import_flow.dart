import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/data/repositories/local_backup_providers.dart';
import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/domain_label_resolver.dart';
import '../../../../core/theme/athlos_button_insets.dart';
import '../../../../core/theme/athlos_button_sizes.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training/presentation/providers/exercise_notifier.dart';
import '../../../training/presentation/providers/program_notifier.dart';
import '../../../training/presentation/providers/recalculate_training_streaks.dart';
import '../../../training/presentation/providers/training_analytics_provider.dart';
import '../../../training/presentation/providers/workout_execution_notifier.dart';
import '../../../training/presentation/providers/workout_notifier.dart';
import '../providers/profile_notifier.dart';

Future<void> runBackupImportFlow({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
  String loggerName = 'BackupImportFlow',
}) async {
  try {
    if (kDebugMode) {
      dev.log('[backup-ui] start file picker', name: loggerName);
    }

    final fileResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (fileResult == null || fileResult.files.isEmpty) return;

    final file = fileResult.files.single;
    if (kDebugMode) {
      dev.log(
        '[backup-ui] selected file: name=${file.name} size=${file.size}',
        name: loggerName,
      );
    }

    String? jsonContent;
    if (file.bytes != null) {
      jsonContent = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonContent = await File(file.path!).readAsString();
    }
    if (jsonContent == null) {
      throw const FormatException('Selected file is empty.');
    }

    final previewUseCase = ref.read(previewLocalBackupImportUseCaseProvider);
    if (kDebugMode) {
      dev.log('[backup-ui] preview import', name: loggerName);
    }
    final previewResult = await previewUseCase(jsonContent);
    final preview = previewResult.getOrThrow();
    if (kDebugMode) {
      dev.log(
        '[backup-ui] preview done: conflicts=${preview.conflicts.length} '
        'pending=${preview.pendingReviews.length} total=${preview.totalRecords}',
        name: loggerName,
      );
    }

    final resolutions = <String, BackupConflictResolution>{};
    for (final conflict in preview.conflicts) {
      if (!context.mounted) return;
      final selected = await _showConflictDialog(
        context: context,
        conflict: conflict,
        l10n: l10n,
      );
      if (selected == null) return;
      resolutions[conflict.conflictId] = selected;
    }

    final pendingResolutions = <String, BackupPendingReviewResolution>{};
    for (final review in preview.pendingReviews) {
      if (review.decisionScope ==
          BackupConflictDecisionScope.catalogGovernance) {
        pendingResolutions[review.reviewId] =
            BackupPendingReviewResolution.skip;
        continue;
      }
      if (!context.mounted) return;
      final selected = await _showPendingReviewDialog(
        context: context,
        review: review,
        l10n: l10n,
      );
      if (selected == null) return;
      pendingResolutions[review.reviewId] = selected;
    }

    if (!context.mounted) return;
    final confirmed =
        await showAthlosDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.profileDataImportConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.profileDataImportConfirmMessage(preview.totalRecords),
                ),
              ],
            ),
            actions: [
              AthlosStackedDialogActions(
                children: [
                  TextButton(
                    style: AthlosDialogButtonStyles.stackedGhost(context),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    style: AthlosDialogButtonStyles.stackedFilled(context),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l10n.profileDataImportAction),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    final importUseCase = ref.read(importLocalBackupUseCaseProvider);
    if (kDebugMode) {
      dev.log('[backup-ui] execute import', name: loggerName);
    }
    final importResult = await importUseCase(
      BackupImportRequest(
        jsonContent: jsonContent,
        conflictResolutions: resolutions,
        pendingReviewResolutions: pendingResolutions,
      ),
    );
    final report = importResult.getOrThrow();

    await _invalidateProvidersAfterBackupImport(ref);

    if (!context.mounted) return;
    await showAthlosDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDataImportResultTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileDataImportResultMessage(
                report.createdCount,
                report.updatedCount,
                report.skippedCount,
                report.failedCount,
              ),
            ),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(context),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.okButton),
              ),
            ],
          ),
        ],
      ),
    );
  } on Exception catch (e, stackTrace) {
    final debugMessage = '[backup-ui] import flow exception: ${e.toString()}';
    debugPrint(debugMessage);
    debugPrintStack(
      stackTrace: stackTrace,
      label: '[backup-ui] import flow stacktrace',
    );
    if (kDebugMode) {
      dev.log(debugMessage, name: loggerName, error: e, stackTrace: stackTrace);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kDebugMode
              ? '${l10n.profileDataImportError}\n${e.toString()}'
              : l10n.profileDataImportError,
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

/// Runs after a successful import so [FutureProvider] teardown from mass
/// [invalidate] does not trip Riverpod debug asserts (e.g. activeProgram).
Future<void> _invalidateProvidersAfterBackupImport(WidgetRef ref) {
  final done = Completer<void>();
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    try {
      ref.invalidate(profileProvider);
      ref.invalidate(activeProgramProvider);
      ref.invalidate(programListProvider);
      ref.invalidate(workoutListProvider);
      ref.invalidate(archivedWorkoutListProvider);
      ref.invalidate(lastFinishedWorkoutIdProvider);
      ref.invalidate(workoutExecutionListProvider);
      ref.invalidate(exerciseListProvider);
      ref.invalidate(cycleStepsProvider);
      ref.invalidate(effectiveCycleStepsProvider);
      ref.invalidate(cycleListItemsProvider);
      ref.invalidate(nextCycleWorkoutProvider);
      ref.invalidate(nextWorkoutToStartProvider);
      ref.invalidate(nextCycleStepIndexProvider);
      ref.invalidate(executionStreakProvider);
      ref.invalidate(trainingHomeAnalyticsProvider);

      await ref.read(recalculateTrainingStreaksProvider.notifier).run();
      ref.invalidate(profileProvider);
      done.complete();
    } on Object catch (e, st) {
      done.completeError(e, st);
    }
  });
  return done.future;
}

Future<BackupConflictResolution?> _showConflictDialog({
  required BuildContext context,
  required BackupImportConflict conflict,
  required AppLocalizations l10n,
}) {
  return showAthlosDialog<BackupConflictResolution>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.profileDataConflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileDataConflictType(
                    _conflictTypeLabel(conflict, l10n),
                  ),
                ),
                const Gap(AthlosSpacing.sm),
                Text(
                  l10n.profileDataConflictExisting(
                    _resolveEntityLabel(
                      conflict.type,
                      conflict.existingLabel,
                      l10n,
                    ),
                  ),
                ),
                Text(
                  l10n.profileDataConflictImported(
                    _resolveEntityLabel(
                      conflict.type,
                      conflict.importedLabel,
                      l10n,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              for (final resolution in conflict.allowedResolutions)
                TextButton(
                  style: AthlosDialogButtonStyles.stackedGhost(context),
                  onPressed: () => Navigator.of(context).pop(resolution),
                  child: Text(_resolutionLabel(resolution, l10n)),
                ),
            ],
          ),
        ],
      );
    },
  );
}

Future<BackupPendingReviewResolution?> _showPendingReviewDialog({
  required BuildContext context,
  required BackupPendingReview review,
  required AppLocalizations l10n,
}) {
  final importedDisplay = _resolveEntityLabel(
    review.entityType,
    review.importedLabel,
    l10n,
  );
  final existingDisplay = review.existingLabel != null
      ? _resolveEntityLabel(review.entityType, review.existingLabel!, l10n)
      : null;
  final suggestedDisplay = review.suggestedLabel != null
      ? _resolveEntityLabel(review.entityType, review.suggestedLabel!, l10n)
      : null;

  final similarityPercent = review.similarityScore != null
      ? '${(review.similarityScore!.clamp(0.0, 1.0) * 100).round()}%'
      : null;

  return showAthlosDialog<BackupPendingReviewResolution>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final textTheme = theme.textTheme;

      final suggestionWidgets = suggestedDisplay != null
          ? <Widget>[
              Text(
                l10n.profileDataPendingLabelSuggestion,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.xs),
              Text(
                similarityPercent != null
                    ? l10n.profileDataPendingSuggested(
                        suggestedDisplay,
                        similarityPercent,
                      )
                    : l10n.profileDataPendingSuggestedShort(suggestedDisplay),
                style: textTheme.bodyLarge,
              ),
            ]
          : <Widget>[
              Text(
                l10n.profileDataPendingNoSuggestion,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ];

      final allowUserChoice =
          review.decisionScope != BackupConflictDecisionScope.catalogGovernance;

      return AlertDialog(
        title: Text(l10n.profileDataPendingTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profileDataPendingIntro, style: textTheme.bodyMedium),
              const Gap(AthlosSpacing.sm),
              Text(
                _pendingContextSentence(review, l10n),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Gap(AthlosSpacing.sm),
              Text(
                _pendingSituationSentence(review, l10n),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(AthlosSpacing.md),
              _pendingDialogValueBlock(
                context,
                caption: l10n.profileDataPendingLabelFromBackup,
                value: importedDisplay,
              ),
              if (existingDisplay != null) ...[
                const Gap(AthlosSpacing.sm),
                _pendingDialogValueBlock(
                  context,
                  caption: l10n.profileDataPendingLabelOnDevice,
                  value: existingDisplay,
                ),
              ],
              const Gap(AthlosSpacing.sm),
              ...suggestionWidgets,
            ],
          ),
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(context),
                onPressed: () => Navigator.of(
                  context,
                ).pop(BackupPendingReviewResolution.skip),
                child: _pendingDialogActionLabel(l10n.profileDataPendingSkip),
              ),
              if (allowUserChoice) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      double.infinity,
                      AthlosButtonSizes.dialogMinHeight,
                    ),
                    padding: AthlosButtonInsets.screen,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(BackupPendingReviewResolution.createCustom),
                  child: _pendingDialogActionLabel(
                    l10n.profileDataPendingCreateCustom,
                  ),
                ),
                if (review.suggestedLabel != null)
                  FilledButton(
                    style: AthlosDialogButtonStyles.stackedFilled(context),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(BackupPendingReviewResolution.linkSuggested),
                    child: _pendingDialogActionLabel(
                      l10n.profileDataPendingLinkSuggested,
                    ),
                  ),
              ],
            ],
          ),
        ],
      );
    },
  );
}

/// Centered, up to two lines — avoids odd left-aligned wraps in full-width
/// dialog buttons.
Widget _pendingDialogActionLabel(String text) {
  return Text(text, textAlign: TextAlign.center, maxLines: 2);
}

Widget _pendingDialogValueBlock(
  BuildContext context, {
  required String caption,
  required String value,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        caption,
        style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const Gap(AthlosSpacing.xs),
      Text(value, style: textTheme.bodyLarge),
    ],
  );
}

String _pendingContextSentence(
  BackupPendingReview review,
  AppLocalizations l10n,
) {
  return switch (review.detectedFrom) {
    BackupConflictDetectedFrom.importPreview =>
      l10n.profileDataPendingContextImportPreview,
    BackupConflictDetectedFrom.runtimeScan =>
      l10n.profileDataPendingContextRuntimeScan,
    BackupConflictDetectedFrom.catalogSync =>
      l10n.profileDataPendingContextCatalogSync,
  };
}

String _pendingSituationSentence(
  BackupPendingReview review,
  AppLocalizations l10n,
) {
  final entityLabel = _conflictTypeFromEnum(review.entityType, l10n);
  return switch (review.type) {
    BackupPendingReviewType.missingCanonicalReference =>
      l10n.profileDataPendingMissingCanonical(entityLabel),
    BackupPendingReviewType.fuzzyMatchCandidate => l10n.profileDataPendingFuzzy(
      entityLabel,
    ),
    BackupPendingReviewType.verifiedVsCustomConfirmation =>
      l10n.profileDataPendingVerifiedVsCustom(entityLabel),
    BackupPendingReviewType.governanceConflict =>
      l10n.profileDataPendingGovernance(entityLabel),
  };
}

String _conflictTypeLabel(
  BackupImportConflict conflict,
  AppLocalizations l10n,
) {
  return _conflictTypeFromEnum(conflict.type, l10n);
}

String _conflictTypeFromEnum(BackupConflictType type, AppLocalizations l10n) {
  return switch (type) {
    BackupConflictType.profile => l10n.profile,
    BackupConflictType.equipment => l10n.profileEquipmentTab,
    BackupConflictType.exercise => l10n.tabExercises,
    BackupConflictType.workout => l10n.tabTraining,
  };
}

String _resolutionLabel(
  BackupConflictResolution resolution,
  AppLocalizations l10n,
) {
  return switch (resolution) {
    BackupConflictResolution.keepExisting =>
      l10n.profileDataConflictKeepExisting,
    BackupConflictResolution.overwriteExisting =>
      l10n.profileDataConflictOverwrite,
    BackupConflictResolution.keepBoth => l10n.profileDataConflictKeepBoth,
  };
}

String _resolveEntityLabel(
  BackupConflictType entityType,
  String label,
  AppLocalizations l10n,
) {
  final trimmed = label.trim();
  if (trimmed.isEmpty || trimmed == '-') return '-';

  final kind = switch (entityType) {
    BackupConflictType.equipment => DomainLabelKind.equipment,
    BackupConflictType.exercise => DomainLabelKind.exercise,
    BackupConflictType.profile || BackupConflictType.workout => null,
  };
  if (kind == null) return trimmed;

  final resolver = DomainLabelResolver(l10n);
  final canonical = resolver.toCanonicalName(kind: kind, candidate: trimmed);
  return resolver.toDisplayName(
    kind: kind,
    canonicalName: canonical,
    isVerified: true,
  );
}
