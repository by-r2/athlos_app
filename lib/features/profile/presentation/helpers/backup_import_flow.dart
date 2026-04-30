import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/data/repositories/local_backup_providers.dart';
import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/domain_label_resolver.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training/presentation/providers/equipment_notifier.dart';
import '../../../training/presentation/providers/exercise_notifier.dart';
import '../../../training/presentation/providers/program_notifier.dart';
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
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.profileDataImportConfirmTitle),
            content: Text(
              l10n.profileDataImportConfirmMessage(preview.totalRecords),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.profileDataImportAction),
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

    ref.invalidate(profileProvider);
    ref.invalidate(activeProgramProvider);
    ref.invalidate(programListProvider);
    ref.invalidate(workoutListProvider);
    ref.invalidate(archivedWorkoutListProvider);
    ref.invalidate(lastFinishedWorkoutIdProvider);
    ref.invalidate(workoutExecutionListProvider);
    ref.invalidate(exerciseListProvider);
    ref.invalidate(exerciseEquipmentMapProvider);
    ref.invalidate(equipmentListProvider);
    ref.invalidate(userEquipmentIdsProvider);
    ref.invalidate(cycleStepsProvider);
    ref.invalidate(effectiveCycleStepsProvider);
    ref.invalidate(cycleListItemsProvider);
    ref.invalidate(nextCycleWorkoutProvider);
    ref.invalidate(nextWorkoutToStartProvider);
    ref.invalidate(nextCycleStepIndexProvider);
    ref.invalidate(executionStreakProvider);
    ref.invalidate(trainingHomeAnalyticsProvider);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileDataImportResultTitle),
        content: Text(
          l10n.profileDataImportResultMessage(
            report.createdCount,
            report.updatedCount,
            report.skippedCount,
            report.failedCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.okButton),
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

Future<BackupConflictResolution?> _showConflictDialog({
  required BuildContext context,
  required BackupImportConflict conflict,
  required AppLocalizations l10n,
}) {
  return showDialog<BackupConflictResolution>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.profileDataConflictTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileDataConflictType(_conflictTypeLabel(conflict, l10n)),
            ),
            const Gap(AthlosSpacing.sm),
            Text(l10n.profileDataConflictExisting(
              _resolveEntityLabel(conflict.type, conflict.existingLabel, l10n),
            )),
            Text(l10n.profileDataConflictImported(
              _resolveEntityLabel(conflict.type, conflict.importedLabel, l10n),
            )),
          ],
        ),
        actions: [
          for (final resolution in conflict.allowedResolutions)
            TextButton(
              onPressed: () => Navigator.of(context).pop(resolution),
              child: Text(_resolutionLabel(resolution, l10n)),
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
  final importedDisplay =
      _resolveEntityLabel(review.entityType, review.importedLabel, l10n);
  final existingDisplay = review.existingLabel != null
      ? _resolveEntityLabel(review.entityType, review.existingLabel!, l10n)
      : null;
  final suggestedDisplay = review.suggestedLabel != null
      ? _resolveEntityLabel(review.entityType, review.suggestedLabel!, l10n)
      : null;

  final suggestionText = suggestedDisplay != null
      ? l10n.profileDataPendingSuggested(
          suggestedDisplay,
          review.similarityScore?.toStringAsFixed(2) ?? '-',
        )
      : l10n.profileDataPendingNoSuggestion;

  return showDialog<BackupPendingReviewResolution>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.profileDataPendingTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileDataPendingType(_pendingTypeLabel(review, l10n))),
            Text(
              l10n.profileDataPendingScope(_pendingScopeLabel(review, l10n)),
            ),
            Text(
              l10n.profileDataPendingDetectedFrom(
                _pendingSourceLabel(review, l10n),
              ),
            ),
            const Gap(AthlosSpacing.sm),
            Text(l10n.profileDataPendingImported(importedDisplay)),
            if (existingDisplay != null)
              Text(l10n.profileDataPendingExisting(existingDisplay)),
            Text(suggestionText),
          ],
        ),
        actions: [
          if (review.decisionScope !=
                  BackupConflictDecisionScope.catalogGovernance &&
              review.suggestedLabel != null)
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(BackupPendingReviewResolution.linkSuggested),
              child: Text(l10n.profileDataPendingLinkSuggested),
            ),
          if (review.decisionScope !=
              BackupConflictDecisionScope.catalogGovernance)
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(BackupPendingReviewResolution.createCustom),
              child: Text(l10n.profileDataPendingCreateCustom),
            ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(BackupPendingReviewResolution.skip),
            child: Text(l10n.profileDataPendingSkip),
          ),
        ],
      );
    },
  );
}

String _pendingTypeLabel(BackupPendingReview review, AppLocalizations l10n) {
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

String _pendingScopeLabel(BackupPendingReview review, AppLocalizations l10n) {
  return switch (review.decisionScope) {
    BackupConflictDecisionScope.userLocal =>
      l10n.profileDataPendingScopeUserLocal,
    BackupConflictDecisionScope.catalogGovernance =>
      l10n.profileDataPendingScopeCatalogGovernance,
  };
}

String _pendingSourceLabel(BackupPendingReview review, AppLocalizations l10n) {
  return switch (review.detectedFrom) {
    BackupConflictDetectedFrom.importPreview =>
      l10n.profileDataPendingSourceImportPreview,
    BackupConflictDetectedFrom.runtimeScan =>
      l10n.profileDataPendingSourceRuntimeScan,
    BackupConflictDetectedFrom.catalogSync =>
      l10n.profileDataPendingSourceCatalogSync,
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
