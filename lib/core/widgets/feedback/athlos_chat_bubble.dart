import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../constants/athlos_assets.dart';
import '../../theme/athlos_spacing.dart';

/// Reusable chat bubble used by setup-like conversational flows.
class AthlosChatBubble extends StatelessWidget {
  const AthlosChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onTap,
    this.isEditing = false,
    this.showAssistantAvatar = true,
  });

  final String text;
  final bool isUser;
  final VoidCallback? onTap;
  final bool isEditing;
  final bool showAssistantAvatar;

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
        color: isUser
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(_bubbleRadius),
          topRight: const Radius.circular(_bubbleRadius),
          bottomLeft: Radius.circular(isUser ? _bubbleRadius : 4),
          bottomRight: Radius.circular(isUser ? 4 : _bubbleRadius),
        ),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: textTheme.bodyMedium?.copyWith(
          color: isUser
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && showAssistantAvatar) _buildAvatar(context),
          if (!isUser && showAssistantAvatar) const Gap(AthlosSpacing.xs),
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
          if (isUser) const Gap(AthlosSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const avatarSize = 32.0;
    const symbolSize = 24.0;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
        boxShadow: colorScheme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        AthlosAssets.athlosSymbol,
        width: symbolSize,
        height: symbolSize,
      ),
    );
  }
}
