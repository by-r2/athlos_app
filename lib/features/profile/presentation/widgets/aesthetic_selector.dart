import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/body_aesthetic.dart';

/// Selector for [BodyAesthetic].
///
/// Each aesthetic is a selectable card with icon, title, and short description.
/// When [showHelp] is true, an animated panel expands below each card
/// explaining the impact of that option on the system.
class AestheticSelector extends StatelessWidget {
  final BodyAesthetic? selected;
  final ValueChanged<BodyAesthetic> onSelected;
  final bool showHelp;

  const AestheticSelector({
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
        Text(l10n.aestheticSelectTitle, style: textTheme.titleMedium),
        const Gap(AthlosSpacing.md),
        ...BodyAesthetic.values.map((aesthetic) {
          final isSelected = aesthetic == selected;
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
                onTap: () => onSelected(aesthetic),
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
                            _iconFor(aesthetic),
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
                                  _titleFor(aesthetic, l10n),
                                  style: textTheme.titleSmall?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _descriptionFor(aesthetic, l10n),
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
                                    borderRadius: AthlosRadius.smAll,
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
                                          _impactFor(aesthetic, l10n),
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

  IconData _iconFor(BodyAesthetic aesthetic) => switch (aesthetic) {
        BodyAesthetic.athletic => Icons.sports_gymnastics,
        BodyAesthetic.bulky => Icons.fitness_center,
        BodyAesthetic.robust => Icons.bolt,
      };

  String _titleFor(BodyAesthetic aesthetic, AppLocalizations l10n) =>
      switch (aesthetic) {
        BodyAesthetic.athletic => l10n.aestheticAthletic,
        BodyAesthetic.bulky => l10n.aestheticBulky,
        BodyAesthetic.robust => l10n.aestheticRobust,
      };

  String _descriptionFor(BodyAesthetic aesthetic, AppLocalizations l10n) =>
      switch (aesthetic) {
        BodyAesthetic.athletic => l10n.aestheticAthleticDesc,
        BodyAesthetic.bulky => l10n.aestheticBulkyDesc,
        BodyAesthetic.robust => l10n.aestheticRobustDesc,
      };

  String _impactFor(BodyAesthetic aesthetic, AppLocalizations l10n) =>
      switch (aesthetic) {
        BodyAesthetic.athletic => l10n.aestheticAthleticImpact,
        BodyAesthetic.bulky => l10n.aestheticBulkyImpact,
        BodyAesthetic.robust => l10n.aestheticRobustImpact,
      };
}
