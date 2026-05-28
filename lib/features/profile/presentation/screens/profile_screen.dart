import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/providers/network_connectivity_provider.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/services/account_data_isolation_service.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../../../core/sync/sync_issue.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_trigger.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/app_bar_menu.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/widgets/layout/athlos_initials_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../kleos/presentation/screens/kleos_screen.dart';
import '../../../training/presentation/providers/training_analytics_provider.dart';
import '../../domain/entities/body_metric.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../helpers/profile_l10n.dart';
import '../providers/body_metric_notifier.dart';
import '../providers/conflict_center_provider.dart';
import '../providers/profile_notifier.dart';
import '../providers/sync_issue_center_provider.dart';
import '../providers/user_cloud_sync_status_provider.dart';
import '../widgets/body_metrics_dashboard_card.dart';
import '../widgets/owned_equipment_list.dart';
import 'profile_overview_edit_screen.dart';
import 'profile_training_edit_screen.dart';

double? _tryParseDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Placeholder profile for [Skeletonizer] on the hub.
const UserProfile _kProfileHubSkeletonPlaceholder = UserProfile(
  id: '_skeleton',
  name: 'Alexandre Costa',
  height: 178,
  age: 32,
  goal: TrainingGoal.hypertrophy,
  experienceLevel: ExperienceLevel.intermediate,
);

