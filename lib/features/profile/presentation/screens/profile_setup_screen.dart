import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme/athlos_durations.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../../../training/data/repositories/training_providers.dart';
import '../../../training/domain/entities/training_program.dart';
import '../../../training/domain/enums/duration_mode.dart';
import '../../../training/domain/enums/program_focus.dart';
import '../../../training/presentation/providers/program_notifier.dart';
import '../helpers/profile_l10n.dart';
import '../providers/body_metric_notifier.dart';
import '../providers/profile_notifier.dart';

double? _tryParseDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Chat-style profile setup screen shown on first launch.
///
/// Presents an interactive conversation with Chiron (the AI assistant)
/// that guides the user through profile configuration step by step.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
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

  const _ChatEntry({required this.text, required this.isUser, this.inputStep});

  _ChatEntry copyWith({String? text, bool? isUser, _StepType? inputStep}) {
    return _ChatEntry(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      inputStep: inputStep ?? this.inputStep,
    );
  }
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _entries = <_ChatEntry>[];

  bool _isSaving = false;
  bool _waitingInput = false;
  int? _editingIndex;
  _StepType? _editingStep;

  /// Latest question step shown by Chiron (drives setup progress between messages).
  _StepType? _latestPromptStep;

  // Collected data
  String? _name;
  double? _weight;
  double? _bodyFatPercent;
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
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
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
      if (inputStep != null) {
        _waitingInput = true;
        _latestPromptStep = inputStep;
      }
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text, {_StepType? answeredStep}) {
    setState(() {
      _entries.add(
        _ChatEntry(text: text, isUser: true, inputStep: answeredStep),
      );
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

  _StepType? get _activeInputStep => _editingStep ?? _currentInputStep;

  /// 0 → none yet; 1 → full bar on final [done] step.
  double get _setupProgressFraction {
    final step = _editingStep ?? _latestPromptStep;
    if (step == null) return 0;
    return (step.index + 1) / _StepType.values.length;
  }

  bool _tryApplyEditedAnswer({
    required _StepType step,
    required String text,
    required VoidCallback applyValue,
  }) {
    final editingIndex = _editingIndex;
    if (editingIndex == null || _editingStep != step) return false;

    setState(() {
      applyValue();
      _entries[editingIndex] = _entries[editingIndex].copyWith(text: text);
      if (step == _StepType.name) {
        _updateNameGreetingAfterEdit(editingIndex);
      }
      _editingIndex = null;
      _editingStep = null;
    });
    _scrollToBottom();
    return true;
  }

  void _updateNameGreetingAfterEdit(int nameAnswerIndex) {
    final l10n = AppLocalizations.of(context)!;
    final greeting = _name != null
        ? l10n.setupChatGreetName(_name!)
        : l10n.setupChatGreetNoName;
    final greetingIndex = nameAnswerIndex + 1;
    if (greetingIndex >= _entries.length) return;
    final greetingEntry = _entries[greetingIndex];
    if (greetingEntry.isUser) return;
    _entries[greetingIndex] = greetingEntry.copyWith(text: greeting);
  }

  void _startEditing(int entryIndex) {
    if (_isSaving || entryIndex < 0 || entryIndex >= _entries.length) return;
    final entry = _entries[entryIndex];
    if (!entry.isUser || entry.inputStep == null) return;

    setState(() {
      _editingIndex = entryIndex;
      _editingStep = entry.inputStep;
      _waitingInput = true;
      if (_editingStep == _StepType.name) {
        _textController.text = _name ?? '';
      } else if (_editingStep == _StepType.body) {
        _weightCtrl.text = _weight != null ? _weight.toString() : '';
        _bodyFatCtrl.text = _bodyFatPercent != null
            ? (_bodyFatPercent! % 1 == 0
                ? _bodyFatPercent!.toInt().toString()
                : _bodyFatPercent!.toStringAsFixed(1))
            : '';
        _heightCtrl.text = _height != null ? _height.toString() : '';
        _ageCtrl.text = _age != null ? _age.toString() : '';
      }
    });
    _scrollToBottom();
  }

  void _onNameSubmitted(String value) {
    final l10n = AppLocalizations.of(context)!;
    final name = value.trim();
    final userText = name.isEmpty ? l10n.setupChatSkipped : name;
    if (_tryApplyEditedAnswer(
      step: _StepType.name,
      text: userText,
      applyValue: () => _name = name.isEmpty ? null : name,
    )) {
      return;
    }
    _name = name.isEmpty ? null : name;
    _addUserMessage(userText, answeredStep: _StepType.name);

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
    final w = _tryParseDecimal(_weightCtrl.text);
    final bf = _tryParseDecimal(_bodyFatCtrl.text);
    final h = _tryParseDecimal(_heightCtrl.text);
    final a = int.tryParse(_ageCtrl.text.trim());

    if (bf != null && w == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setupChatBodyFatNeedsWeight)),
      );
      return;
    }

    String bfBubble(double value) {
      final s =
          value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
      return l10n.bodyMetricsDashboardBodyFat(s);
    }

    final parts = <String>[];
    if (w != null) parts.add('${w}kg');
    if (bf != null) parts.add(bfBubble(bf));
    if (h != null) parts.add('${h}cm');
    if (a != null) parts.add('$a ${l10n.yearsUnit}');
    final userText = parts.isEmpty ? l10n.setupChatSkipped : parts.join(', ');
    if (_tryApplyEditedAnswer(
      step: _StepType.body,
      text: userText,
      applyValue: () {
        _weight = w;
        _bodyFatPercent = bf;
        _height = h;
        _age = a;
      },
    )) {
      return;
    }
    _weight = w;
    _bodyFatPercent = bf;
    _height = h;
    _age = a;
    _addUserMessage(userText, answeredStep: _StepType.body);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGender, inputStep: _StepType.gender);
    });
  }

  void _onGenderSelected(Gender? value) {
    final l10n = AppLocalizations.of(context)!;
    final userText = value == null
        ? l10n.setupChatPreferNotToSay
        : value == Gender.male
        ? l10n.genderMale
        : l10n.genderFemale;
    if (_tryApplyEditedAnswer(
      step: _StepType.gender,
      text: userText,
      applyValue: () => _gender = value,
    )) {
      return;
    }
    _gender = value;
    _addUserMessage(userText, answeredStep: _StepType.gender);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGoal, inputStep: _StepType.goal);
    });
  }

  void _onGoalSelected(TrainingGoal goal) {
    final l10n = AppLocalizations.of(context)!;
    final userText = _goalLabel(goal, l10n);
    if (_tryApplyEditedAnswer(
      step: _StepType.goal,
      text: userText,
      applyValue: () => _selectedGoal = goal,
    )) {
      return;
    }
    _selectedGoal = goal;
    _addUserMessage(userText, answeredStep: _StepType.goal);

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
    final userText = _aestheticLabel(aesthetic, l10n);
    if (_tryApplyEditedAnswer(
      step: _StepType.aesthetic,
      text: userText,
      applyValue: () => _selectedAesthetic = aesthetic,
    )) {
      return;
    }
    _selectedAesthetic = aesthetic;
    _addUserMessage(userText, answeredStep: _StepType.aesthetic);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskStyle, inputStep: _StepType.style);
    });
  }

  void _onStyleSelected(TrainingStyle style) {
    final l10n = AppLocalizations.of(context)!;
    final userText = _styleLabel(style, l10n);
    if (_tryApplyEditedAnswer(
      step: _StepType.style,
      text: userText,
      applyValue: () => _selectedStyle = style,
    )) {
      return;
    }
    _selectedStyle = style;
    _addUserMessage(userText, answeredStep: _StepType.style);

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
    final userText = _experienceLabel(level, l10n);
    if (_tryApplyEditedAnswer(
      step: _StepType.experience,
      text: userText,
      applyValue: () => _selectedExperience = level,
    )) {
      return;
    }
    _selectedExperience = level;
    _addUserMessage(userText, answeredStep: _StepType.experience);

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
    final userText = '${_trainingFrequency}x ${l10n.perWeek}';
    if (_tryApplyEditedAnswer(
      step: _StepType.frequency,
      text: userText,
      applyValue: () {},
    )) {
      return;
    }
    _addUserMessage(userText, answeredStep: _StepType.frequency);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskGym, inputStep: _StepType.gym);
    });
  }

  void _onGymSelected(bool value) {
    final l10n = AppLocalizations.of(context)!;
    final userText = value ? l10n.yes : l10n.no;
    if (_tryApplyEditedAnswer(
      step: _StepType.gym,
      text: userText,
      applyValue: () => _trainsAtGym = value,
    )) {
      return;
    }
    _trainsAtGym = value;
    _addUserMessage(userText, answeredStep: _StepType.gym);

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
    final userText = text.isEmpty ? l10n.setupChatNone : text;
    if (_tryApplyEditedAnswer(
      step: _StepType.injuries,
      text: userText,
      applyValue: () => _injuries = text.isEmpty ? null : text,
    )) {
      return;
    }
    _injuries = text.isEmpty ? null : text;
    _addUserMessage(userText, answeredStep: _StepType.injuries);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatAskBio, inputStep: _StepType.bio);
    });
  }

  void _onBioSubmitted(String value) {
    final l10n = AppLocalizations.of(context)!;
    final text = value.trim();
    final userText = text.isEmpty ? l10n.setupChatSkipped : text;
    if (_tryApplyEditedAnswer(
      step: _StepType.bio,
      text: userText,
      applyValue: () => _bio = text.isEmpty ? null : text,
    )) {
      return;
    }
    _bio = text.isEmpty ? null : text;
    _addUserMessage(userText, answeredStep: _StepType.bio);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _addChironMessage(l10n.setupChatReady, inputStep: _StepType.done);
    });
  }

  Future<void> _saveProfile() => _persist();

  /// Persist everything collected so far (nulls for steps not reached yet) and exit to hub.
  Future<void> _persist() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileProvider.notifier)
          .create(
            name: _name,
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

      if (_weight != null) {
        await ref.read(bodyMetricListProvider.notifier).add(
              weight: _weight!,
              bodyFatPercent: _bodyFatPercent,
            );
      }

      await _ensureDefaultProgram();

      ref.read(hasProfileProvider.notifier).markAsCreated();

      if (mounted) context.go(RoutePaths.hub);
    } catch (e, st) {
      debugPrint('[ProfileSetup] Save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _ensureDefaultProgram() async {
    final repo = ref.read(programRepositoryProvider);

    final activeResult = await repo.getActive();
    if (activeResult.getOrThrow() != null) return;

    final focus = switch (_selectedGoal) {
      TrainingGoal.hypertrophy => ProgramFocus.hypertrophy,
      TrainingGoal.strength => ProgramFocus.strength,
      TrainingGoal.endurance => ProgramFocus.endurance,
      TrainingGoal.weightLoss ||
      TrainingGoal.generalFitness ||
      null => ProgramFocus.hypertrophy,
    };

    final program = TrainingProgram(
      id: 0,
      name: 'Meu Programa',
      focus: focus,
      durationMode: DurationMode.sessions,
      durationValue: 12,
      defaultRestSeconds: focus.suggestedRestSeconds,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final id = (await repo.create(program)).getOrThrow();
    (await repo.activate(id)).getOrThrow();

    ref.invalidate(programListProvider);
    ref.invalidate(activeProgramProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSetupTitle),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: LinearProgressIndicator(
            value: _setupProgressFraction,
            minHeight: 2,
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            color: colorScheme.primary.withValues(alpha: 0.38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _persist,
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
                  final entryIndex = _entries.length - 1 - index;
                  final entry = _entries[entryIndex];
                  return _ChatBubbleItem(
                    key: ValueKey(entryIndex),
                    entry: entry,
                    isEditing: _editingIndex == entryIndex,
                    onTap:
                        entry.isUser &&
                            entry.inputStep != null &&
                            !_isSaving &&
                            (_editingIndex == null ||
                                _editingIndex == entryIndex)
                        ? () => _startEditing(entryIndex)
                        : null,
                  );
                },
              ),
            ),
            _SetupInputBar(step: _activeInputStep, state: this),
          ],
        ),
      ),
    );
  }

  // --- Label helpers ---

  String _goalLabel(TrainingGoal goal, AppLocalizations l10n) =>
      localizedTrainingGoalName(goal, l10n);

  String _aestheticLabel(BodyAesthetic a, AppLocalizations l10n) =>
      localizedBodyAestheticName(a, l10n);

  String _styleLabel(TrainingStyle s, AppLocalizations l10n) =>
      localizedTrainingStyleName(s, l10n);

  String _experienceLabel(ExperienceLevel e, AppLocalizations l10n) =>
      localizedExperienceLevelName(e, l10n);

  String _goalDescription(TrainingGoal goal, AppLocalizations l10n) =>
      localizedTrainingGoalDescription(goal, l10n);

  String _aestheticDescription(BodyAesthetic a, AppLocalizations l10n) =>
      localizedBodyAestheticDescription(a, l10n);

  String _styleDescription(TrainingStyle s, AppLocalizations l10n) =>
      localizedTrainingStyleDescription(s, l10n);

  String _experienceDescription(ExperienceLevel e, AppLocalizations l10n) =>
      localizedExperienceLevelDescription(e, l10n);
}

