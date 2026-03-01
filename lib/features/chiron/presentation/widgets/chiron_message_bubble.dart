import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../domain/entities/chiron_message.dart';

class ChironMessageBubble extends StatelessWidget {
  final ChironMessage message;
  final bool isStreaming;

  const ChironMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChironRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AthlosRadius.md),
            topRight: const Radius.circular(AthlosRadius.md),
            bottomLeft:
                isUser ? const Radius.circular(AthlosRadius.md) : Radius.zero,
            bottomRight:
                isUser ? Radius.zero : const Radius.circular(AthlosRadius.md),
          ),
        ),
        child: message.content.isEmpty && isStreaming
            ? SizedBox(
                width: AthlosSpacing.md,
                height: AthlosSpacing.md,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Text(
                message.content,
                style: textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
      ),
    );
  }
}
