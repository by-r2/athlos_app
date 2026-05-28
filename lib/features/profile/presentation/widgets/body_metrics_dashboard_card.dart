import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/body_metric_notifier.dart';
import '../providers/body_metrics_dashboard_provider.dart';
import 'body_metrics_sheets.dart';

/// Unified dashboard card for body-metrics (weight + optional body fat).
///
/// Replaces the isolated stale-weight prompt banner with a single card that
/// shows current values, deltas, freshness, and a stale warning when needed.
class BodyMetricsDashboardCard extends ConsumerWidget {
  const BodyMetricsDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(bodyMetricsDashboardProvider);

    return dashboardAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (state) => switch (state.status) {
        BodyMetricsDashboardStatus.empty => _buildEmptyCard(context, ref),
        BodyMetricsDashboardStatus.stale ||
        BodyMetricsDashboardStatus.upToDate => _buildMetricsCard(
          context,
          ref,
          state,
        ),
      },
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────

  Widget _buildEmptyCard(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, colorScheme, textTheme),
            const Gap(AthlosSpacing.sm),
            Text(
              l10n.bodyMetricsEmptyHint,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(AthlosSpacing.smd),
            FilledButton(
              style: AthlosScreenButtonStyles.stackedFilled(context),
              onPressed: () => showBodyMetricRecordSheet(context: context, ref: ref),
              child: Text(l10n.bodyMetricsRecordWeight),
            ),
          ],
        ),
      ),
    );
  }

  // ── Data states (stale / up-to-date) ─────────────────────────────────

  Widget _buildMetricsCard(
    BuildContext context,
    WidgetRef ref,
    BodyMetricsDashboardState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isStale = state.status == BodyMetricsDashboardStatus.stale;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              l10n,
              colorScheme,
              textTheme,
              daysSince: state.daysSinceLastEntry,
              isStale: isStale,
            ),
            if (isStale) ...[
              const Gap(AthlosSpacing.xs),
              Text(
                l10n.bodyMetricsDashboardStaleHint,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
            const Gap(AthlosSpacing.smd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${formatBodyMetricWeight(state.latestWeight!)} kg',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.weightDelta != null) ...[
                  const Gap(AthlosSpacing.sm),
                  _buildDelta(state.weightDelta!, 'kg', colorScheme, textTheme),
                ],
              ],
            ),
            if (state.latestBodyFat != null) ...[
              const Gap(AthlosSpacing.xs),
              Row(
                children: [
                  Text(
                    l10n.bodyMetricsDashboardBodyFat(
                      state.latestBodyFat!.toStringAsFixed(1),
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (state.bodyFatDelta != null) ...[
                    const Gap(AthlosSpacing.sm),
                    _buildDelta(
                      state.bodyFatDelta!,
                      '%',
                      colorScheme,
                      textTheme,
                    ),
                  ],
                ],
              ),
            ],
            const Gap(AthlosSpacing.smd),
            AthlosStackedActions(
              children: [
                TextButton(
                  style: AthlosScreenButtonStyles.stackedGhost(context),
                  onPressed: () {
                    final metrics = ref.read(bodyMetricListProvider).value;
                    if (metrics == null || metrics.isEmpty) return;
                    showBodyMetricHistorySheet(
                      context: context,
                      metrics: metrics,
                    );
                  },
                  child: Text(l10n.bodyMetricsHistory),
                ),
                FilledButton(
                  style: AthlosScreenButtonStyles.stackedFilled(context),
                  onPressed: () =>
                      showBodyMetricRecordSheet(context: context, ref: ref),
                  child: Text(l10n.bodyMetricsRecordWeight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Header row ───────────────────────────────────────────────────────

  Widget _buildHeader(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    int? daysSince,
    bool isStale = false,
  }) {
    return Row(
      children: [
        Icon(
          Icons.monitor_weight_outlined,
          size: 20,
          color: isStale ? colorScheme.error : colorScheme.primary,
        ),
        const Gap(AthlosSpacing.xs),
        Expanded(
          child: Text(
            l10n.bodyMetricsSectionTitle,
            style: textTheme.titleSmall,
          ),
        ),
        if (daysSince != null) ...[
          if (isStale) ...[
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: colorScheme.error,
            ),
            const Gap(AthlosSpacing.xxs),
          ],
          Text(
            daysSince == 0
                ? l10n.bodyMetricsDashboardUpdatedToday
                : l10n.bodyMetricsDashboardUpdatedDaysAgo(daysSince),
            style: textTheme.labelSmall?.copyWith(
              color: isStale ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  // ── Delta chip ───────────────────────────────────────────────────────

  Widget _buildDelta(
    double delta,
    String unit,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isZero = delta.abs() < 0.05;
    final isPositive = delta > 0;
    final icon = isZero
        ? Icons.remove
        : isPositive
        ? Icons.arrow_upward
        : Icons.arrow_downward;
    final label = isZero
        ? '0 $unit'
        : '${isPositive ? "+" : ""}${delta.toStringAsFixed(1)} $unit';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const Gap(AthlosSpacing.xxs),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
