import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../providers/profile_notifier.dart';
import '../widgets/aesthetic_selector.dart';
import '../widgets/experience_selector.dart';
import '../widgets/goal_selector.dart';
import '../widgets/profile_section_header.dart';
import '../widgets/style_selector.dart';

/// Full-screen editor for training goals and preferences.
class ProfileTrainingEditScreen extends ConsumerStatefulWidget {
  const ProfileTrainingEditScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProfileTrainingEditScreen(),
      ),
    );
  }

  @override
  ConsumerState<ProfileTrainingEditScreen> createState() =>
      _ProfileTrainingEditScreenState();
}

class _ProfileTrainingEditScreenState
    extends ConsumerState<ProfileTrainingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _workoutMinutesController = TextEditingController();
  TrainingGoal? _selectedGoal;
  BodyAesthetic? _selectedAesthetic;
  TrainingStyle? _selectedStyle;
  ExperienceLevel? _selectedExperience;
  int? _trainingFrequency;
  int? _availableWorkoutMinutes;
  bool? _trainsAtGym;
  String? _editBaseline;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _workoutMinutesController.dispose();
    super.dispose();
  }

  void _loadFromProfile(UserProfile profile) {
    _selectedGoal = profile.goal;
    _selectedAesthetic = profile.bodyAesthetic;
    _selectedStyle = profile.trainingStyle;
    _selectedExperience = profile.experienceLevel;
    _trainingFrequency = profile.trainingFrequency;
    _availableWorkoutMinutes = profile.availableWorkoutMinutes;
    _workoutMinutesController.text =
        profile.availableWorkoutMinutes?.toString() ?? '60';
    _trainsAtGym = profile.trainsAtGym;
    _editBaseline = _snapshotEdit();
  }

  String _snapshotEdit() => [
    _selectedGoal?.name ?? 'null',
    _selectedAesthetic?.name ?? 'null',
    _selectedStyle?.name ?? 'null',
    _selectedExperience?.name ?? 'null',
    '${_trainingFrequency ?? -1}',
    '${_availableWorkoutMinutes ?? -1}',
    _workoutMinutesController.text,
    '${_trainsAtGym ?? -1}',
  ].join('\u001e');

  bool get _isDirty =>
      _editBaseline != null && _snapshotEdit() != _editBaseline;

  Future<void> _cancel() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDiscardUnsavedEdits(context);
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  Future<void> _save(UserProfile profile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = profile.copyWith(
      goal: () => _selectedGoal,
      bodyAesthetic: () => _selectedAesthetic,
      trainingStyle: () => _selectedStyle,
      experienceLevel: () => _selectedExperience,
      trainingFrequency: () => _trainingFrequency,
      availableWorkoutMinutes: () => _availableWorkoutMinutes,
      trainsAtGym: () => _trainsAtGym,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;

    if (profile != null && !_initialized) {
      _loadFromProfile(profile);
      _initialized = true;
    }

    return ConfirmNavigationScope(
      guardActive: _isDirty && !_isSaving,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileSectionTraining),
          leading: BackButton(onPressed: _cancel),
        ),
        body: profile == null
            ? Center(
                child: profileAsync.hasError
                    ? Text(l10n.genericError)
                    : const CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AthlosSpacing.md),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProfileSectionHeader(
                              title: l10n.profileSectionTraining,
                            ),
                            const Gap(AthlosSpacing.sm),
                            GoalSelector(
                              selected: _selectedGoal,
                              onSelected: (goal) =>
                                  setState(() => _selectedGoal = goal),
                            ),
                            const Gap(AthlosSpacing.md),
                            AestheticSelector(
                              selected: _selectedAesthetic,
                              onSelected: (aesthetic) => setState(
                                () => _selectedAesthetic = aesthetic,
                              ),
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
                              onSelected: (level) => setState(
                                () => _selectedExperience = level,
                              ),
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
                              onChanged: (v) => setState(
                                () => _trainingFrequency = v.round(),
                              ),
                            ),
                            Center(
                              child: Text(
                                '${_trainingFrequency ?? 3} ${l10n.daysPerWeek}',
                              ),
                            ),
                            const Gap(AthlosSpacing.md),
                            SwitchListTile(
                              title: Text(
                                l10n.profileAvailableWorkoutMinutesLabel,
                              ),
                              subtitle: Text(
                                l10n.profileAvailableWorkoutMinutesHint,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              value: _availableWorkoutMinutes != null,
                              onChanged: (v) {
                                setState(() {
                                  _availableWorkoutMinutes = v ? 60 : null;
                                });
                                if (v) _workoutMinutesController.text = '60';
                              },
                            ),
                            if (_availableWorkoutMinutes != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: (_availableWorkoutMinutes!
                                              .toDouble())
                                          .clamp(15, 120),
                                      min: 15,
                                      max: 120,
                                      divisions: 21,
                                      label: '$_availableWorkoutMinutes min',
                                      onChanged: (v) {
                                        final rounded = v.round();
                                        setState(
                                          () => _availableWorkoutMinutes =
                                              rounded,
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
                                            () => _availableWorkoutMinutes =
                                                parsed,
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
                              onChanged: (v) =>
                                  setState(() => _trainsAtGym = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AthlosSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _cancel,
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const Gap(AthlosSpacing.smd),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving ? null : () => _save(profile),
                              child: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
