import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// Deep-dive links styled as tappable list tiles inside a card.
class KleosRelatedLinks extends StatelessWidget {
  const KleosRelatedLinks({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _LinkTile(
            icon: Icons.emoji_events_outlined,
            iconBackground: colorScheme.tertiaryContainer.withValues(
              alpha: 0.65,
            ),
            iconColor: colorScheme.tertiary,
            title: l10n.kleosLinkFullPrList,
            subtitle: l10n.kleosLinkFullPrListHint,
            onTap: () => context.push(RoutePaths.trainingPRHistory),
          ),
          Divider(
            height: 1,
            indent: AthlosSpacing.md + 40 + AthlosSpacing.md,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          _LinkTile(
            icon: Icons.stacked_bar_chart_outlined,
            iconBackground: colorScheme.primaryContainer.withValues(
              alpha: 0.65,
            ),
            iconColor: colorScheme.primary,
            title: l10n.kleosLinkWeeklyVolume,
            subtitle: l10n.kleosLinkWeeklyVolumeHint,
            onTap: () => context.push(RoutePaths.trainingVolumeTrend),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AthlosRadius.smAll,
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const Gap(AthlosSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AthlosSpacing.xxs),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
