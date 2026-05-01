import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/data/repositories/local_backup_providers.dart';
import '../../../../core/domain/entities/local_backup_models.dart';
import '../../../../core/localization/domain_label_resolver.dart';
import '../../../../core/errors/result.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.conflictCenterLoadError)),
        data: (data) => RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(backupConflictCenterProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            children: [
              Text(
                l10n.conflictCenterDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Gap(AthlosSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.conflictCenterDuplicatesFound(
                        data.runtimeLocalReviews.length,
                      ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isRescanning ? null : _runRuntimeScan,
                    icon: _isRescanning
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
              const Gap(AthlosSpacing.md),
              if (data.runtimeLocalReviews.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AthlosSpacing.xl,
                    ),
                    child: Text(
                      l10n.conflictCenterEmptyState,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final review in data.runtimeLocalReviews) ...[
                  _DuplicateCard(
                    review: review,
                    isProcessing: _processingReviews.contains(review.reviewId),
                    onNotDuplicate: () => _handleNotDuplicate(review),
                    onConfirmDuplicate: () => _handleConfirmDuplicate(review),
                    onKeepA: () => _handleKeep(review, review.leftEntityId!),
                    onKeepB: () => _handleKeep(review, review.rightEntityId!),
                    onMergeAttributes: () => _handleMergeAttributes(review),
                  ),
                  const Gap(AthlosSpacing.sm),
                ],
            ],
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
      result.getOrThrow();
      ref.invalidate(backupConflictCenterProvider);
      await ref.read(backupConflictCenterProvider.future);
    } on Exception {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileDataImportError)));
    } finally {
      if (mounted) {
        setState(() => _processingReviews.remove(review.reviewId));
      }
    }
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
            Text(
              l10n.conflictCenterCardTitle(
                _entityLabel(review.entityType, l10n),
              ),
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
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
            Text(
              l10n.conflictCenterSimilarity(similarityPercent),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

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
    return Row(
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
                      ? colorScheme.tertiary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onMergeAttributes,
          child: Text(l10n.conflictCenterMergeAttributesAction),
        ),
        const Gap(AthlosSpacing.xs),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onKeepA,
                child: Text(l10n.conflictCenterKeepAAction),
              ),
            ),
            const Gap(AthlosSpacing.xs),
            Expanded(
              child: FilledButton.tonal(
                onPressed: onKeepB,
                child: Text(l10n.conflictCenterKeepBAction),
              ),
            ),
          ],
        ),
        const Gap(AthlosSpacing.xs),
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
