import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../providers/profile_notifier.dart';

/// Chat-style profile setup screen shown on first launch.
///
/// Presents an interactive conversation with Chiron (the AI assistant)
/// that guides the user through profile configuration step by step.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

enum _StepType {
  name,
  body,
  gender,
  goal,
  aesthetic,
  style,
  experience,
  frequency,
  gym,
  injuries,
  bio,
  done,
}

class _ChatEntry {
  final String text;
  final bool isUser;
  final _StepType? inputStep;

  const _ChatEntry({
    required this.text,
    required this.isUser,
    this.inputStep,
  });
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _entries = <_ChatEntry>[];

  bool _isSaving = false;
  bool _waitingInput = false;

  // Collected data
  String? _name;
  double? _weight;
  double? _height;
  int? _age;
  Gender? _gender;
  TrainingGoal? _selectedGoal;
  BodyAesthetic? _selectedAesthetic;
  TrainingStyle? _selectedStyle;
  ExperienceLevel? _selectedExperience;
  int _trainingFrequency = 3;
  bool? _trainsAtGym;
  String? _injuries;
  String? _bio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startConversation());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startConversation() {
    final l10n = AppLocalizations.of(context)!;
    _addChironMessage(l10n.setupChatGreeting);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskName, inputStep: _StepType.name);
    });
  }

  void _addChironMessage(String text, {_StepType? inputStep}) {
    setState(() {
      _entries.add(_ChatEntry(text: text, isUser: false, inputStep: inputStep));
      if (inputStep != null) _waitingInput = true;
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _entries.add(_ChatEntry(text: text, isUser: true));
      _waitingInput = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // List is reversed: position 0 = newest messages (bottom of chat)
        _scrollController.animateTo(
          0,
          duration: AthlosDurations.normal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Current step for which we are waiting input; null when not waiting.
  _StepType? get _currentInputStep {
    if (!_waitingInput || _entries.isEmpty) return null;
    return _entries.last.inputStep;
  }

  void _onNameSubmitted(String value) {
    final l10n = AppLocalizations.of(context)!;
    final name = value.trim();
    _name = name.isEmpty ? null : name;
    _addUserMessage(name.isEmpty ? l10n.setupChatSkipped : name);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final greeting = _name != null
          ? l10n.setupChatGreetName(_name!)
          : l10n.setupChatGreetNoName;
      _addChironMessage(greeting);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _addChironMessage(l10n.setupChatAskBody, inputStep: _StepType.body);
      });
    });
  }

  void _onBodySubmitted() {
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[];
    if (_weight != null) parts.add('${_weight}kg');
    if (_height != null) parts.add('${_height}cm');
    if (_age != null) parts.add('$_age ${l10n.yearsUnit}');
    _addUserMessage(parts.isEmpty ? l10n.setupChatSkipped : parts.join(', '));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGender, inputStep: _StepType.gender);
    });
  }

  void _onGenderSelected(Gender? value) {
    final l10n = AppLocalizations.of(context)!;
    _gender = value;
    _addUserMessage(value == null
        ? l10n.setupChatPreferNotToSay
        : value == Gender.male
            ? l10n.genderMale
            : l10n.genderFemale);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGoal, inputStep: _StepType.goal);
    });
  }

  void _onGoalSelected(TrainingGoal goal) {
    final l10n = AppLocalizations.of(context)!;
    _selectedGoal = goal;
    _addUserMessage(_goalLabel(goal, l10n));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(
        l10n.setupChatAskAesthetic,
        inputStep: _StepType.aesthetic,
      );
    });
  }

  void _onAestheticSelected(BodyAesthetic aesthetic) {
    final l10n = AppLocalizations.of(context)!;
    _selectedAesthetic = aesthetic;
    _addUserMessage(_aestheticLabel(aesthetic, l10n));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(
        l10n.setupChatAskStyle,
        inputStep: _StepType.style,
      );
    });
  }

  void _onStyleSelected(TrainingStyle style) {
    final l10n = AppLocalizations.of(context)!;
    _selectedStyle = style;
    _addUserMessage(_styleLabel(style, l10n));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(
        l10n.setupChatAskExperience,
        inputStep: _StepType.experience,
      );
    });
  }

  void _onExperienceSelected(ExperienceLevel level) {
    final l10n = AppLocalizations.of(context)!;
    _selectedExperience = level;
    _addUserMessage(_experienceLabel(level, l10n));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(
        l10n.setupChatAskFrequency,
        inputStep: _StepType.frequency,
      );
    });
  }

  void _onFrequencyConfirmed() {
    final l10n = AppLocalizations.of(context)!;
    _addUserMessage('${_trainingFrequency}x ${l10n.perWeek}');

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGym, inputStep: _StepType.gym);
    });
  }

  void _onGymSelected(bool value) {
    final l10n = AppLocalizations.of(context)!;
    _trainsAtGym = value;
    _addUserMessage(value ? l10n.yes : l10n.no);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(
        l10n.setupChatAskInjuries,
        inputStep: _StepType.injuries,
      );
    });
  }

  void _onInjuriesSubmitted(String value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value.trim();
    _injuries = text.isEmpty ? null : text;
    _addUserMessage(text.isEmpty ? l10n.setupChatNone : text);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskBio, inputStep: _StepType.bio);
    });
  }

  void _onBioSubmitted(String value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value.trim();
    _bio = text.isEmpty ? null : text;
    _addUserMessage(text.isEmpty ? l10n.setupChatSkipped : text);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatReady, inputStep: _StepType.done);
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      await ref.read(profileProvider.notifier).create(
            name: _name,
            weight: _weight,
            height: _height,
            age: _age,
            gender: _gender,
            goal: _selectedGoal,
            bodyAesthetic: _selectedAesthetic,
            trainingStyle: _selectedStyle,
            experienceLevel: _selectedExperience,
            trainingFrequency: _trainingFrequency,
            trainsAtGym: _trainsAtGym,
            injuries: _injuries,
            bio: _bio,
          );

      ref.read(hasProfileProvider.notifier).markAsCreated();

      if (mounted) context.go(RoutePaths.hub);
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSkip() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).create(
            name: _name,
            weight: _weight,
            height: _height,
            age: _age,
            gender: _gender,
            goal: _selectedGoal,
            bodyAesthetic: _selectedAesthetic,
            trainingStyle: _selectedStyle,
            experienceLevel: _selectedExperience,
            trainingFrequency: _trainingFrequency,
            trainsAtGym: _trainsAtGym,
            injuries: _injuries,
            bio: _bio,
          );
      ref.read(hasProfileProvider.notifier).markAsCreated();
      if (mounted) context.go(RoutePaths.hub);
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.genericError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSetupTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _onSkip,
            child: Text(l10n.skip),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(
                  AthlosSpacing.md,
                  AthlosSpacing.sm + 120,
                  AthlosSpacing.md,
                  AthlosSpacing.sm,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[_entries.length - 1 - index];
                  return _ChatBubbleItem(
                    key: ValueKey(_entries.length - 1 - index),
                    entry: entry,
                  );
                },
              ),
            ),
            _SetupInputBar(
              step: _currentInputStep,
              state: this,
            ),
          ],
        ),
      ),
    );
  }

  // --- Label helpers ---

  String _goalLabel(TrainingGoal goal, AppLocalizations l10n) => switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophy,
        TrainingGoal.weightLoss => l10n.goalWeightLoss,
        TrainingGoal.endurance => l10n.goalEndurance,
        TrainingGoal.strength => l10n.goalStrength,
        TrainingGoal.generalFitness => l10n.goalGeneralFitness,
      };

  String _aestheticLabel(BodyAesthetic a, AppLocalizations l10n) =>
      switch (a) {
        BodyAesthetic.athletic => l10n.aestheticAthletic,
        BodyAesthetic.bulky => l10n.aestheticBulky,
        BodyAesthetic.robust => l10n.aestheticRobust,
      };

  String _styleLabel(TrainingStyle s, AppLocalizations l10n) => switch (s) {
        TrainingStyle.traditional => l10n.styleTraditional,
        TrainingStyle.calisthenics => l10n.styleCalisthenics,
        TrainingStyle.functional => l10n.styleFunctional,
        TrainingStyle.hybrid => l10n.styleHybrid,
      };

  String _experienceLabel(ExperienceLevel e, AppLocalizations l10n) =>
      switch (e) {
        ExperienceLevel.beginner => l10n.experienceBeginner,
        ExperienceLevel.intermediate => l10n.experienceIntermediate,
        ExperienceLevel.advanced => l10n.experienceAdvanced,
      };

  String _goalDescription(TrainingGoal goal, AppLocalizations l10n) =>
      switch (goal) {
        TrainingGoal.hypertrophy => l10n.goalHypertrophyDesc,
        TrainingGoal.weightLoss => l10n.goalWeightLossDesc,
        TrainingGoal.endurance => l10n.goalEnduranceDesc,
        TrainingGoal.strength => l10n.goalStrengthDesc,
        TrainingGoal.generalFitness => l10n.goalGeneralFitnessDesc,
      };

  String _aestheticDescription(BodyAesthetic a, AppLocalizations l10n) =>
      switch (a) {
        BodyAesthetic.athletic => l10n.aestheticAthleticDesc,
        BodyAesthetic.bulky => l10n.aestheticBulkyDesc,
        BodyAesthetic.robust => l10n.aestheticRobustDesc,
      };

  String _styleDescription(TrainingStyle s, AppLocalizations l10n) =>
      switch (s) {
        TrainingStyle.traditional => l10n.styleTraditionalDesc,
        TrainingStyle.calisthenics => l10n.styleCalisthenicsDesc,
        TrainingStyle.functional => l10n.styleFunctionalDesc,
        TrainingStyle.hybrid => l10n.styleHybridDesc,
      };

  String _experienceDescription(ExperienceLevel e, AppLocalizations l10n) =>
      switch (e) {
        ExperienceLevel.beginner => l10n.experienceBeginnerDesc,
        ExperienceLevel.intermediate => l10n.experienceIntermediateDesc,
        ExperienceLevel.advanced => l10n.experienceAdvancedDesc,
      };
}

