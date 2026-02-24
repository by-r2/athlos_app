import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../providers/profile_notifier.dart';
import '../widgets/aesthetic_selector.dart';
import '../widgets/goal_selector.dart';
import '../widgets/style_selector.dart';

/// Profile setup screen shown on first launch.
///
/// Uses a PageView with a custom step indicator instead of Stepper
/// to avoid overflow issues and give a cleaner look.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _totalSteps = 4;
  int _currentStep = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();

  TrainingGoal? _selectedGoal;
  BodyAesthetic? _selectedAesthetic;
  TrainingStyle? _selectedStyle;
  bool _isSaving = false;
  bool _showHelp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSetupTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: Text(l10n.skip),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
              child: Text(
                l10n.profileSetupSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Gap(AthlosSpacing.md),

            // Step indicator
            _StepIndicator(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              labels: [
                l10n.stepPersonalData,
                l10n.stepGoal,
                l10n.stepAesthetic,
                l10n.stepStyle,
              ],
            ),
            const Gap(AthlosSpacing.lg),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (_currentStep) {
                    0 => _buildPersonalDataStep(l10n),
                    1 => _buildGoalStep(),
                    2 => _buildAestheticStep(),
                    3 => _buildStyleStep(),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(AthlosSpacing.md, AthlosSpacing.smd, AthlosSpacing.md, AthlosSpacing.md),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _onBack,
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox.shrink(),
                  // Help toggle — only on selection steps
                  if (_currentStep > 0)
                    IconButton(
                      onPressed: () =>
                          setState(() => _showHelp = !_showHelp),
                      tooltip: l10n.helpModeTooltip,
                      icon: Icon(
                        _showHelp
                            ? Icons.help
                            : Icons.help_outline,
                        color: _showHelp
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isSaving ? null : _onNext,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _currentStep == _totalSteps - 1
                                ? l10n.finish
                                : l10n.next,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalDataStep(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(0),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              hintText: l10n.nameHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const Gap(AthlosSpacing.md),
          TextFormField(
            controller: _weightController,
            decoration: InputDecoration(
              labelText: l10n.weightLabel,
              hintText: l10n.weightHint,
              suffixText: l10n.weightUnit,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                return l10n.invalidNumber;
              }
              return null;
            },
          ),
          const Gap(AthlosSpacing.md),
          TextFormField(
            controller: _heightController,
            decoration: InputDecoration(
              labelText: l10n.heightLabel,
              hintText: l10n.heightHint,
              suffixText: l10n.heightUnit,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            validator: (value) {
              if (value != null && value.isNotEmpty && double.tryParse(value) == null) {
                return l10n.invalidNumber;
              }
              return null;
            },
          ),
          const Gap(AthlosSpacing.md),
          TextFormField(
            controller: _ageController,
            decoration: InputDecoration(
              labelText: l10n.ageLabel,
              hintText: l10n.ageHint,
              suffixText: l10n.yearsUnit,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                return l10n.invalidNumber;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return GoalSelector(
      key: const ValueKey(1),
      selected: _selectedGoal,
      onSelected: (goal) => setState(() => _selectedGoal = goal),
      showHelp: _showHelp,
    );
  }

  Widget _buildAestheticStep() {
    return AestheticSelector(
      key: const ValueKey(2),
      selected: _selectedAesthetic,
      onSelected: (aesthetic) =>
          setState(() => _selectedAesthetic = aesthetic),
      showHelp: _showHelp,
    );
  }

  Widget _buildStyleStep() {
    return StyleSelector(
      key: const ValueKey(3),
      selected: _selectedStyle,
      onSelected: (style) => setState(() => _selectedStyle = style),
      showHelp: _showHelp,
    );
  }

  void _onNext() {
    final l10n = AppLocalizations.of(context)!;

    switch (_currentStep) {
      case 0:
        if (_formKey.currentState?.validate() ?? false) {
          setState(() => _currentStep = 1);
        }
      case 1:
        setState(() => _currentStep = 2);
      case 2:
        setState(() => _currentStep = 3);
      case 3:
        _saveProfile();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _onSkip() async {
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);
      final age = int.tryParse(_ageController.text);

      await ref.read(profileProvider.notifier).create(
            name: name.isEmpty ? null : name,
            weight: weight,
            height: height,
            age: age,
            goal: _selectedGoal,
            bodyAesthetic: _selectedAesthetic,
            trainingStyle: _selectedStyle,
          );

      ref.read(hasProfileProvider.notifier).markAsCreated();

      if (mounted) {
        context.go(RoutePaths.hub);
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final weight = double.tryParse(_weightController.text);
      final height = double.tryParse(_heightController.text);
      final age = int.tryParse(_ageController.text);
      await ref.read(profileProvider.notifier).create(
            name: name.isEmpty ? null : name,
            weight: weight,
            height: height,
            age: age,
            goal: _selectedGoal,
            bodyAesthetic: _selectedAesthetic,
            trainingStyle: _selectedStyle,
          );

      ref.read(hasProfileProvider.notifier).markAsCreated();

      if (mounted) {
        context.go(RoutePaths.hub);
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

/// Minimal segmented progress bar with current step label.
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AthlosSpacing.md),
      child: Column(
        children: [
          // Segmented bars
          Row(
            children: List.generate(totalSteps, (index) {
              final isReached = index <= currentStep;

              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < totalSteps - 1 ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isReached
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                  ),
                ),
              );
            }),
          ),
          const Gap(AthlosSpacing.smd),

          // Current step label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              labels[currentStep],
              key: ValueKey(currentStep),
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
