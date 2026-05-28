import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chiron_chat_state.dart';
import '../providers/chiron_notifier.dart';
import 'chiron_message_bubble.dart';

/// Opens the Chiron AI chat as a modal bottom sheet.
///
/// If [initialMessage] is set, that message is sent automatically when the
/// sheet opens (e.g. "Monte meu treino" as a shortcut from the workout list).
void showChironSheet(BuildContext context, {String? initialMessage}) {
  showAthlosModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (sheetContext) =>
        _ChironSheet(initialMessage: initialMessage),
  );
}

class _ChironSheet extends ConsumerStatefulWidget {
  const _ChironSheet({this.initialMessage});

  final String? initialMessage;

  @override
  ConsumerState<_ChironSheet> createState() => _ChironSheetState();
}

class _ChironSheetState extends ConsumerState<_ChironSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final msg = widget.initialMessage?.trim();
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(chironProvider.notifier).send(msg);
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(chironProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        // Reversed list: 0 is the bottom (newest messages)
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendSuggestion(String suggestion) {
    _controller.text = suggestion;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatState = ref.watch(chironProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen(chironProvider, (prev, next) {
      _scrollToBottom();
      final workoutId = next.lastCreatedWorkoutId;
      if (workoutId != null && context.mounted) {
        Navigator.of(context).pop();
        context.push('${RoutePaths.trainingWorkouts}/$workoutId');
        ref.read(chironProvider.notifier).clearCreatedWorkoutId();
      }
    });

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final shouldConfirmLeave =
        chatState.isStreaming ||
        _controller.text.trim().isNotEmpty ||
        chatState.messages.isNotEmpty;

    return ConfirmNavigationScope(
      guardActive: shouldConfirmLeave,
      onConfirmLeave: confirmLeaveChironAssistant,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              _buildHandle(colorScheme),
              _buildHeader(l10n, chatState, colorScheme),
              const Divider(height: 1),
              Expanded(
                child: chatState.messages.isEmpty
                    ? _buildEmptyState(l10n, colorScheme, textTheme)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ListView.separated(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.all(AthlosSpacing.md),
                              itemCount: chatState.messages.length,
                              separatorBuilder: (context, index) =>
                                  const Gap(AthlosSpacing.sm),
                              itemBuilder: (context, index) {
                                final reverseIndex =
                                    chatState.messages.length - 1 - index;
                                final message =
                                    chatState.messages[reverseIndex];
                                final isNewest = index == 0;
                                final isLastError =
                                    isNewest &&
                                    !chatState.isStreaming &&
                                    chatState.hasError;
                                return ChironMessageBubble(
                                  key: ValueKey(reverseIndex),
                                  message: message,
                                  isStreaming:
                                      isNewest && chatState.isStreaming,
                                  isError: isLastError,
                                );
                              },
                            ),
                          ),
                          if (chatState.isStreaming) ...[
                            if (chatState.lastResponseToolFeedback.isNotEmpty)
                              _buildToolFeedbackChips(
                                l10n,
                                colorScheme,
                                chatState.lastResponseToolFeedback,
                              ),
                            _buildThinkingIndicator(l10n, colorScheme),
                          ] else if (chatState.lastResponseToolFeedback.any(
                            _isMutationTool,
                          ))
                            _buildToolFeedbackChips(
                              l10n,
                              colorScheme,
                              chatState.lastResponseToolFeedback
                                  .where(_isMutationTool)
                                  .toList(),
                            ),
                        ],
                      ),
              ),
              _buildInputBar(l10n, colorScheme, chatState.isStreaming),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolFeedbackChips(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    List<ChironToolFeedback> feedback,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AthlosSpacing.md,
        0,
        AthlosSpacing.md,
        AthlosSpacing.sm,
      ),
      child: Wrap(
        spacing: AthlosSpacing.xs,
        runSpacing: AthlosSpacing.xs,
        children: feedback
            .where((f) => f.success)
            .map(
              (f) => Chip(
                label: Text(
                  _toolFeedbackLabel(l10n, f.toolName),
                  style: TextStyle(fontSize: 12, color: colorScheme.primary),
                ),
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
                backgroundColor: colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AthlosSpacing.sm,
                  vertical: AthlosSpacing.xxs,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(),
      ),
    );
  }

  static const _readOnlyTools = {'requestExtendedHistory', 'getTrainingState'};

  static bool _isMutationTool(ChironToolFeedback f) =>
      f.success && !_readOnlyTools.contains(f.toolName);

  String _toolFeedbackLabel(AppLocalizations l10n, String toolName) {
    switch (toolName) {
      case 'createWorkout':
        return l10n.chironToolFeedbackCreateWorkout;
      case 'updateWorkout':
        return l10n.chironToolFeedbackUpdateWorkout;
      case 'archiveWorkout':
        return l10n.chironToolFeedbackArchiveWorkout;
      case 'setCycle':
        return l10n.chironToolFeedbackSetCycle;
      case 'updateBio':
        return l10n.chironToolFeedbackUpdateBio;
      case 'setInjuries':
        return l10n.chironToolFeedbackSetInjuries;
      case 'updateExperienceLevel':
        return l10n.chironToolFeedbackUpdateExperienceLevel;
      case 'updateGender':
        return l10n.chironToolFeedbackUpdateGender;
      case 'updateTrainingFrequency':
        return l10n.chironToolFeedbackUpdateTrainingFrequency;
      case 'updateTrainsAtGym':
        return l10n.chironToolFeedbackUpdateTrainsAtGym;
      case 'updateAvailableMinutes':
        return l10n.chironToolFeedbackUpdateAvailableMinutes;
      case 'registerEquipment':
        return l10n.chironToolFeedbackRegisterEquipment;
      case 'removeEquipment':
        return l10n.chironToolFeedbackRemoveEquipment;
      case 'requestExtendedHistory':
        return l10n.chironToolFeedbackRequestExtendedHistory;
      case 'getTrainingState':
        return l10n.chironToolFeedbackGetTrainingState;
      default:
        return toolName;
    }
  }

  Widget _buildThinkingIndicator(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const Gap(AthlosSpacing.sm),
          Text(
            l10n.chironThinking,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: AthlosSpacing.sm),
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: AthlosRadius.fullAll,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    dynamic chatState,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AthlosSpacing.md,
        vertical: AthlosSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: colorScheme.primary),
          const Gap(AthlosSpacing.sm),
          Text(
            l10n.chironTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.chironClearChat,
              onPressed: () => ref.read(chironProvider.notifier).clear(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final suggestions = [
      l10n.chironSuggestion1,
      l10n.chironSuggestion2,
      l10n.chironSuggestion3,
      l10n.chironSuggestion4,
      l10n.chironSuggestion5,
      l10n.chironSuggestion6,
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(AthlosSpacing.md),
            Text(
              l10n.chironEmptyState,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(AthlosSpacing.xs),
            Text(
              l10n.chironEmptySubtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const Gap(AthlosSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AthlosSpacing.sm,
              runSpacing: AthlosSpacing.sm,
              children: suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      onPressed: () => _sendSuggestion(s),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isStreaming,
  ) {
    return Container(
      padding: const EdgeInsets.all(AthlosSpacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.chironInputHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                    vertical: AthlosSpacing.sm,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                enabled: !isStreaming,
              ),
            ),
            const Gap(AthlosSpacing.sm),
            IconButton.filled(
              icon: isStreaming
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send),
              onPressed: isStreaming ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
