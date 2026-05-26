import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_custom_colors.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/widgets/app_bar_menu.dart';
import '../../../../core/widgets/layout/athlos_initials_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../helpers/profile_l10n.dart';
import '../../domain/entities/body_metric.dart';
import '../providers/body_metric_notifier.dart';
import '../../../../core/providers/network_connectivity_provider.dart';
import '../../../../core/services/account_data_isolation_service.dart';
import '../../../../core/services/user_data_sync_coordinator.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/sync/sync_trigger.dart';
import '../../../../core/sync/sync_issue.dart';
import '../providers/conflict_center_provider.dart';
import '../providers/sync_issue_center_provider.dart';
import '../providers/profile_notifier.dart';
import '../providers/user_cloud_sync_status_provider.dart';
import '../widgets/aesthetic_selector.dart';
import '../widgets/experience_selector.dart';
import '../widgets/owned_equipment_list.dart';
import '../widgets/goal_selector.dart';
import '../widgets/style_selector.dart';

double? _tryParseDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Profile view/edit screen (P-04).
///
/// Displays the current profile data. Tapping "Edit" switches
/// to edit mode with the same fields as the setup screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

enum _EditingTab { none, overview, training }

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _EditingTab _editingTab = _EditingTab.none;
  bool _isSigningOut = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _workoutMinutesController = TextEditingController();
  final _injuriesController = TextEditingController();
  final _bioController = TextEditingController();
  Gender? _selectedGender;
  TrainingGoal? _selectedGoal;
  BodyAesthetic? _selectedAesthetic;
  TrainingStyle? _selectedStyle;
  ExperienceLevel? _selectedExperience;
  int? _trainingFrequency;
  int? _availableWorkoutMinutes;
  bool? _trainsAtGym;

  String? _overviewEditBaseline;
  String? _trainingEditBaseline;

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _workoutMinutesController.dispose();
    _injuriesController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _startEditingOverview(UserProfile profile) {
    _nameController.text = profile.name ?? '';
    _heightController.text = profile.height?.toString() ?? '';
    _ageController.text = profile.age?.toString() ?? '';
    _selectedGender = profile.gender;
    _injuriesController.text = profile.injuries ?? '';
    _bioController.text = profile.bio ?? '';
    _trainingEditBaseline = null;
    setState(() {
      _editingTab = _EditingTab.overview;
      _overviewEditBaseline = _snapshotOverviewEdit();
    });
  }

  void _startEditingTraining(UserProfile profile) {
    _selectedGoal = profile.goal;
    _selectedAesthetic = profile.bodyAesthetic;
    _selectedStyle = profile.trainingStyle;
    _selectedExperience = profile.experienceLevel;
    _trainingFrequency = profile.trainingFrequency;
    _availableWorkoutMinutes = profile.availableWorkoutMinutes;
    _workoutMinutesController.text =
        profile.availableWorkoutMinutes?.toString() ?? '60';
    _trainsAtGym = profile.trainsAtGym;
    _overviewEditBaseline = null;
    setState(() {
      _editingTab = _EditingTab.training;
      _trainingEditBaseline = _snapshotTrainingEdit();
    });
  }

  String _snapshotOverviewEdit() => [
    _nameController.text,
    _heightController.text,
    _ageController.text,
    _injuriesController.text,
    _bioController.text,
    _selectedGender?.name ?? 'null',
  ].join('\u001e');

  String _snapshotTrainingEdit() => [
    _selectedGoal?.name ?? 'null',
    _selectedAesthetic?.name ?? 'null',
    _selectedStyle?.name ?? 'null',
    _selectedExperience?.name ?? 'null',
    '${_trainingFrequency ?? -1}',
    '${_availableWorkoutMinutes ?? -1}',
    _workoutMinutesController.text,
    '${_trainsAtGym ?? -1}',
  ].join('\u001e');

  bool get _isProfileEditDirty {
    if (_editingTab == _EditingTab.overview && _overviewEditBaseline != null) {
      return _snapshotOverviewEdit() != _overviewEditBaseline;
    }
    if (_editingTab == _EditingTab.training && _trainingEditBaseline != null) {
      return _snapshotTrainingEdit() != _trainingEditBaseline;
    }
    return false;
  }

  Future<void> _cancelEditing() async {
    if (!_isProfileEditDirty) {
      setState(() => _editingTab = _EditingTab.none);
      return;
    }
    final discard = await confirmDiscardUnsavedEdits(context);
    if (!mounted) return;
    if (discard) {
      setState(() {
        _editingTab = _EditingTab.none;
        _overviewEditBaseline = null;
        _trainingEditBaseline = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);
    final resolved = profileAsync.value ?? const UserProfile(id: '');

    final isEditing = _editingTab != _EditingTab.none;

    return ConfirmNavigationScope(
      guardActive: _editingTab != _EditingTab.none && _isProfileEditDirty,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      onLeaveConfirmed: (_) {
        if (!mounted) return;
        setState(() {
          _editingTab = _EditingTab.none;
          _overviewEditBaseline = null;
          _trainingEditBaseline = null;
        });
      },
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.profile),
            actions: [const AppBarMenu()],
            bottom: isEditing
                ? null
                : TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: l10n.profileOverviewTab),
                      Tab(text: l10n.profileTrainingPreferencesTab),
                      Tab(text: l10n.profileEquipmentTab),
                      Tab(text: l10n.profileDataTab),
                    ],
                  ),
          ),
          body: profileAsync.hasError
              ? Center(child: Text(l10n.genericError))
              : isEditing
              ? _editingTab == _EditingTab.overview
                    ? _buildOverviewEditView(resolved, l10n)
                    : _buildTrainingEditView(resolved, l10n)
              : TabBarView(
                  children: [
                    Skeletonizer(
                      enabled: profileAsync.isLoading,
                      child: _buildOverviewCategory(resolved, l10n),
                    ),
                    Skeletonizer(
                      enabled: profileAsync.isLoading,
                      child: _buildTrainingPreferencesCategory(resolved, l10n),
                    ),
                    const OwnedEquipmentList(),
                    Skeletonizer(
                      enabled: profileAsync.isLoading,
                      child: _buildDataCategory(l10n),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOverviewCategory(UserProfile profile, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AthlosInitialsAvatar(displayName: profile.name),
          ),
          const Gap(AthlosSpacing.lg),

          // Dados pessoais
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

          // Saúde e histórico
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
          const Gap(AthlosSpacing.md),
          const _BodyMetricsSection(),
          const Gap(AthlosSpacing.lg),

          FilledButton.icon(
            onPressed: () => _startEditingOverview(profile),
            icon: const Icon(Icons.edit),
            label: Text(l10n.edit),
          ),
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
            onPressed: () => _startEditingTraining(profile),
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
        authAsync.isLoading || conflictCenterAsync.isLoading || syncIssuesAsync.isLoading;

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

  Widget _buildEditBottomBar(UserProfile profile, AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelEditing,
                child: Text(l10n.cancel),
              ),
            ),
            const Gap(AthlosSpacing.smd),
            Expanded(
              child: FilledButton(
                onPressed: () => _saveChanges(profile),
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewEditView(UserProfile profile, AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(title: l10n.profileSectionPersonal),
                  const Gap(AthlosSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: l10n.nameLabel),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  const Gap(AthlosSpacing.md),
                  TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: l10n.heightLabel,
                      suffixText: l10n.heightUnit,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          _tryParseDecimal(value) == null) {
                        return l10n.invalidNumber;
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const Gap(AthlosSpacing.md),
                  TextFormField(
                    controller: _ageController,
                    decoration: InputDecoration(
                      labelText: l10n.ageLabel,
                      suffixText: l10n.yearsUnit,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          int.tryParse(value) == null) {
                        return l10n.invalidNumber;
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const Gap(AthlosSpacing.md),
                  Text(l10n.profileGender, style: textTheme.titleMedium),
                  Wrap(
                    spacing: AthlosSpacing.sm,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.genderMale),
                        selected: _selectedGender == Gender.male,
                        onSelected: (_) =>
                            setState(() => _selectedGender = Gender.male),
                      ),
                      ChoiceChip(
                        label: Text(l10n.genderFemale),
                        selected: _selectedGender == Gender.female,
                        onSelected: (_) =>
                            setState(() => _selectedGender = Gender.female),
                      ),
                      ChoiceChip(
                        label: Text(l10n.setupChatPreferNotToSay),
                        selected: _selectedGender == null,
                        onSelected: (_) =>
                            setState(() => _selectedGender = null),
                      ),
                    ],
                  ),
                  const Gap(AthlosSpacing.lg),
                  _SectionHeader(title: l10n.profileSectionHealth),
                  const Gap(AthlosSpacing.sm),
                  TextFormField(
                    controller: _injuriesController,
                    decoration: InputDecoration(
                      labelText: l10n.injuriesLabel,
                      hintText: l10n.injuriesHint,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                  const Gap(AthlosSpacing.md),
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: l10n.bioLabel,
                      hintText: l10n.bioHint,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildEditBottomBar(profile, l10n),
      ],
    );
  }

  Widget _buildTrainingEditView(UserProfile profile, AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(title: l10n.profileSectionTraining),
                  const Gap(AthlosSpacing.sm),
                  GoalSelector(
                    selected: _selectedGoal,
                    onSelected: (goal) => setState(() => _selectedGoal = goal),
                  ),
                  const Gap(AthlosSpacing.md),
                  AestheticSelector(
                    selected: _selectedAesthetic,
                    onSelected: (aesthetic) =>
                        setState(() => _selectedAesthetic = aesthetic),
                  ),
                  const Gap(AthlosSpacing.md),
                  StyleSelector(
                    selected: _selectedStyle,
                    onSelected: (style) =>
                        setState(() => _selectedStyle = style),
                  ),
                  const Gap(AthlosSpacing.md),
                  ExperienceSelector(
                    selected: _selectedExperience,
                    onSelected: (level) =>
                        setState(() => _selectedExperience = level),
                  ),
                  const Gap(AthlosSpacing.lg),
                  Text(
                    l10n.trainingFrequencyLabel,
                    style: textTheme.titleMedium,
                  ),
                  Slider(
                    value: (_trainingFrequency ?? 3).toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '${_trainingFrequency ?? 3}x',
                    onChanged: (v) =>
                        setState(() => _trainingFrequency = v.round()),
                  ),
                  Center(
                    child: Text(
                      '${_trainingFrequency ?? 3} ${l10n.daysPerWeek}',
                    ),
                  ),
                  const Gap(AthlosSpacing.md),
                  SwitchListTile(
                    title: Text(l10n.profileAvailableWorkoutMinutesLabel),
                    subtitle: Text(
                      l10n.profileAvailableWorkoutMinutesHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _availableWorkoutMinutes != null,
                    onChanged: (v) {
                      setState(() => _availableWorkoutMinutes = v ? 60 : null);
                      if (v) _workoutMinutesController.text = '60';
                    },
                  ),
                  if (_availableWorkoutMinutes != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: (_availableWorkoutMinutes!.toDouble()).clamp(
                              15,
                              120,
                            ),
                            min: 15,
                            max: 120,
                            divisions: 21,
                            label: '$_availableWorkoutMinutes min',
                            onChanged: (v) {
                              final rounded = v.round();
                              setState(
                                () => _availableWorkoutMinutes = rounded,
                              );
                              _workoutMinutesController.text = rounded
                                  .toString();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            controller: _workoutMinutesController,
                            decoration: const InputDecoration(
                              suffixText: 'min',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AthlosSpacing.sm,
                                vertical: AthlosSpacing.xs,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setState(
                                  () => _availableWorkoutMinutes = parsed,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Gap(AthlosSpacing.md),
                  SwitchListTile(
                    title: Text(l10n.trainsAtGymLabel),
                    value: _trainsAtGym ?? false,
                    onChanged: (v) => setState(() => _trainsAtGym = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildEditBottomBar(profile, l10n),
      ],
    );
  }

  Future<void> _saveChanges(UserProfile profile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final UserProfile updated;

    if (_editingTab == _EditingTab.overview) {
      final name = _nameController.text.trim();
      final heightText = _heightController.text.trim();
      final ageText = _ageController.text.trim();
      final injuries = _injuriesController.text.trim();
      final bio = _bioController.text.trim();
      updated = profile.copyWith(
        name: () => name.isEmpty ? null : name,
        height: () => heightText.isEmpty ? null : _tryParseDecimal(heightText),
        age: () => ageText.isEmpty ? null : int.tryParse(ageText),
        gender: () => _selectedGender,
        injuries: () => injuries.isEmpty ? null : injuries,
        bio: () => bio.isEmpty ? null : bio,
      );
    } else {
      updated = profile.copyWith(
        goal: () => _selectedGoal,
        bodyAesthetic: () => _selectedAesthetic,
        trainingStyle: () => _selectedStyle,
        experienceLevel: () => _selectedExperience,
        trainingFrequency: () => _trainingFrequency,
        availableWorkoutMinutes: () => _availableWorkoutMinutes,
        trainsAtGym: () => _trainsAtGym,
      );
    }

    try {
      await ref.read(profileProvider.notifier).updateProfile(updated);
      if (mounted) {
        setState(() {
          _editingTab = _EditingTab.none;
          _overviewEditBaseline = null;
          _trainingEditBaseline = null;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
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
    return intl.DateFormat('dd/MM/yyyy HH:mm', locale).format(instant.toLocal());
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
                        lastAttempt.difference(lastSuccess).inSeconds.abs() > 2) ...[
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
