import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/training_style.dart';

/// Selector for [TrainingStyle].
///
/// Each style is a selectable card with icon, title, and short description.
/// When [showHelp] is true, an animated panel expands below each card
/// explaining the impact of that option on the system.
class StyleSelector extends StatelessWidget {
  final TrainingStyle? selected;
  final ValueChanged<TrainingStyle> onSelected;
  final bool showHelp;

  const StyleSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showHelp = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.styleSelectTitle, style: textTheme.titleMedium),
        const Gap(AthlosSpacing.md),
        ...TrainingStyle.values.map((style) {
          final isSelected = style == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: AthlosSpacing.sm),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: isSelected ? 2 : 0,
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: AthlosRadius.mdAll,
                side: isSelected
                    ? BorderSide(color: colorScheme.primary, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => onSelected(style),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AthlosSpacing.md,
                    vertical: AthlosSpacing.smd,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconFor(style),
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          const Gap(AthlosSpacing.smd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleFor(style, l10n),
                                  style: textTheme.titleSmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _descriptionFor(style, l10n),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            ),
                        ],
                      ),

                      // Help panel
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: showHelp
                            ? Padding(
                                padding: const EdgeInsets.only(top: AthlosSpacing.smd),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AthlosSpacing.smd),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: colorScheme.surfaceContainerHighest
                                        .withAlpha(120),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const Gap(AthlosSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          _impactFor(style, l10n),
                                          style:
                                              textTheme.bodySmall?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _iconFor(TrainingStyle style) => switch (style) {
        TrainingStyle.traditional => Icons.fitness_center,
        TrainingStyle.calisthenics => Icons.sports_gymnastics,
        TrainingStyle.functional => Icons.sports_martial_arts,
        TrainingStyle.hybrid => Icons.sync_alt,
      };

  String _titleFor(TrainingStyle style, AppLocalizations l10n) =>
      switch (style) {
        TrainingStyle.traditional => l10n.styleTraditional,
        TrainingStyle.calisthenics => l10n.styleCalisthenics,
        TrainingStyle.functional => l10n.styleFunctional,
        TrainingStyle.hybrid => l10n.styleHybrid,
      };

  String _descriptionFor(TrainingStyle style, AppLocalizations l10n) =>
      switch (style) {
        TrainingStyle.traditional => l10n.styleTraditionalDesc,
        TrainingStyle.calisthenics => l10n.styleCalisthenicsDesc,
        TrainingStyle.functional => l10n.styleFunctionalDesc,
        TrainingStyle.hybrid => l10n.styleHybridDesc,
      };

  String _impactFor(TrainingStyle style, AppLocalizations l10n) =>
      switch (style) {
        TrainingStyle.traditional => l10n.styleTraditionalImpact,
        TrainingStyle.calisthenics => l10n.styleCalisthenicsImpact,
        TrainingStyle.functional => l10n.styleFunctionalImpact,
        TrainingStyle.hybrid => l10n.styleHybridImpact,
      };
}
