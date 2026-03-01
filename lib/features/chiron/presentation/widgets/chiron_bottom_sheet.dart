import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chiron_notifier.dart';
import 'chiron_message_bubble.dart';

/// Opens the Chiron AI chat as a modal bottom sheet.
///
/// If [initialMessage] is set, that message is sent automatically when the
/// sheet opens (e.g. "Monte meu treino" as a shortcut from the workout list).
void showChironSheet(BuildContext context, {String? initialMessage}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AthlosRadius.lg)),
    ),
    builder: (_) => _ChironSheet(initialMessage: initialMessage),
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

    ref.listen(chironProvider, (prev, next) => _scrollToBottom());

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
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
                  : ListView.separated(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(AthlosSpacing.md),
                      itemCount: chatState.messages.length,
                      separatorBuilder: (context, index) => const Gap(AthlosSpacing.sm),
                      itemBuilder: (context, index) {
                        final reverseIndex =
                            chatState.messages.length - 1 - index;
                        final message = chatState.messages[reverseIndex];
                        final isNewest = index == 0;
                        return ChironMessageBubble(
                          key: ValueKey(reverseIndex),
                          message: message,
                          isStreaming: isNewest && chatState.isStreaming,
                        );
                      },
                    ),
            ),
            _buildInputBar(l10n, colorScheme, chatState.isStreaming),
          ],
        ),
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
            ...suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
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
    return Container(
      padding: const EdgeInsets.all(AthlosSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
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