/// Renders a single chat bubble (WhatsApp/Telegram style).
class _ChatBubbleItem extends StatelessWidget {
  final _ChatEntry entry;

  const _ChatBubbleItem({
    super.key,
    required this.entry,
  });

  static const _bubbleRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      child: Row(
        mainAxisAlignment:
            entry.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!entry.isUser) _buildAvatar(context),
          if (!entry.isUser) const Gap(AthlosSpacing.xs),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AthlosSpacing.md,
                vertical: AthlosSpacing.smd,
              ),
              decoration: BoxDecoration(
                color: entry.isUser
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(_bubbleRadius),
                  topRight: const Radius.circular(_bubbleRadius),
                  bottomLeft: Radius.circular(entry.isUser ? _bubbleRadius : 4),
                  bottomRight:
                      Radius.circular(entry.isUser ? 4 : _bubbleRadius),
                ),
              ),
              child: Text(
                entry.text,
                style: textTheme.bodyMedium?.copyWith(
                  color: entry.isUser
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          if (entry.isUser) const Gap(AthlosSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.auto_awesome,
        size: 18,
        color: colorScheme.primary,
      ),
    );
  }
}

/// Fixed bottom bar with the current step input (WhatsApp/Telegram style).
class _SetupInputBar extends StatelessWidget {
  final _StepType? step;
  final _ProfileSetupScreenState state;

