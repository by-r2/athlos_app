import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chiron_notifier.dart';
import '../widgets/chiron_message_bubble.dart';

class ChironChatScreen extends ConsumerStatefulWidget {
  const ChironChatScreen({super.key});

  @override
  ConsumerState<ChironChatScreen> createState() => _ChironChatScreenState();
}

class _ChironChatScreenState extends ConsumerState<ChironChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

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
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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

    ref.listen(chironProvider, (_, _) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chironTitle),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.chironClearChat,
              onPressed: () =>
                  ref.read(chironProvider.notifier).clear(),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(l10n, colorScheme, textTheme)
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AthlosSpacing.md),
                    itemCount: chatState.messages.length,
                    separatorBuilder: (_, _) =>
                        const Gap(AthlosSpacing.sm),
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isLast =
                          index == chatState.messages.length - 1;
                      return ChironMessageBubble(
                        key: ValueKey(index),
                        message: message,
                        isStreaming: isLast && chatState.isStreaming,
                      );
                    },
                  ),
          ),
          _buildInputBar(l10n, colorScheme, chatState.isStreaming),
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
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const Gap(AthlosSpacing.md),
            Text(
              l10n.chironEmptyState,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AthlosSpacing.lg),
            ...suggestions.map(
              (s) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AthlosSpacing.sm),
                child: ActionChip(
                  label: Text(s),
                  onPressed: () => _sendSuggestion(s),
                ),
              ),
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
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.sm,
          vertical: AthlosSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
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
                  fillColor: colorScheme.surfaceContainerHighest,
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
