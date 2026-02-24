import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../providers/profile_notifier.dart';
import '../widgets/aesthetic_selector.dart';
import '../widgets/goal_selector.dart';
import '../widgets/style_selector.dart';

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
  bool _isEditing = false;

  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  TrainingGoal? _selectedGoal;
  BodyAesthetic? _selectedAesthetic;
  TrainingStyle? _selectedStyle;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _startEditing(UserProfile profile) {
    _weightController.text = profile.weight?.toString() ?? '';
    _heightController.text = profile.height?.toString() ?? '';
    _ageController.text = profile.age?.toString() ?? '';
    _selectedGoal = profile.goal;
    _selectedAesthetic = profile.bodyAesthetic;
    _selectedStyle = profile.trainingStyle;
    setState(() => _isEditing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (profile) {
          final resolved = profile ?? const UserProfile(id: 0);
          return _isEditing
              ? _buildEditView(resolved, l10n)
              : _buildReadView(resolved, l10n);
        },
      ),
    );
  }

  Widget _buildReadView(UserProfile profile, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Column(
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 48,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 48,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const Gap(AthlosSpacing.lg),

          // Data cards
          _ProfileTile(
            icon: Icons.monitor_weight_outlined,
            label: l10n.profileWeight,
            value: profile.weight != null
                ? '${profile.weight} ${l10n.weightUnit}'
                : l10n.profileNotSet,
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
          const Gap(AthlosSpacing.lg),

          // Edit button
          FilledButton.icon(
            onPressed: () => _startEditing(profile),
            icon: const Icon(Icons.edit),
            label: Text(l10n.edit),
          ),
        ],
      ),
    );
  }

  Widget _buildEditView(UserProfile profile, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AthlosSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _weightController,
              decoration: InputDecoration(
                labelText: l10n.weightLabel,
                suffixText: l10n.weightUnit,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.fieldRequired;
                if (double.tryParse(value) == null) return l10n.invalidNumber;
                return null;
              },
            ),
            const Gap(AthlosSpacing.md),
            TextFormField(
              controller: _heightController,
              decoration: InputDecoration(
                labelText: l10n.heightLabel,
                suffixText: l10n.heightUnit,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.fieldRequired;
                if (double.tryParse(value) == null) return l10n.invalidNumber;
                return null;
              },
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
                if (value == null || value.isEmpty) return l10n.fieldRequired;
                if (int.tryParse(value) == null) return l10n.invalidNumber;
                return null;
              },
            ),
            const Gap(AthlosSpacing.lg),
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
            const Gap(AthlosSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isEditing = false),
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
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges(UserProfile profile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final updated = UserProfile(
      id: profile.id,
      weight: double.parse(_weightController.text),
      height: double.parse(_heightController.text),
      age: int.parse(_ageController.text),
      goal: _selectedGoal,
      bodyAesthetic: _selectedAesthetic,
      trainingStyle: _selectedStyle,
      lastActiveModule: profile.lastActiveModule,
    );

    try {
      await ref.read(profileProvider.notifier).updateProfile(updated);
      if (mounted) {
        setState(() => _isEditing = false);
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    }
  }

  String _goalLabel(TrainingGoal goal, AppLocalizations l10n) => switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophy,
        TrainingGoal.weightLoss => l10n.goalWeightLoss,
        TrainingGoal.endurance => l10n.goalEndurance,
        TrainingGoal.strength => l10n.goalStrength,
        TrainingGoal.generalFitness => l10n.goalGeneralFitness,
      };

  String _aestheticLabel(BodyAesthetic aesthetic, AppLocalizations l10n) =>
      switch (aesthetic) {
        BodyAesthetic.athletic => l10n.aestheticAthletic,
        BodyAesthetic.bulky => l10n.aestheticBulky,
        BodyAesthetic.robust => l10n.aestheticRobust,
      };

  String _styleLabel(TrainingStyle style, AppLocalizations l10n) =>
      switch (style) {
        TrainingStyle.traditional => l10n.styleTraditional,
        TrainingStyle.calisthenics => l10n.styleCalisthenics,
        TrainingStyle.functional => l10n.styleFunctional,
        TrainingStyle.hybrid => l10n.styleHybrid,
      };
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                Text(
                  value,
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