  const _SetupInputBar({
    required this.step,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    if (step == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.4;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AthlosSpacing.md,
            AthlosSpacing.sm,
            AthlosSpacing.md,
            AthlosSpacing.md + 8,
          ),
          child: _buildInput(context, step!),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, _StepType step) {
    return switch (step) {
      _StepType.name => _NameInput(state: state),
      _StepType.body => _BodyInput(state: state),
      _StepType.gender => _GenderInput(state: state),
      _StepType.goal => _GoalInput(state: state),
      _StepType.aesthetic => _AestheticInput(state: state),
      _StepType.style => _StyleInput(state: state),
      _StepType.experience => _ExperienceInput(state: state),
      _StepType.frequency => _FrequencyInput(state: state),
      _StepType.gym => _GymInput(state: state),
      _StepType.injuries => _TextInput(
          hint: AppLocalizations.of(context)!.injuriesHint,
          onSubmitted: state._onInjuriesSubmitted,
          allowSkip: true,
          skipLabel: AppLocalizations.of(context)!.setupChatNone,
        ),
      _StepType.bio => _TextInput(
          hint: AppLocalizations.of(context)!.bioHint,
          onSubmitted: state._onBioSubmitted,
          allowSkip: true,
          skipLabel: AppLocalizations.of(context)!.skip,
        ),
      _StepType.done => _DoneInput(state: state),
    };
  }
}

// --- Input widgets ---

class _NameInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _NameInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: state._textController,
            decoration: InputDecoration(
              hintText: l10n.nameHint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AthlosSpacing.smd,
                vertical: AthlosSpacing.smd,
              ),
              border: OutlineInputBorder(
                borderRadius: AthlosRadius.mdAll,
              ),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) {
              state._onNameSubmitted(v);
              state._textController.clear();
            },
          ),
        ),
        const Gap(AthlosSpacing.sm),
        IconButton.filled(
          onPressed: () {
            state._onNameSubmitted(state._textController.text);
            state._textController.clear();
          },
          icon: const Icon(Icons.send, size: 20),
        ),
      ],
    );
  }
}

