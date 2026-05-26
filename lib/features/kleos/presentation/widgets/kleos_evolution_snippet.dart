import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/athlos_radius.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../training/domain/entities/execution_comparison.dart';
import '../../../training/presentation/helpers/duration_format.dart';
import '../../../training/presentation/providers/training_analytics_provider.dart';

/// Compact recent workout comparison card.
class KleosEvolutionSnippet extends ConsumerWidget {
  const KleosEvolutionSnippet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(lastExecutedWorkoutComparisonProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final c = data.comparison;
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final locale = Localizations.localeOf(context);
        final lastDurationSec = c.last.duration?.inSeconds ?? 0;
        final prevDurationSec = c.previous.duration?.inSeconds ?? 0;
        final hasDelta = c.volumeDelta != 0 || c.volumePercentChange != null;
        final deltaColor = c.volumeDelta > 0
            ? colorScheme.primary
            : c.volumeDelta < 0
                ? colorScheme.error
                : colorScheme.onSurfaceVariant;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(
              '${RoutePaths.trainingHistory}?workoutId=${c.last.workoutId}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const Gap(AthlosSpacing.xs),
                      Expanded(
                        child: Text(
                          l10n.trainingEvolutionRecent,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const Gap(AthlosSpacing.sm),
                  Text(
                    data.workoutName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(AthlosSpacing.md),
                  _SessionCompareRow(
                    label: l10n.trainingLastSession,
                    date: intl.DateFormat.MMMd(
                      locale.toString(),
                    ).format(c.last.startedAt.toLocal()),
                    duration: formatDuration(lastDurationSec),
                    volumeKg: c.volumeLast,
                  ),
                  const Gap(AthlosSpacing.xs),
                  _SessionCompareRow(
                    label: l10n.trainingPreviousSession,
                    date: intl.DateFormat.MMMd(
                      locale.toString(),
                    ).format(c.previous.startedAt.toLocal()),
                    duration: formatDuration(prevDurationSec),
                    volumeKg: c.volumePrevious,
                    isMuted: true,
                  ),
                  if (hasDelta) ...[
                    const Gap(AthlosSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AthlosSpacing.smd,
                        vertical: AthlosSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: deltaColor.withValues(alpha: 0.1),
                        borderRadius: AthlosRadius.smAll,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            c.volumeDelta > 0
                                ? Icons.trending_up
                                : c.volumeDelta < 0
                                    ? Icons.trending_down
                                    : Icons.trending_flat,
                            size: 18,
                            color: deltaColor,
                          ),
                          const Gap(AthlosSpacing.xs),
                          Expanded(
                            child: Text(
                              _deltaLabel(l10n, c),
                              style: textTheme.bodySmall?.copyWith(
                                color: deltaColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _deltaLabel(
    AppLocalizations l10n,
    ExecutionComparison comparison,
  ) {
    final delta = comparison.volumeDelta;
    final sign = delta > 0
        ? '+'
        : delta < 0
            ? '-'
            : '';
    final percent = comparison.volumePercentChange;

    if (percent != null) {
      final formattedPercent = '$sign${percent.abs().toStringAsFixed(0)}';
      return l10n.trainingVolumePercent(formattedPercent);
    }

    final formattedDelta = '$sign${delta.abs().toStringAsFixed(1)}';
    return l10n.trainingVolumeDelta(formattedDelta);
  }
}

class _SessionCompareRow extends StatelessWidget {
  const _SessionCompareRow({
    required this.label,
    required this.date,
    required this.duration,
    required this.volumeKg,
    this.isMuted = false,
  });

  final String label;
  final String date;
  final String duration;
  final double volumeKg;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = textTheme.bodySmall?.copyWith(
      color: isMuted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
    );

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: labelStyle),
        ),
        Expanded(
          child: Text('$date · $duration', style: valueStyle),
        ),
        Text(
          '${volumeKg.toStringAsFixed(0)} kg',
          style: valueStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
