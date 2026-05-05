import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../domain/entities/chiron_message.dart';

class ChironMessageBubble extends StatelessWidget {
  final ChironMessage message;
  final bool isStreaming;
  final bool isError;

  const ChironMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChironRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Don't render empty assistant bubbles — the thinking indicator
    // in the bottom sheet handles the loading state.
    if (!isUser && message.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final bgColor = isError
        ? colorScheme.errorContainer
        : isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    final textColor = isError
        ? colorScheme.onErrorContainer
        : isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.md,
          vertical: AthlosSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AthlosRadius.md),
            topRight: const Radius.circular(AthlosRadius.md),
            bottomLeft: isUser
                ? const Radius.circular(AthlosRadius.md)
                : Radius.zero,
            bottomRight: isUser
                ? Radius.zero
                : const Radius.circular(AthlosRadius.md),
          ),
        ),
        child: isError
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: colorScheme.error),
                  const Gap(AthlosSpacing.sm),
                  Flexible(
                    child: Text(
                      message.content,
                      style: textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                ],
              )
            : MarkdownBody(
                data: message.content,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: textTheme.bodyMedium?.copyWith(color: textColor),
                  strong: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  em: textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontStyle: FontStyle.italic,
                  ),
                  listBullet: textTheme.bodyMedium?.copyWith(color: textColor),
                  blockSpacing: AthlosSpacing.xs,
                ),
              ),
      ),
    );
  }
}
