import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' as intl;
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/data/repositories/local_backup_providers.dart';
import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/localization/domain_label_resolver.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/conflict_center_provider.dart';
import '../widgets/attribute_merge_dialog.dart';

class ConflictCenterScreen extends ConsumerStatefulWidget {
  const ConflictCenterScreen({super.key});

  @override
  ConsumerState<ConflictCenterScreen> createState() =>
      _ConflictCenterScreenState();
}

class _ConflictCenterScreenState extends ConsumerState<ConflictCenterScreen> {
  bool _isRescanning = false;
  final Set<String> _processingReviews = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncSnapshot = ref.watch(backupConflictCenterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.conflictCenterTitle)),
      body: asyncSnapshot.when(
        loading: () => Skeletonizer(
          enabled: true,
          child: _ConflictCenterBody(
            l10n: l10n,
            reviews: const <BackupPendingReview>[],
            lastAnalyzedAt: DateTime.now(),
            isRescanning: false,
            processingReviews: const <String>{},
            onRescan: null,
            onNotDuplicate: (_) {},
            onConfirmDuplicate: (_) {},
            onKeepA: (_) {},
            onKeepB: (_) {},
            onMergeAttributes: (_) {},
          ),
        ),
        error: (_, _) => _ConflictCenterErrorState(
          message: l10n.conflictCenterLoadError,
          retryLabel: l10n.conflictCenterRetryAction,
          onRetry: () => ref.invalidate(backupConflictCenterProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(backupConflictCenterProvider.future),
          child: _ConflictCenterBody(
            l10n: l10n,
            reviews: data.runtimeLocalReviews,
            lastAnalyzedAt: data.lastAnalyzedAt,
            isRescanning: _isRescanning,
            processingReviews: _processingReviews,
            onRescan: _isRescanning ? null : _runRuntimeScan,
            onNotDuplicate: _handleNotDuplicate,
            onConfirmDuplicate: _handleConfirmDuplicate,
            onKeepA: (review) => _handleKeep(review, review.leftEntityId!),
            onKeepB: (review) => _handleKeep(review, review.rightEntityId!),
            onMergeAttributes: _handleMergeAttributes,
          ),
        ),
      ),
    );
  }

  Future<void> _runRuntimeScan() async {
    setState(() => _isRescanning = true);
    try {
      ref.invalidate(backupConflictCenterProvider);
      await ref.read(backupConflictCenterProvider.future);
    } finally {
      if (mounted) setState(() => _isRescanning = false);
    }
  }

  Future<void> _handleNotDuplicate(BackupPendingReview review) async {
    await _resolve(
      review: review,
      decision: RuntimeDuplicateDecision.notDuplicate,
    );
  }

  Future<void> _handleConfirmDuplicate(BackupPendingReview review) async {
    final winnerId = review.isLeftVerified
        ? review.leftEntityId
        : review.isRightVerified
        ? review.rightEntityId
        : review.leftEntityId;
    await _resolve(
      review: review,
      decision: RuntimeDuplicateDecision.confirmDuplicate,
      winnerId: winnerId,
    );
  }

  Future<void> _handleKeep(BackupPendingReview review, int winnerId) async {
    await _resolve(
      review: review,
      decision: RuntimeDuplicateDecision.confirmDuplicate,
      winnerId: winnerId,
    );
  }

  Future<void> _handleMergeAttributes(BackupPendingReview review) async {
    final leftId = review.leftEntityId;
    final rightId = review.rightEntityId;
    if (leftId == null || rightId == null) return;

    final repo = ref.read(localBackupRepositoryProvider);
    final leftResult = await repo.loadEntityAttributes(
      entityType: review.entityType,
      entityId: leftId,
    );
    final rightResult = await repo.loadEntityAttributes(
      entityType: review.entityType,
      entityId: rightId,
    );

    if (!mounted) return;
    final itemA = leftResult.getOrThrow();
    final itemB = rightResult.getOrThrow();

    final result = await showAttributeMergeDialog(
      context: context,
      entityType: review.entityType,
      itemA: itemA,
      itemB: itemB,
      idA: leftId,
      idB: rightId,
    );
    if (result == null) return;

    await _resolve(
      review: review,
      decision: RuntimeDuplicateDecision.mergeAttributes,
      winnerId: result.winnerId,
      mergedAttributes: result.mergedAttributes,
    );
  }

  Future<void> _resolve({
    required BackupPendingReview review,
    required RuntimeDuplicateDecision decision,
    int? winnerId,
    Map<String, dynamic>? mergedAttributes,
  }) async {
    final leftId = review.leftEntityId;
    final rightId = review.rightEntityId;
    if (leftId == null || rightId == null) return;

    setState(() => _processingReviews.add(review.reviewId));
    try {
      final useCase = ref.read(resolveRuntimeDuplicateUseCaseProvider);
      final result = await useCase(
        entityType: review.entityType,
        leftEntityId: leftId,
        rightEntityId: rightId,
        decision: decision,
        winnerId: winnerId,
        mergedAttributes: mergedAttributes,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      switch (result) {
        case Success():
          ref.invalidate(backupConflictCenterProvider);
          await ref.read(backupConflictCenterProvider.future);
        case Failure(:final exception):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_resolveErrorMessage(exception, l10n))),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _processingReviews.remove(review.reviewId));
      }
    }
  }
}

