import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/widgets/feedback/athlos_messenger.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/presentation/dialogs/confirm_destructive_action_dialog.dart';
import '../../../../core/providers/last_module_provider.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../../../core/sync/sync_issue.dart';
import '../../../../core/sync/sync_issue_prefs.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../training/data/services/training_repair_providers.dart';
import '../../../training/data/sync/training_sync_table_names.dart';
import '../providers/sync_issue_center_provider.dart';
import '../providers/user_cloud_sync_status_provider.dart';

class SyncIssueCenterScreen extends ConsumerStatefulWidget {
  const SyncIssueCenterScreen({super.key});

  @override
  ConsumerState<SyncIssueCenterScreen> createState() =>
      _SyncIssueCenterScreenState();
}

class _SyncIssueCenterScreenState extends ConsumerState<SyncIssueCenterScreen> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncIssues = ref.watch(syncIssueCenterProvider);

    return AthlosScaffold(
      appBar: AppBar(title: Text(l10n.syncIssueCenterTitle)),
      body: asyncIssues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (issues) => _SyncIssueCenterContent(
          issues: issues,
          isBusy: _isBusy,
          onRefresh: () async {
            ref.invalidate(syncIssueCenterProvider);
            await ref.read(syncIssueCenterProvider.future);
          },
          onSyncNow: _isBusy ? null : () => _syncNow(l10n),
          onClearList: _isBusy || issues.isEmpty
              ? null
              : () => _clearAll(l10n),
          onRepairWorkouts: _isBusy || !_hasRepairableWorkoutIssues(issues)
              ? null
              : () => _repairWorkoutIssues(l10n),
        ),
      ),
    );
  }

  bool _hasRepairableWorkoutIssues(List<SyncIssue> issues) => issues.any(
    (e) =>
        e.tableName == TrainingSyncTableNames.workoutExercises &&
        _looksLikeEmptyUuidIssue(e),
  );

  bool _looksLikeEmptyUuidIssue(SyncIssue issue) =>
      issue.message.contains('invalid input syntax for type uuid: ""');

  Future<void> _syncNow(AppLocalizations l10n) async {
    if (ref.read(authProvider).value == null) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(userDataSyncCoordinatorProvider).synchronizeManual();
      if (!mounted) return;
      _refreshAfterAction();
      context.showAthlosSuccessSnack(l10n.profileDataCloudSyncSuccessSnack);
    } on Exception {
      if (!mounted) return;
      context.showAthlosErrorSnack(l10n.profileDataCloudSyncRetryError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _repairWorkoutIssues(AppLocalizations l10n) async {
    final authUser = ref.read(authProvider).value;
    if (authUser == null) return;

    final confirmed = await confirmDestructiveAction(
      context,
      title: l10n.syncIssueCenterConfirmRepairTitle,
      message: l10n.syncIssueCenterConfirmRepairMessage,
      confirmLabel: l10n.syncIssueCenterRepairAction,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final store = SyncIssuePrefs(prefs);
      final userId = authUser.id;
      final repair = ref.read(workoutSyncRepairServiceProvider);
      final result = await repair.purgeCorruptedRows(userId: userId);
      switch (result) {
        case Success(:final value):
          await store.clearTable(TrainingSyncTableNames.workoutExercises);
          await ref
              .read(userOwnedSyncRunnerProvider)
              .synchronizeTable(TrainingSyncTableNames.workoutExercises);
          if (!mounted) return;
          _refreshAfterAction();
          context.showAthlosSuccessSnack(
            value > 0
                ? l10n.syncIssueCenterRepairDoneWithDeletes(value)
                : l10n.syncIssueCenterRepairDone,
          );
        case Failure():
          throw Exception('repair failed');
      }
    } on Exception {
      if (!mounted) return;
      context.showAthlosErrorSnack(l10n.genericError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _clearAll(AppLocalizations l10n) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: l10n.syncIssueCenterConfirmClearTitle,
      message: l10n.syncIssueCenterConfirmClearMessage,
      confirmLabel: l10n.syncIssueCenterClearAction,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await SyncIssuePrefs(prefs).clearAll();
      if (!mounted) return;
      _refreshAfterAction();
      context.showAthlosSnack(l10n.syncIssueCenterClearDoneSnack);
    } on Exception {
      if (!mounted) return;
      context.showAthlosErrorSnack(l10n.genericError);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _refreshAfterAction() {
    ref.invalidate(syncIssueCenterProvider);
    ref.invalidate(userCloudSyncStatusProvider);
    ref.invalidate(pendingSyncDirtyCountProvider);
  }
}

class _SyncIssueCenterContent extends StatelessWidget {
  const _SyncIssueCenterContent({
    required this.issues,
    required this.isBusy,
    required this.onRefresh,
    required this.onSyncNow,
    required this.onClearList,
    required this.onRepairWorkouts,
  });

  final List<SyncIssue> issues;
  final bool isBusy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onSyncNow;
  final VoidCallback? onClearList;
  final VoidCallback? onRepairWorkouts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AthlosSpacing.md,
                AthlosSpacing.sm,
                AthlosSpacing.md,
                AthlosSpacing.md,
              ),
              children: [
                Text(
                  l10n.syncIssueCenterDescription,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const Gap(AthlosSpacing.md),
                if (issues.isEmpty)
                  _EmptyState(message: l10n.syncIssueCenterEmpty)
                else ...[
                  Text(
                    l10n.syncIssueCenterIssuesSection(issues.length),
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(AthlosSpacing.sm),
                  ...issues.map(
                    (issue) => Padding(
                      padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
                      child: _IssueTile(issue: issue),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.sm,
            ),
            child: AthlosStackedActions(
              children: [
                FilledButton(
                  style: AthlosScreenButtonStyles.stackedFilled(context),
                  onPressed: onSyncNow,
                  child: isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.profileDataCloudSyncRetryAction),
                ),
                if (onRepairWorkouts != null)
                  OutlinedButton(
                    style: AthlosScreenButtonStyles.stackedOutlined(context),
                    onPressed: onRepairWorkouts,
                    child: Text(l10n.syncIssueCenterRepairAction),
                  ),
                if (onClearList != null)
                  TextButton(
                    style: AthlosScreenButtonStyles.stackedGhost(context),
                    onPressed: onClearList,
                    child: Text(l10n.syncIssueCenterClearAction),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.md,
          vertical: AthlosSpacing.lg,
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 40,
              color: colorScheme.primary.withValues(alpha: 0.85),
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final date = intl.DateFormat.yMMMd().add_Hm().format(
      issue.occurredAtUtc.toLocal(),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.md,
          vertical: AthlosSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: colorScheme.error,
                ),
                const Gap(AthlosSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tableLabel(l10n, issue.tableName),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Gap(AthlosSpacing.xxs),
                      Text(
                        date,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(AthlosSpacing.sm),
            Text(
              _shortMessage(issue.message),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static String _shortMessage(String raw) {
    const maxLen = 160;
    final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= maxLen) return oneLine;
    return '${oneLine.substring(0, maxLen)}…';
  }
}

String _tableLabel(AppLocalizations l10n, String tableName) {
  return switch (tableName) {
    TrainingSyncTableNames.exercises => l10n.syncIssueTableExercises,
    TrainingSyncTableNames.workouts => l10n.syncIssueTableWorkouts,
    TrainingSyncTableNames.workoutExercises => l10n.syncIssueTableWorkoutExercises,
    TrainingSyncTableNames.programs => l10n.syncIssueTablePrograms,
    TrainingSyncTableNames.progressionRules => l10n.syncIssueTableProgressionRules,
    TrainingSyncTableNames.cycleSteps => l10n.syncIssueTableCycleSteps,
    TrainingSyncTableNames.workoutExecutions => l10n.syncIssueTableWorkoutExecutions,
    TrainingSyncTableNames.executionSets => l10n.syncIssueTableExecutionSets,
    _ => tableName,
  };
}
