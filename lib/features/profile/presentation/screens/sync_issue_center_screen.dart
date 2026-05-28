import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/providers/last_module_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_issue.dart';
import '../../../../core/sync/sync_issue_prefs.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../training/data/sync/training_sync_table_names.dart';
import '../../../training/data/services/training_repair_providers.dart';
import '../providers/sync_issue_center_provider.dart';
import '../../../../core/errors/result.dart';

class SyncIssueCenterScreen extends ConsumerStatefulWidget {
  const SyncIssueCenterScreen({super.key});

  @override
  ConsumerState<SyncIssueCenterScreen> createState() =>
      _SyncIssueCenterScreenState();
}

class _SyncIssueCenterScreenState extends ConsumerState<SyncIssueCenterScreen> {
  bool _isRepairing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncIssues = ref.watch(syncIssueCenterProvider);

    return AthlosScaffold(
      appBar: AppBar(title: Text(l10n.syncIssueCenterTitle)),
      body: asyncIssues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (issues) => RefreshIndicator(
          onRefresh: () async => ref.refresh(syncIssueCenterProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            children: [
              Text(
                l10n.syncIssueCenterDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Gap(AthlosSpacing.md),
              _RepairCard(
                issues: issues,
                isRepairing: _isRepairing,
                onRepair: _isRepairing ? null : _repairKnownIssues,
                onClearAll: _isRepairing ? null : _clearAll,
              ),
              const Gap(AthlosSpacing.sm),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0),
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                  title: Text(
                    l10n.syncIssueCenterAutoRepairDetailsTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  children: [
                    Text(
                      l10n.syncIssueCenterAutoRepairDetailsBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Gap(AthlosSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AthlosSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.syncIssueCenterManualSectionTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Gap(AthlosSpacing.sm),
                      Text(
                        l10n.syncIssueCenterManualSectionBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Gap(AthlosSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(RoutePaths.trainingWorkouts),
                        icon: const Icon(Icons.fitness_center_outlined),
                        label: Text(l10n.syncIssueCenterOpenTrainingAction),
                      ),
                      const Gap(AthlosSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push(RoutePaths.profileConflicts),
                        icon: const Icon(Icons.rule_folder_outlined),
                        label: Text(l10n.syncIssueCenterOpenDuplicatesAction),
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(AthlosSpacing.md),
              if (issues.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AthlosSpacing.md),
                    child: Text(l10n.syncIssueCenterEmpty),
                  ),
                )
              else
                ...issues.map((e) => _IssueTile(issue: e)),
              const Gap(AthlosSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  bool _looksLikeEmptyUuidIssue(SyncIssue issue) =>
      issue.message.contains('invalid input syntax for type uuid: ""');

  Future<void> _repairKnownIssues() async {
    final l10n = AppLocalizations.of(context)!;
    final authUser = ref.read(authProvider).value;
    if (authUser == null) return;

    setState(() => _isRepairing = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final store = SyncIssuePrefs(prefs);
      final issues = store.getAll();
      final hasWorkoutUuidIssues = issues.any(
        (e) =>
            e.tableName == TrainingSyncTableNames.workoutExercises &&
            _looksLikeEmptyUuidIssue(e),
      );

      var deleted = 0;
      if (hasWorkoutUuidIssues) {
        final userId = ref.read(authProvider).value!.id;
        final repair = ref.read(workoutSyncRepairServiceProvider);
        final result = await repair.purgeCorruptedRows(userId: userId);
        switch (result) {
          case Success(:final value):
            deleted += value;
          case Failure():
            // Surface the failure below as a generic error.
            throw Exception('repair failed');
        }
        await store.clearTable(TrainingSyncTableNames.workoutExercises);
      }

      // Best-effort attempt to sync after repair.
      await ref
          .read(userOwnedSyncRunnerProvider)
          .synchronizeTable(TrainingSyncTableNames.workoutExercises);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted > 0
                ? l10n.syncIssueCenterRepairDoneWithDeletes(deleted)
                : l10n.syncIssueCenterRepairDone,
          ),
        ),
      );
      ref.invalidate(syncIssueCenterProvider);
      await ref.read(syncIssueCenterProvider.future);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final store = SyncIssuePrefs(prefs);
      await store.clearAll();
      ref.invalidate(syncIssueCenterProvider);
      await ref.read(syncIssueCenterProvider.future);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.genericError)),
      );
    }
  }
}

class _RepairCard extends StatelessWidget {
  const _RepairCard({
    required this.issues,
    required this.isRepairing,
    required this.onRepair,
    required this.onClearAll,
  });

  final List<SyncIssue> issues;
  final bool isRepairing;
  final VoidCallback? onRepair;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = issues.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.syncIssueCenterOverviewTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(AthlosSpacing.xs),
            Text(l10n.syncIssueCenterOverviewCount(total)),
            const Gap(AthlosSpacing.md),
            FilledButton.icon(
              onPressed: onRepair,
              icon: isRepairing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build_outlined),
              label: Text(l10n.syncIssueCenterRepairAction),
            ),
            const Gap(AthlosSpacing.sm),
            OutlinedButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.syncIssueCenterClearAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final SyncIssue issue;

  @override
  Widget build(BuildContext context) {
    final date = intl.DateFormat.yMMMd().add_Hm().format(issue.occurredAtUtc.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.tableName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Gap(AthlosSpacing.xs),
            Text(
              date,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Gap(AthlosSpacing.sm),
            Text(issue.message),
          ],
        ),
      ),
    );
  }
}