class _ConflictCenterBody extends StatelessWidget {
  const _ConflictCenterBody({
    required this.l10n,
    required this.reviews,
    this.lastAnalyzedAt,
    required this.isRescanning,
    required this.processingReviews,
    required this.onRescan,
    required this.onNotDuplicate,
    required this.onConfirmDuplicate,
    required this.onKeepA,
    required this.onKeepB,
    required this.onMergeAttributes,
  });

  final AppLocalizations l10n;
  final List<BackupPendingReview> reviews;
  final DateTime? lastAnalyzedAt;
  final bool isRescanning;
  final Set<String> processingReviews;
  final VoidCallback? onRescan;
  final void Function(BackupPendingReview review) onNotDuplicate;
  final void Function(BackupPendingReview review) onConfirmDuplicate;
  final void Function(BackupPendingReview review) onKeepA;
  final void Function(BackupPendingReview review) onKeepB;
  final void Function(BackupPendingReview review) onMergeAttributes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      children: [
        _ConflictCenterSectionHeader(title: l10n.conflictCenterOverviewSectionTitle),
        const Gap(AthlosSpacing.xs),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.conflictCenterDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Gap(AthlosSpacing.md),
                _ConflictCenterStatusBanner(duplicateCount: reviews.length),
                const Gap(AthlosSpacing.md),
                _ConflictCenterLastAnalysisRow(
                  l10n: l10n,
                  lastAnalyzedAt: lastAnalyzedAt,
                ),
                const Gap(AthlosSpacing.md),
                AthlosStackedActions(
                  spacing: AthlosSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onRescan,
                      icon: isRescanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.conflictCenterRescanAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (reviews.isNotEmpty) ...[
          const Gap(AthlosSpacing.md),
          _ConflictCenterSectionHeader(
            title: l10n.conflictCenterReviewsSectionTitle,
          ),
          const Gap(AthlosSpacing.xs),
          Text(
            l10n.conflictCenterReviewHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(AthlosSpacing.sm),
          for (final review in reviews) ...[
            _DuplicateCard(
              review: review,
              isProcessing: processingReviews.contains(review.reviewId),
              onNotDuplicate: () => onNotDuplicate(review),
              onConfirmDuplicate: () => onConfirmDuplicate(review),
              onKeepA: () => onKeepA(review),
              onKeepB: () => onKeepB(review),
              onMergeAttributes: () => onMergeAttributes(review),
            ),
            const Gap(AthlosSpacing.sm),
          ],
        ],
        const Gap(AthlosSpacing.lg),
      ],
    );
  }
}