/// Profile view/edit screen (P-04).
///
/// Displays the current profile data. Tapping "Edit" switches
/// to edit mode with the same fields as the setup screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);
    final resolved = profileAsync.value ?? const UserProfile(id: '');

    return AthlosScaffold(
      appBar: AppBar(title: Text(l10n.profile), actions: [const AppBarMenu()]),
      body: profileAsync.hasError
          ? Center(child: Text(l10n.genericError))
          : Skeletonizer(
              enabled: profileAsync.isLoading,
              child: _buildProfileHub(
                profileAsync.isLoading
                    ? _kProfileHubSkeletonPlaceholder
                    : resolved,
                l10n,
              ),
            ),
    );
  }

  Widget _buildProfileHub(UserProfile profile, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final rawName = profile.name?.trim();
    final displayName = rawName != null && rawName.isNotEmpty
        ? rawName
        : l10n.profileHeroNamePlaceholder;

    final latestWeight = ref.watch(latestBodyWeightProvider).value;
    final subtitleParts = <String>[];
    if (profile.goal != null) {
      subtitleParts.add(_goalLabel(profile.goal!, l10n));
    }
    if (profile.experienceLevel != null) {
      subtitleParts.add(_experienceLabel(profile.experienceLevel!, l10n));
    }

    final bmi =
        profile.height != null && latestWeight != null && profile.height! > 0
        ? latestWeight / ((profile.height! / 100.0) * (profile.height! / 100.0))
        : null;
    final bmiLabel = bmi == null ? l10n.profileNotSet : bmi.toStringAsFixed(1);

    final conflictAsync = ref.watch(backupConflictCenterProvider);
    final syncIssuesAsync = ref.watch(syncIssueCenterProvider);
    final cloudSyncAsync = ref.watch(userCloudSyncStatusProvider);
    final showAccountBadge = _shortcutAccountShowsBadge(
      conflictAsync,
      syncIssuesAsync,
      cloudSyncAsync,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider);
        ref.invalidate(latestBodyWeightProvider);
        await ref.read(profileProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AthlosInitialsAvatar(displayName: profile.name),
                const Gap(AthlosSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(AthlosSpacing.xxs),
                      Text(
                        subtitleParts.isEmpty
                            ? l10n.profileHeroSubtitleIncomplete
                            : subtitleParts.join(' · '),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(AthlosSpacing.smd),
            LayoutBuilder(
              builder: (context, constraints) => _ProfileMetricChipGrid(
                maxWidth: constraints.maxWidth,
                chips: [
                  _ProfileMetricChipData(
                    label: l10n.profileAge,
                    value: profile.age != null
                        ? '${profile.age} ${l10n.yearsUnit}'
                        : l10n.profileNotSet,
                  ),
                  _ProfileMetricChipData(
                    label: l10n.profileHeight,
                    value: profile.height != null
                        ? '${profile.height!.toInt()} ${l10n.heightUnit}'
                        : l10n.profileNotSet,
                  ),
                  _ProfileMetricChipData(
                    label: l10n.profileWeight,
                    value: _formatWeight(latestWeight, l10n),
                  ),
                  _ProfileMetricChipData(
                    label: l10n.profileBmiChipLabel,
                    value: bmiLabel,
                  ),
                ],
              ),
            ),
            const Gap(AthlosSpacing.lg),
            _SectionHeader(title: l10n.profileShortcutsSectionTitle),
            const Gap(AthlosSpacing.xs),
            LayoutBuilder(
              builder: (context, constraints) {
                return _ProfileShortcutGrid(
                  maxWidth: constraints.maxWidth,
                  shortcuts: [
                    _ProfileShortcutSpec(
                      icon: Icons.badge_outlined,
                      label: l10n.profileShortcutPersonal,
                      onTap: () => _pushPersonalSubpage(
                        title: l10n.profileOverviewTab,
                        body: _buildPersonalDetailsCategory,
                      ),
                    ),
                    _ProfileShortcutSpec(
                      icon: Icons.flag_outlined,
                      label: l10n.profileShortcutGoals,
                      onTap: () => _pushPersonalSubpage(
                        title: l10n.profileSectionTraining,
                        body: _buildTrainingPreferencesCategory,
                      ),
                    ),
                    _ProfileShortcutSpec(
                      icon: Icons.monitor_weight_outlined,
                      label: l10n.profileShortcutMetrics,
                      onTap: () => _pushPersonalSubpage(
                        title: l10n.profileShortcutMetrics,
                        body: (_, l10n) => _buildMetricsDetailCategory(l10n),
                      ),
                    ),
                    _ProfileShortcutSpec(
                      icon: Icons.emoji_events_outlined,
                      label: l10n.profileShortcutKleos,
                      onTap: () => KleosScreen.open(context),
                    ),
                    _ProfileShortcutSpec(
                      icon: Icons.inventory_2_outlined,
                      label: l10n.profileShortcutEquipment,
                      onTap: () => _pushPersonalSubpage(
                        title: l10n.profileEquipmentTab,
                        body: (_, _) => const Padding(
                          padding: EdgeInsets.all(AthlosSpacing.md),
                          child: OwnedEquipmentList(),
                        ),
                      ),
                    ),
                    _ProfileShortcutSpec(
                      icon: Icons.cloud_outlined,
                      label: l10n.profileShortcutAccount,
                      showBadge: showAccountBadge,
                      onTap: () => _pushPersonalSubpage(
                        title: l10n.profileDataTab,
                        body: (_, l10n) => _buildDataCategory(l10n),
                      ),
                    ),
                  ],
                );
              },
            ),
            const Gap(AthlosSpacing.lg),
            _SectionHeader(title: l10n.profileConsistencySectionTitle),
            const Gap(AthlosSpacing.xs),
            _ProfileStreakSummaryCard(profile: profile, l10n: l10n),
            const Gap(AthlosSpacing.lg),
            const BodyMetricsDashboardCard(),
            const Gap(AthlosSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _pushPersonalSubpage({
    required String title,
    required Widget Function(UserProfile profile, AppLocalizations l10n) body,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => Consumer(
          builder: (context, ref, _) {
            final subL10n = AppLocalizations.of(context)!;
            final profileAsync = ref.watch(profileProvider);

            return AthlosScaffold(
              appBar: AppBar(title: Text(title)),
              body: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => Center(child: Text(subL10n.genericError)),
                data: (profile) =>
                    body(profile ?? const UserProfile(id: ''), subL10n),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _shortcutAccountShowsBadge(
    AsyncValue<ConflictCenterViewData> conflictAsync,
    AsyncValue<List<SyncIssue>> syncIssuesAsync,
    AsyncValue<UserCloudSyncStatus> cloudSyncAsync,
  ) {
    final duplicates = conflictAsync.value?.localDuplicateCount ?? 0;
    if (duplicates > 0) return true;
    final issues = syncIssuesAsync.value?.length ?? 0;
    if (issues > 0) return true;
    final cloud = cloudSyncAsync.value;
    if (cloud != null &&
        cloud.isAvailable &&
        (cloud.hasPending || cloud.hasFailed)) {
      return true;
    }
    return false;
  }

  Widget _buildPersonalDetailsCategory(
    UserProfile profile,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: l10n.profileSectionPersonal),
          const Gap(AthlosSpacing.xs),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AthlosSpacing.sm,
                horizontal: AthlosSpacing.md,
              ),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.person_outline,
                    label: l10n.profileName,
                    value: profile.name ?? l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.monitor_weight_outlined,
                    label: l10n.profileWeight,
                    value: _formatWeight(
                      ref.watch(latestBodyWeightProvider).value,
                      l10n,
                    ),
                  ),
                  _ProfileTile(
                    icon: Icons.height,
                    label: l10n.profileHeight,
                    value: profile.height != null
                        ? '${profile.height} ${l10n.heightUnit}'
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.cake_outlined,
                    label: l10n.profileAge,
                    value: profile.age != null
                        ? '${profile.age} ${l10n.yearsUnit}'
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.wc,
                    label: l10n.profileGender,
                    value: profile.gender != null
                        ? _genderLabel(profile.gender!, l10n)
                        : l10n.profileNotSet,
                  ),
                ],
              ),
            ),
          ),
          const Gap(AthlosSpacing.md),
          _SectionHeader(title: l10n.profileSectionHealth),
          const Gap(AthlosSpacing.xs),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AthlosSpacing.sm,
                horizontal: AthlosSpacing.md,
              ),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.healing,
                    label: l10n.profileInjuries,
                    value: profile.injuries ?? l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.auto_stories,
                    label: l10n.profileBio,
                    value: profile.bio ?? l10n.profileNotSet,
                  ),
                ],
              ),
            ),
          ),
          const Gap(AthlosSpacing.lg),
          FilledButton.icon(
            onPressed: () => ProfileOverviewEditScreen.open(context),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.profileHeroEditProfileAction),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsDetailCategory(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BodyMetricsDashboardCard(),
          const Gap(AthlosSpacing.md),
          const _BodyMetricsSection(),
        ],
      ),
    );
  }

  Widget _buildTrainingPreferencesCategory(
    UserProfile profile,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: l10n.profileSectionTraining),
          const Gap(AthlosSpacing.xs),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AthlosSpacing.sm,
                horizontal: AthlosSpacing.md,
              ),
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.flag_outlined,
                    label: l10n.profileGoal,
                    value: profile.goal != null
                        ? _goalLabel(profile.goal!, l10n)
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.sports_gymnastics,
                    label: l10n.profileAesthetic,
                    value: profile.bodyAesthetic != null
                        ? _aestheticLabel(profile.bodyAesthetic!, l10n)
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.sync_alt,
                    label: l10n.profileStyle,
                    value: profile.trainingStyle != null
                        ? _styleLabel(profile.trainingStyle!, l10n)
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.trending_up,
                    label: l10n.profileExperience,
                    value: profile.experienceLevel != null
                        ? _experienceLabel(profile.experienceLevel!, l10n)
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.calendar_today,
                    label: l10n.profileFrequency,
                    value: profile.trainingFrequency != null
                        ? '${profile.trainingFrequency}x ${l10n.perWeek}'
                        : l10n.profileNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.timer_outlined,
                    label: l10n.profileAvailableWorkoutMinutes,
                    value: profile.availableWorkoutMinutes != null
                        ? l10n.profileAvailableWorkoutMinutesValue(
                            profile.availableWorkoutMinutes!,
                          )
                        : l10n.profileAvailableWorkoutMinutesNotSet,
                  ),
                  _ProfileTile(
                    icon: Icons.store,
                    label: l10n.profileGym,
                    value: profile.trainsAtGym != null
                        ? (profile.trainsAtGym! ? l10n.yes : l10n.no)
                        : l10n.profileNotSet,
                  ),
                ],
              ),
            ),
          ),
          const Gap(AthlosSpacing.lg),
          FilledButton.icon(
            onPressed: () => ProfileTrainingEditScreen.open(context),
            icon: const Icon(Icons.edit),
            label: Text(l10n.edit),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCategory(AppLocalizations l10n) {
    final conflictCenterAsync = ref.watch(backupConflictCenterProvider);
    final syncIssuesAsync = ref.watch(syncIssueCenterProvider);
    final authAsync = ref.watch(authProvider);
    final authUser = authAsync.value;
    final isDataLoading =
        authAsync.isLoading ||
        conflictCenterAsync.isLoading ||
        syncIssuesAsync.isLoading;

    return Skeletonizer(
      enabled: isDataLoading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: l10n.authAccountSectionTitle),
            const Gap(AthlosSpacing.xs),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AthlosSpacing.sm,
                  horizontal: AthlosSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileTile(
                      icon: authUser != null
                          ? Icons.verified_user_outlined
                          : Icons.account_circle_outlined,
                      label: l10n.profileDataAccountSessionLabel,
                      value: authUser?.email ?? l10n.authNotSignedIn,
                    ),
                    const Gap(AthlosSpacing.md),
                    if (authUser == null)
                      FilledButton.icon(
                        onPressed: authAsync.isLoading
                            ? null
                            : () => context.push(RoutePaths.authPrompt),
                        icon: const Icon(Icons.login),
                        label: Text(l10n.authOpenAccountAction),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _isSigningOut || authAsync.isLoading
                            ? null
                            : () => _signOut(l10n),
                        icon: _isSigningOut
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: Text(l10n.authLogoutAction),
                      ),
                  ],
                ),
              ),
            ),
            const Gap(AthlosSpacing.md),
            const _CloudSyncStatusCard(),
            const Gap(AthlosSpacing.md),
            _SectionHeader(title: l10n.profileDataConflictsSectionTitle),
            const Gap(AthlosSpacing.xs),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileConflictStatusBanner(
                      conflictCenterAsync: conflictCenterAsync,
                    ),
                    const Gap(AthlosSpacing.sm),
                    Text(
                      l10n.profileDataConflictSummaryLocalHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(AthlosSpacing.md),
                    _ProfileDataNavRow(
                      icon: Icons.rule_folder_outlined,
                      title: l10n.conflictCenterTitle,
                      subtitle: l10n.tapToOpen,
                      onTap: () => context.push(RoutePaths.profileConflicts),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(AthlosSpacing.md),
            _SectionHeader(title: l10n.profileDataSyncIssuesSectionTitle),
            const Gap(AthlosSpacing.xs),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AthlosSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SyncIssueStatusBanner(syncIssuesAsync: syncIssuesAsync),
                    const Gap(AthlosSpacing.md),
                    _ProfileDataNavRow(
                      icon: Icons.sync_problem_outlined,
                      title: l10n.syncIssueCenterTitle,
                      subtitle: l10n.tapToOpen,
                      onTap: () => context.push(RoutePaths.profileSyncIssues),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(AthlosSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmSignOutWithUnsyncedData(
    AppLocalizations l10n,
    int dirtyCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authSignOutUnsyncedTitle),
        content: Text(l10n.authSignOutUnsyncedMessage(dirtyCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.authSignOutConfirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _signOut(AppLocalizations l10n) async {
    final dirtyCount = await ref.read(pendingSyncDirtyCountProvider.future);
    if (dirtyCount > 0) {
      final confirmed = await _confirmSignOutWithUnsyncedData(l10n, dirtyCount);
      if (!confirmed || !mounted) return;
    }

    setState(() => _isSigningOut = true);
    try {
      if (ref.read(isNetworkAvailableForSyncProvider)) {
        try {
          await ref
              .read(userDataSyncCoordinatorProvider)
              .synchronizeAuthenticatedUserData(
                trigger: SyncTrigger.sessionChange,
              );
        } on Exception {
          // Best-effort sync — proceed with logout regardless.
        }
      }

      await ref.read(accountDataIsolationServiceProvider).wipeUserData();
      await ref.read(authProvider.notifier).signOut();
      if (!mounted) return;
      context.go(RoutePaths.authPrompt);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  String _formatWeight(double? weight, AppLocalizations l10n) {
    if (weight == null) return l10n.profileNotSet;
    final str = weight % 1 == 0
        ? weight.toInt().toString()
        : weight.toStringAsFixed(1);
    return '$str ${l10n.weightUnit}';
  }

  String _goalLabel(TrainingGoal goal, AppLocalizations l10n) =>
      localizedTrainingGoalName(goal, l10n);

  String _aestheticLabel(BodyAesthetic aesthetic, AppLocalizations l10n) =>
      localizedBodyAestheticName(aesthetic, l10n);

  String _styleLabel(TrainingStyle style, AppLocalizations l10n) =>
      localizedTrainingStyleName(style, l10n);

  String _experienceLabel(ExperienceLevel level, AppLocalizations l10n) =>
      localizedExperienceLevelName(level, l10n);

  String _genderLabel(Gender gender, AppLocalizations l10n) =>
      localizedGenderName(gender, l10n);
}

class _ProfileMetricChipData {
  const _ProfileMetricChipData({required this.label, required this.value});

  final String label;
  final String value;
}

/// Two metric chips per row, each expanding to half the available width.
class _ProfileMetricChipGrid extends StatelessWidget {
  const _ProfileMetricChipGrid({required this.maxWidth, required this.chips});

  static const int _columns = 2;
  static const double _spacing = AthlosSpacing.sm;

  final double maxWidth;
  final List<_ProfileMetricChipData> chips;

  @override
  Widget build(BuildContext context) {
    final chipWidth = (maxWidth - _spacing) / _columns;

    return Column(
      children: [
        for (var row = 0; row < chips.length; row += _columns) ...[
          if (row > 0) const Gap(_spacing),
          Row(
            children: [
              for (var col = 0; col < _columns; col++) ...[
                if (col > 0) const Gap(_spacing),
                SizedBox(
                  width: chipWidth,
                  child: _ProfileMetricChip(
                    label: chips[row + col].label,
                    value: chips[row + col].value,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ProfileMetricChip extends StatelessWidget {
  const _ProfileMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.smd,
        vertical: AthlosSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: AthlosRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProfileShortcutSpec {
  const _ProfileShortcutSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;
}

/// Three equal-width shortcut tiles per row with uniform height.
class _ProfileShortcutGrid extends StatelessWidget {
  const _ProfileShortcutGrid({required this.maxWidth, required this.shortcuts});

  static const int _columns = 3;
  static const double _spacing = AthlosSpacing.sm;
  static const double _tileHeight = 110;

  final double maxWidth;
  final List<_ProfileShortcutSpec> shortcuts;

  @override
  Widget build(BuildContext context) {
    final tileWidth = (maxWidth - _spacing * (_columns - 1)) / _columns;

    return Column(
      children: [
        for (var row = 0; row < shortcuts.length; row += _columns) ...[
          if (row > 0) const Gap(_spacing),
          Row(
            children: [
              for (var col = 0; col < _columns; col++) ...[
                if (col > 0) const Gap(_spacing),
                if (row + col < shortcuts.length)
                  _ProfileHubShortcutTile(
                    width: tileWidth,
                    height: _tileHeight,
                    icon: shortcuts[row + col].icon,
                    label: shortcuts[row + col].label,
                    showBadge: shortcuts[row + col].showBadge,
                    onTap: shortcuts[row + col].onTap,
                  )
                else
                  SizedBox(width: tileWidth, height: _tileHeight),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ProfileHubShortcutTile extends StatelessWidget {
  const _ProfileHubShortcutTile({
    required this.width,
    required this.height,
    required this.icon,
    required this.label,
    required this.onTap,
    this.showBadge = false,
  });

  final double width;
  final double height;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  static const double _labelAreaHeight = 36;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: AthlosRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AthlosSpacing.sm,
              horizontal: AthlosSpacing.xs,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: showBadge,
                  backgroundColor: colorScheme.error,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: AthlosRadius.mdAll,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AthlosSpacing.smd),
                      child: Icon(
                        icon,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const Gap(AthlosSpacing.sm),
                SizedBox(
                  height: _labelAreaHeight,
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStreakSummaryCard extends ConsumerWidget {
  const _ProfileStreakSummaryCard({required this.profile, required this.l10n});

  final UserProfile profile;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sessionCount = ref.watch(finishedSessionCountProvider).value ?? 0;
    final freq = profile.currentFrequencyStreak;
    final bestFreq = profile.bestFrequencyStreak;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.fitness_center_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    l10n.dashboardFinishedSessionsCount(sessionCount),
                    style: textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: colorScheme.tertiary,
                    size: 22,
                  ),
                  const Gap(AthlosSpacing.xs),
                  Text(
                    l10n.dashboardConsistencyStreak(freq),
                    style: textTheme.titleSmall,
                  ),
                  if (bestFreq > 0) ...[
                    const Gap(AthlosSpacing.xxs),
                    Text(
                      l10n.dashboardStreakBestFrequency(bestFreq),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title in profile (read and edit views).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

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

/// A single profile data row.
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AthlosSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 24),
          const Gap(AthlosSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileConflictStatusBanner extends StatelessWidget {
  const _ProfileConflictStatusBanner({required this.conflictCenterAsync});

  final AsyncValue<ConflictCenterViewData> conflictCenterAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>()!;

    return conflictCenterAsync.when(
      loading: () => _ProfileConflictStatusSurface(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        icon: Icons.hourglass_empty_outlined,
        message: l10n.profileDataConflictSummaryLoading,
      ),
      error: (_, _) => _ProfileConflictStatusSurface(
        backgroundColor: colorScheme.errorContainer,
        foregroundColor: colorScheme.onErrorContainer,
        icon: Icons.error_outline,
        message: l10n.profileDataConflictSummaryError,
      ),
      data: (summary) {
        final duplicateCount = summary.localDuplicateCount;
        if (duplicateCount == 0) {
          return _ProfileConflictStatusSurface(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurfaceVariant,
            iconColor: colorScheme.primary,
            icon: Icons.check_circle_outline,
            message: l10n.profileDataConflictStatusClear,
          );
        }

        final warningStyle = customColors.duplicateWarningCallout(colorScheme);

        return _ProfileConflictStatusSurface(
          backgroundColor: warningStyle.background,
          foregroundColor: warningStyle.foreground,
          iconColor: warningStyle.icon,
          icon: Icons.warning_amber_rounded,
          message: l10n.profileDataLocalConflictSummary(duplicateCount),
        );
      },
    );
  }
}

class _SyncIssueStatusBanner extends StatelessWidget {
  const _SyncIssueStatusBanner({required this.syncIssuesAsync});

  final AsyncValue<List<SyncIssue>> syncIssuesAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<AthlosCustomColors>()!;

    return syncIssuesAsync.when(
      loading: () => _ProfileConflictStatusSurface(
        backgroundColor: colorScheme.surfaceContainerHigh,
        foregroundColor: colorScheme.onSurfaceVariant,
        icon: Icons.hourglass_empty_outlined,
        message: l10n.profileDataSyncIssueSummaryLoading,
      ),
      error: (_, _) => _ProfileConflictStatusSurface(
        backgroundColor: colorScheme.errorContainer,
        foregroundColor: colorScheme.onErrorContainer,
        icon: Icons.error_outline,
        message: l10n.profileDataSyncIssueSummaryError,
      ),
      data: (issues) {
        final count = issues.length;
        if (count == 0) {
          return _ProfileConflictStatusSurface(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurfaceVariant,
            iconColor: colorScheme.primary,
            icon: Icons.check_circle_outline,
            message: l10n.profileDataSyncIssueStatusClear,
          );
        }

        final warningStyle = customColors.duplicateWarningCallout(colorScheme);
        return _ProfileConflictStatusSurface(
          backgroundColor: warningStyle.background,
          foregroundColor: warningStyle.foreground,
          iconColor: warningStyle.icon,
          icon: Icons.sync_problem_outlined,
          message: l10n.profileDataSyncIssueSummaryCount(count),
        );
      },
    );
  }
}

class _ProfileConflictStatusSurface extends StatelessWidget {
  const _ProfileConflictStatusSurface({
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

class _ProfileDataNavRow extends StatelessWidget {
  const _ProfileDataNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: AthlosRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          minTileHeight: AthlosComponentSizes.listItemMinHeight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.md,
            vertical: AthlosSpacing.xs,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AthlosRadius.mdAll,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _BodyMetricsSection extends ConsumerWidget {
  const _BodyMetricsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final metricsAsync = ref.watch(bodyMetricListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: l10n.bodyMetricsSectionTitle),
        const Gap(AthlosSpacing.xs),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: metricsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => Text(l10n.genericError),
              data: (metrics) {
                if (metrics.isEmpty) {
                  return Column(
                    children: [
                      Text(
                        l10n.bodyMetricsEmptyHint,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AthlosSpacing.sm),
                      FilledButton.tonal(
                        onPressed: () => _showRecordDialog(context, ref),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add),
                            const Gap(AthlosSpacing.xs),
                            Text(l10n.bodyMetricsRecordWeight),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final latest = metrics.first;
                final weightStr = latest.weight % 1 == 0
                    ? latest.weight.toInt().toString()
                    : latest.weight.toStringAsFixed(1);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const Gap(AthlosSpacing.sm),
                        Text(
                          l10n.bodyMetricsLatest(weightStr),
                          style: textTheme.titleSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: l10n.bodyMetricsRecordWeight,
                          onPressed: () => _showRecordDialog(context, ref),
                        ),
                      ],
                    ),
                    if (metrics.length >= 2) ...[
                      const Gap(AthlosSpacing.sm),
                      _MiniWeightChart(metrics: metrics),
                    ],
                    if (metrics.length > 1) ...[
                      const Gap(AthlosSpacing.xs),
                      TextButton(
                        onPressed: () =>
                            _showFullHistory(context, ref, metrics),
                        child: Text(l10n.bodyMetricsHistory),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showRecordDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final weightCtrl = TextEditingController();
    final bfCtrl = TextEditingController();

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bodyMetricsRecordWeight),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: weightCtrl,
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsWeightLabel,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              autofocus: true,
            ),
            const Gap(AthlosSpacing.md),
            TextField(
              controller: bfCtrl,
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsBodyFatLabel,
                hintText: l10n.bodyMetricsBodyFatHint,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () {
                  final w = _tryParseDecimal(weightCtrl.text);
                  if (w == null || w <= 0) return;
                  final bf = _tryParseDecimal(bfCtrl.text);
                  ref
                      .read(bodyMetricListProvider.notifier)
                      .add(weight: w, bodyFatPercent: bf);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.programSaveAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullHistory(
    BuildContext context,
    WidgetRef ref,
    List<BodyMetric> metrics,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showAthlosModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      wrapInShell: false,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => AthlosBottomSheetShell(
          expand: true,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Text(
                l10n.bodyMetricsHistory,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: metrics.length,
                itemBuilder: (ctx, i) {
                  final m = metrics[i];
                  final date =
                      '${m.recordedAt.day}/${m.recordedAt.month}/${m.recordedAt.year}';
                  final weightStr = m.weight % 1 == 0
                      ? m.weight.toInt().toString()
                      : m.weight.toStringAsFixed(1);
                  return ListTile(
                    title: Text('$weightStr kg'),
                    subtitle: Text(date),
                    trailing: m.bodyFatPercent != null
                        ? Text('${m.bodyFatPercent!.toStringAsFixed(1)}%')
                        : null,
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _CloudSyncStatusCard extends ConsumerStatefulWidget {
  const _CloudSyncStatusCard();

  @override
  ConsumerState<_CloudSyncStatusCard> createState() =>
      _CloudSyncStatusCardState();
}

class _CloudSyncStatusCardState extends ConsumerState<_CloudSyncStatusCard> {
  var _isRetrying = false;

  Future<void> _retryCloudSync(AppLocalizations l10n) async {
    if (!ref.read(isNetworkAvailableForSyncProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileDataCloudSyncOfflineSnack)),
      );
      return;
    }

    setState(() => _isRetrying = true);
    try {
      await ref.read(userDataSyncCoordinatorProvider).synchronizeManual();
      if (!mounted) return;

      final status = await ref.read(userCloudSyncStatusProvider.future);
      if (!mounted) return;

      ref.invalidate(userCloudSyncStatusProvider);

      final messenger = ScaffoldMessenger.of(context);
      if (status.isUpToDate) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.profileDataCloudSyncSuccessSnack)),
        );
      } else if (status.hasFailed || status.hasPending) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.profileDataCloudSyncFailedSnack(
                status.failedCount,
                status.pendingCount,
              ),
            ),
          ),
        );
      }
    } on Exception catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileDataCloudSyncRetryError)),
      );
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  String _formatSyncTimestamp(BuildContext context, DateTime instant) {
    final locale = Localizations.localeOf(context).toString();
    return intl.DateFormat(
      'dd/MM/yyyy HH:mm',
      locale,
    ).format(instant.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final syncStatusAsync = ref.watch(userCloudSyncStatusProvider);
    final isOnline = ref.watch(isNetworkAvailableForSyncProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: l10n.profileDataCloudSyncSectionTitle),
        const Gap(AthlosSpacing.xs),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: syncStatusAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Text(
                l10n.profileDataCloudSyncRetryError,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              data: (status) {
                if (!status.isAvailable) {
                  return Text(
                    l10n.profileDataCloudSyncUnavailable,
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }

                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;
                final statusColor = !isOnline
                    ? colorScheme.onSurfaceVariant
                    : status.hasFailed
                    ? colorScheme.error
                    : status.hasPending
                    ? colorScheme.tertiary
                    : status.isUpToDate
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant;
                final statusIcon = !isOnline
                    ? Icons.cloud_off_outlined
                    : status.hasFailed
                    ? Icons.cloud_off
                    : status.hasPending
                    ? Icons.cloud_sync
                    : status.isUpToDate
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined;
                final statusLabel = !isOnline
                    ? l10n.profileDataCloudSyncUnavailable
                    : status.hasFailed
                    ? l10n.profileDataCloudSyncFailed(status.failedCount)
                    : status.hasPending
                    ? l10n.profileDataCloudSyncPending(status.pendingCount)
                    : status.isUpToDate
                    ? l10n.profileDataCloudSyncClear
                    : l10n.profileDataCloudSyncNeverSynced;

                final lastSuccess = status.lastSuccessfulSyncAt;
                final lastAttempt = status.lastAttemptAt;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 22),
                        const Gap(AthlosSpacing.sm),
                        Expanded(
                          child: Text(
                            statusLabel,
                            style: textTheme.bodyMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(AthlosSpacing.md),
                    if (lastSuccess != null) ...[
                      Text(
                        l10n.profileDataCloudSyncLastSuccessLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AthlosSpacing.xs),
                      Text(
                        _formatSyncTimestamp(context, lastSuccess),
                        style: textTheme.titleSmall,
                      ),
                    ] else
                      Text(
                        l10n.profileDataCloudSyncNeverSynced,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (lastAttempt != null &&
                        lastSuccess != null &&
                        lastAttempt.difference(lastSuccess).inSeconds.abs() >
                            2) ...[
                      const Gap(AthlosSpacing.sm),
                      Text(
                        l10n.profileDataCloudSyncLastAttemptLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AthlosSpacing.xs),
                      Text(
                        _formatSyncTimestamp(context, lastAttempt),
                        style: textTheme.bodySmall,
                      ),
                    ],
                    if (!isOnline) ...[
                      const Gap(AthlosSpacing.sm),
                      Text(
                        l10n.profileDataCloudSyncUnavailable,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Gap(AthlosSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _isRetrying || !isOnline
                          ? null
                          : () => _retryCloudSync(l10n),
                      icon: _isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync),
                      label: Text(l10n.profileDataCloudSyncRetryAction),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact sparkline-style chart showing weight trend.
class _MiniWeightChart extends StatelessWidget {
  final List<BodyMetric> metrics;

  const _MiniWeightChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reversed = metrics.reversed.toList();
    if (reversed.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: CustomPaint(
        size: const Size(double.infinity, 60),
        painter: _SparklinePainter(
          values: reversed.map((m) => m.weight).toList(),
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;
    final effectiveRange = range < 0.1 ? 1.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y =
          size.height - ((values[i] - minV) / effectiveRange) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      values != oldDelegate.values || color != oldDelegate.color;
}