class _BodyInput extends StatefulWidget {
  final _ProfileSetupScreenState state;
  const _BodyInput({required this.state});

  @override
  State<_BodyInput> createState() => _BodyInputState();
}

class _BodyInputState extends State<_BodyInput> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                decoration: InputDecoration(
                  hintText: l10n.weightLabel,
                  suffixText: l10n.weightUnit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.smd,
                    vertical: AthlosSpacing.smd,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AthlosRadius.mdAll,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
            ),
            const Gap(AthlosSpacing.sm),
            Expanded(
              child: TextField(
                controller: _heightCtrl,
                decoration: InputDecoration(
                  hintText: l10n.heightLabel,
                  suffixText: l10n.heightUnit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.smd,
                    vertical: AthlosSpacing.smd,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AthlosRadius.mdAll,
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
            ),
            const Gap(AthlosSpacing.sm),
            Expanded(
              child: TextField(
                controller: _ageCtrl,
                decoration: InputDecoration(
                  hintText: l10n.ageLabel,
                  suffixText: l10n.yearsUnit,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.smd,
                    vertical: AthlosSpacing.smd,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AthlosRadius.mdAll,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              widget.state._weight = double.tryParse(_weightCtrl.text);
              widget.state._height = double.tryParse(_heightCtrl.text);
              widget.state._age = int.tryParse(_ageCtrl.text);
              widget.state._onBodySubmitted();
            },
            child: Text(l10n.next),
          ),
        ),
      ],
    );
  }
}

class _GenderInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _GenderInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AthlosSpacing.sm,
      runSpacing: AthlosSpacing.sm,
      children: [
        ChoiceChip(
          label: Text(l10n.genderMale),
          selected: false,
          onSelected: (_) => state._onGenderSelected(Gender.male),
        ),
        ChoiceChip(
          label: Text(l10n.genderFemale),
          selected: false,
          onSelected: (_) => state._onGenderSelected(Gender.female),
        ),
        ChoiceChip(
          label: Text(l10n.setupChatPreferNotToSay),
          selected: false,
          onSelected: (_) => state._onGenderSelected(null),
        ),
      ],
    );
  }
}