class _ConflictCenterErrorState extends StatelessWidget {
  const _ConflictCenterErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConflictCenterStatusSurface(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
              icon: Icons.error_outline,
              message: message,
            ),
            const Gap(AthlosSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictCenterSectionHeader extends StatelessWidget {
  const _ConflictCenterSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ConflictCenterLastAnalysisRow extends StatelessWidget {
  const _ConflictCenterLastAnalysisRow({
    required this.l10n,
    required this.lastAnalyzedAt,
  });

  final AppLocalizations l10n;
  final DateTime? lastAnalyzedAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final analyzedAt = lastAnalyzedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.conflictCenterLastAnalysisLabel,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.xs),
        Text(
          analyzedAt != null
              ? _formatAnalysisTimestamp(context, analyzedAt)
              : l10n.conflictCenterNeverAnalyzed,
          style: textTheme.titleSmall,
        ),
      ],
    );
  }

  String _formatAnalysisTimestamp(BuildContext context, DateTime instant) {
    final locale = Localizations.localeOf(context).toString();
    return intl.DateFormat('dd/MM/yyyy HH:mm', locale).format(instant.toLocal());
  }
}

class _ConflictCenterStatusBanner extends StatelessWidget {
  const _ConflictCenterStatusBanner({required this.duplicateCount});

  final int duplicateCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>()!;

    if (duplicateCount == 0) {
      return _ConflictCenterStatusSurface(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        iconColor: colorScheme.primary,
        icon: Icons.check_circle_outline,
        message: l10n.conflictCenterEmptyState,
      );
    }

    final warningStyle = customColors.duplicateWarningCallout(colorScheme);

    return _ConflictCenterStatusSurface(
      backgroundColor: warningStyle.background,
      foregroundColor: warningStyle.foreground,
      iconColor: warningStyle.icon,
      icon: Icons.warning_amber_rounded,
      message: l10n.conflictCenterDuplicatesFound(duplicateCount),
    );
  }
}