/// Renders a single chat bubble (WhatsApp/Telegram style).
class _ChatBubbleItem extends StatelessWidget {
  final _ChatEntry entry;
  final VoidCallback? onTap;
  final bool isEditing;

  const _ChatBubbleItem({
    super.key,
    required this.entry,
    this.onTap,
    this.isEditing = false,
  });

  static const _bubbleRadius = 18.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderColor = isEditing ? colorScheme.primary : Colors.transparent;
    final bubble = Container(
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
          bottomRight: Radius.circular(entry.isUser ? 4 : _bubbleRadius),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        entry.text,
        style: textTheme.bodyMedium?.copyWith(
          color: entry.isUser
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      child: Row(
        mainAxisAlignment: entry.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!entry.isUser) _buildAvatar(context),
          if (!entry.isUser) const Gap(AthlosSpacing.xs),
          Flexible(
            child: onTap == null
                ? bubble
                : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_bubbleRadius),
                      onTap: onTap,
                      child: bubble,
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
      child: Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
    );
  }
}

/// Fixed bottom bar with the current step input (WhatsApp/Telegram style).
class _SetupInputBar extends StatelessWidget {
  final _StepType? step;
  final _ProfileSetupScreenState state;

  const _SetupInputBar({required this.step, required this.state});

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
        initialValue: state._injuries ?? '',
      ),
      _StepType.bio => _TextInput(
        hint: AppLocalizations.of(context)!.bioHint,
        onSubmitted: state._onBioSubmitted,
        allowSkip: true,
        skipLabel: AppLocalizations.of(context)!.skip,
        initialValue: state._bio ?? '',
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
              border: OutlineInputBorder(borderRadius: AthlosRadius.mdAll),
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

class _BodyInput extends StatelessWidget {
  final _ProfileSetupScreenState state;
  const _BodyInput({required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    InputDecoration bodyFieldDecoration({
      required String labelText,
      String? suffixText,
    }) =>
        InputDecoration(
          labelText: labelText,
          suffixText: suffixText,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AthlosSpacing.smd,
            vertical: AthlosSpacing.smd,
          ),
          border: OutlineInputBorder(borderRadius: AthlosRadius.mdAll),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: state._weightCtrl,
          decoration: bodyFieldDecoration(labelText: l10n.weightLabel),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        TextField(
          controller: state._bodyFatCtrl,
          decoration: bodyFieldDecoration(
            labelText: l10n.bodyMetricsBodyFatLabel,
          ).copyWith(hintText: l10n.bodyMetricsBodyFatHint),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        TextField(
          controller: state._heightCtrl,
          decoration: bodyFieldDecoration(labelText: l10n.heightLabel),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const Gap(AthlosSpacing.sm),
        TextField(
          controller: state._ageCtrl,
          decoration: bodyFieldDecoration(
            labelText: l10n.ageLabel,
            suffixText: l10n.yearsUnit,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const Gap(AthlosSpacing.sm),
        FilledButton(
          onPressed: state._onBodySubmitted,
          child: Text(l10n.next),
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
        Text('$_value ${l10n.daysPerWeek}', style: textTheme.titleSmall),
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
    return AthlosStackedActions(
      spacing: AthlosSpacing.sm,
      children: [
        OutlinedButton(
          onPressed: () => state._onGymSelected(false),
          child: Text(l10n.no),
        ),
        FilledButton.tonal(
          onPressed: () => state._onGymSelected(true),
          child: Text(l10n.yes),
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
  final String initialValue;

  const _TextInput({
    required this.hint,
    required this.onSubmitted,
    this.allowSkip = false,
    this.skipLabel,
    this.initialValue = '',
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialValue;
  }

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
        AthlosStackedActions(
          spacing: AthlosSpacing.sm,
          children: [
            if (widget.allowSkip)
              OutlinedButton(
                onPressed: () => widget.onSubmitted(''),
                child: Text(widget.skipLabel ?? 'Pular'),
              ),
            FilledButton(
              onPressed: () => widget.onSubmitted(_ctrl.text),
              child: const Icon(Icons.send, size: 20),
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