class _GoalInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _GoalInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.setupChatChipHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Wrap(
          spacing: AthlosSpacing.sm,
          runSpacing: AthlosSpacing.sm,
          children: TrainingGoal.values.map((goal) {
            return Tooltip(
              message: state._goalDescription(goal, l10n),
              child: ChoiceChip(
                label: Text(state._goalLabel(goal, l10n)),
                selected: false,
                onSelected: (_) => state._onGoalSelected(goal),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AestheticInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _AestheticInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.setupChatChipHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Wrap(
          spacing: AthlosSpacing.sm,
          runSpacing: AthlosSpacing.sm,
          children: BodyAesthetic.values.map((a) {
            return Tooltip(
              message: state._aestheticDescription(a, l10n),
              child: ChoiceChip(
                label: Text(state._aestheticLabel(a, l10n)),
                selected: false,
                onSelected: (_) => state._onAestheticSelected(a),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StyleInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _StyleInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.setupChatChipHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Wrap(
          spacing: AthlosSpacing.sm,
          runSpacing: AthlosSpacing.sm,
          children: TrainingStyle.values.map((s) {
            return Tooltip(
              message: state._styleDescription(s, l10n),
              child: ChoiceChip(
                label: Text(state._styleLabel(s, l10n)),
                selected: false,
                onSelected: (_) => state._onStyleSelected(s),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ExperienceInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _ExperienceInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.setupChatChipHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Wrap(
          spacing: AthlosSpacing.sm,
          runSpacing: AthlosSpacing.sm,
          children: ExperienceLevel.values.map((e) {
            return Tooltip(
              message: state._experienceDescription(e, l10n),
              child: ChoiceChip(
                label: Text(state._experienceLabel(e, l10n)),
                selected: false,
                onSelected: (_) => state._onExperienceSelected(e),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FrequencyInput extends StatefulWidget {
  final _ProfileSetupScreenState state;
  const _FrequencyInput({required this.state});

  @override
  State<_FrequencyInput> createState() => _FrequencyInputState();
}

class _FrequencyInputState extends State<_FrequencyInput> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.state._trainingFrequency;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Slider(
          value: _value.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          label: '${_value}x',
          onChanged: (v) => setState(() => _value = v.round()),
        ),
        Text(
          '$_value ${l10n.daysPerWeek}',
          style: textTheme.titleSmall,
        ),
        const Gap(AthlosSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              widget.state._trainingFrequency = _value;
              widget.state._onFrequencyConfirmed();
            },
            child: Text(l10n.next),
          ),
        ),
      ],
    );
  }
}

class _GymInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _GymInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: () => state._onGymSelected(true),
            child: Text(l10n.yes),
          ),
        ),
        const Gap(AthlosSpacing.sm),
        Expanded(
          child: OutlinedButton(
            onPressed: () => state._onGymSelected(false),
            child: Text(l10n.no),
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatefulWidget {
  final String hint;
  final void Function(String) onSubmitted;
  final bool allowSkip;
  final String? skipLabel;

  const _TextInput({
    required this.hint,
    required this.onSubmitted,
    this.allowSkip = false,
    this.skipLabel,
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: widget.hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AthlosSpacing.smd,
              vertical: AthlosSpacing.smd,
            ),
            border: OutlineInputBorder(borderRadius: AthlosRadius.mdAll),
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: widget.onSubmitted,
        ),
        const Gap(AthlosSpacing.sm),
        Row(
          children: [
            if (widget.allowSkip)
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onSubmitted(''),
                  child: Text(widget.skipLabel ?? 'Pular'),
                ),
              ),
            if (widget.allowSkip) const Gap(AthlosSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => widget.onSubmitted(_ctrl.text),
                child: const Icon(Icons.send, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _DoneInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: state._isSaving ? null : state._saveProfile,
        icon: state._isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward),
        label: Text(l10n.setupChatStart),
      ),
    );
  }
}