class _ConflictCenterStatusSurface extends StatelessWidget {
  const _ConflictCenterStatusSurface({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.message,
    this.iconColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AthlosSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AthlosRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor ?? foregroundColor),
          const Gap(AthlosSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(color: foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DuplicateCard extends StatelessWidget {
  final BackupPendingReview review;
  final bool isProcessing;
  final VoidCallback onNotDuplicate;
  final VoidCallback onConfirmDuplicate;
  final VoidCallback onKeepA;
  final VoidCallback onKeepB;
  final VoidCallback onMergeAttributes;

  const _DuplicateCard({
    required this.review,
    required this.isProcessing,
    required this.onNotDuplicate,
    required this.onConfirmDuplicate,
    required this.onKeepA,
    required this.onKeepB,
    required this.onMergeAttributes,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labelA = _resolveLabel(review.entityType, review.importedLabel, l10n);
    final labelB = _resolveLabel(
      review.entityType,
      review.existingLabel ?? review.suggestedLabel ?? '-',
      l10n,
    );

    final similarityPercent = review.similarityScore != null
        ? (review.similarityScore! * 100).round().toString()
        : '-';

    final hasVerified = review.hasVerifiedSide;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const Gap(AthlosSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.conflictCenterCardTitle(
                      _entityLabel(review.entityType, l10n),
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(AthlosSpacing.md),
            _ItemRow(
              label: 'A',
              name: labelA,
              isVerified: review.isLeftVerified,
              colorScheme: colorScheme,
              textTheme: textTheme,
              l10n: l10n,
            ),
            const Gap(AthlosSpacing.sm),
            _ItemRow(
              label: 'B',
              name: labelB,
              isVerified: review.isRightVerified,
              colorScheme: colorScheme,
              textTheme: textTheme,
              l10n: l10n,
            ),
            const Gap(AthlosSpacing.sm),
            _ConflictCenterStatusSurface(
              backgroundColor: colorScheme.surfaceContainerHigh,
              foregroundColor: colorScheme.onSurfaceVariant,
              icon: Icons.percent,
              message: l10n.conflictCenterSimilarity(similarityPercent),
            ),
            const Gap(AthlosSpacing.md),
            const Divider(height: 1),
            const Gap(AthlosSpacing.md),
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AthlosSpacing.sm),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (hasVerified)
              _VerifiedActions(
                onNotDuplicate: onNotDuplicate,
                onConfirmDuplicate: onConfirmDuplicate,
                l10n: l10n,
              )
            else
              _CustomActions(
                onNotDuplicate: onNotDuplicate,
                onKeepA: onKeepA,
                onKeepB: onKeepB,
                onMergeAttributes: onMergeAttributes,
                l10n: l10n,
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String label;
  final String name;
  final bool isVerified;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  const _ItemRow({
    required this.label,
    required this.name,
    required this.isVerified,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AthlosSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AthlosRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Gap(AthlosSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: textTheme.bodyLarge),
                Text(
                  isVerified
                      ? l10n.conflictCenterVerifiedBadge
                      : l10n.conflictCenterCustomBadge,
                  style: textTheme.bodySmall?.copyWith(
                    color: isVerified
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
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

class _VerifiedActions extends StatelessWidget {
  final VoidCallback onNotDuplicate;
  final VoidCallback onConfirmDuplicate;
  final AppLocalizations l10n;

  const _VerifiedActions({
    required this.onNotDuplicate,
    required this.onConfirmDuplicate,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return AthlosStackedActions(
      spacing: AthlosSpacing.sm,
      children: [
        OutlinedButton(
          onPressed: onNotDuplicate,
          child: Text(l10n.conflictCenterNotDuplicateAction),
        ),
        FilledButton(
          onPressed: onConfirmDuplicate,
          child: Text(l10n.conflictCenterConfirmDuplicateAction),
        ),
      ],
    );
  }
}

class _CustomActions extends StatelessWidget {
  final VoidCallback onNotDuplicate;
  final VoidCallback onKeepA;
  final VoidCallback onKeepB;
  final VoidCallback onMergeAttributes;
  final AppLocalizations l10n;

  const _CustomActions({
    required this.onNotDuplicate,
    required this.onKeepA,
    required this.onKeepB,
    required this.onMergeAttributes,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return AthlosStackedActions(
      spacing: AthlosSpacing.sm,
      children: [
        FilledButton(
          onPressed: onMergeAttributes,
          child: Text(l10n.conflictCenterMergeAttributesAction),
        ),
        FilledButton.tonal(
          onPressed: onKeepA,
          child: Text(l10n.conflictCenterKeepAAction),
        ),
        FilledButton.tonal(
          onPressed: onKeepB,
          child: Text(l10n.conflictCenterKeepBAction),
        ),
        OutlinedButton(
          onPressed: onNotDuplicate,
          child: Text(l10n.conflictCenterNotDuplicateAction),
        ),
      ],
    );
  }
}

String _entityLabel(BackupConflictType type, AppLocalizations l10n) {
  return switch (type) {
    BackupConflictType.profile => l10n.profile,
    BackupConflictType.equipment => l10n.profileEquipmentTab,
    BackupConflictType.exercise => l10n.tabExercises,
    BackupConflictType.workout => l10n.tabTraining,
  };
}

String _resolveErrorMessage(AppException exception, AppLocalizations l10n) {
  if (exception is ValidationException) {
    final message = exception.message;
    if (message.contains('Cannot merge two verified')) {
      return l10n.conflictCenterResolveBothVerified;
    }
    if (message.contains('Cannot remove a verified catalog')) {
      return l10n.conflictCenterResolveVerifiedProtected;
    }
    return message;
  }
  return switch (exception) {
    NotFoundException() => l10n.conflictCenterResolveNotFound,
    DatabaseException(:final message) => message,
    _ => l10n.conflictCenterResolveError,
  };
}

String _resolveLabel(
  BackupConflictType entityType,
  String label,
  AppLocalizations l10n,
) {
  final trimmed = label.trim();
  if (trimmed.isEmpty || trimmed == '-') return '-';

  final resolver = DomainLabelResolver(l10n);
  final kind = switch (entityType) {
    BackupConflictType.equipment => DomainLabelKind.equipment,
    BackupConflictType.exercise => DomainLabelKind.exercise,
    BackupConflictType.profile || BackupConflictType.workout => null,
  };
  if (kind == null) return trimmed;

  final canonical = resolver.toCanonicalName(kind: kind, candidate: trimmed);
  return resolver.toDisplayName(
    kind: kind,
    canonicalName: canonical,
    isVerified: true,
  );
}
