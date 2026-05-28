import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/body_metric_notifier.dart';
import '../providers/body_metrics_dashboard_provider.dart';

double? _tryParseDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String _formatWeight(double weight) =>
    weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);

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
            AthlosDialogButtonTheme.wrap(
              context,
              Builder(
                builder: (innerCtx) => SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: AthlosDialogButtonStyles.stackedFilled(innerCtx),
                    onPressed: () => _showRecordDialog(context, ref),
                    child: Text(l10n.bodyMetricsRecordWeight),
                  ),
                ),
              ),
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
                  '${_formatWeight(state.latestWeight!)} kg',
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
            AthlosDialogButtonTheme.wrap(
              context,
              Builder(
                builder: (innerCtx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton(
                      style: AthlosDialogButtonStyles.stackedGhost(innerCtx),
                      onPressed: () => _showHistory(context, ref),
                      child: Text(l10n.bodyMetricsHistory),
                    ),
                    const SizedBox(height: AthlosSpacing.xs),
                    FilledButton(
                      style: AthlosDialogButtonStyles.stackedFilled(innerCtx),
                      onPressed: () => _showRecordDialog(context, ref),
                      child: Text(l10n.bodyMetricsRecordWeight),
                    ),
                  ],
                ),
              ),
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

  // ── Record dialog ────────────────────────────────────────────────────

  void _showRecordDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final weightCtrl = TextEditingController();
    final bfCtrl = TextEditingController();

    showAthlosDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bodyMetricsRecordWeight),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: weightCtrl,
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsWeightLabel,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              autofocus: true,
            ),
            const Gap(AthlosSpacing.md),
            TextField(
              controller: bfCtrl,
              decoration: InputDecoration(
                labelText: l10n.bodyMetricsBodyFatLabel,
                hintText: l10n.bodyMetricsBodyFatHint,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
            ),
          ],
        ),
        actions: [
          AthlosStackedDialogActions(
            children: [
              TextButton(
                style: AthlosDialogButtonStyles.stackedGhost(ctx),
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                style: AthlosDialogButtonStyles.stackedFilled(ctx),
                onPressed: () {
                  final w = _tryParseDecimal(weightCtrl.text);
                  if (w == null || w <= 0) return;
                  final bf = _tryParseDecimal(bfCtrl.text);
                  ref
                      .read(bodyMetricListProvider.notifier)
                      .add(weight: w, bodyFatPercent: bf);
                  Navigator.pop(ctx);
                },
                child: Text(l10n.bodyMetricsWeeklyPromptRecord),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── History bottom sheet ─────────────────────────────────────────────

  void _showHistory(BuildContext context, WidgetRef ref) {
    final metrics = ref.read(bodyMetricListProvider).value;
    if (metrics == null || metrics.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    showAthlosModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      wrapInShell: false,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => AthlosBottomSheetShell(
          expand: true,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AthlosSpacing.md),
              child: Text(
                l10n.bodyMetricsHistory,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: metrics.length,
                itemBuilder: (ctx, i) {
                  final m = metrics[i];
                  final date =
                      '${m.recordedAt.day}/${m.recordedAt.month}/${m.recordedAt.year}';
                  return ListTile(
                    key: ValueKey(m.id),
                    title: Text('${_formatWeight(m.weight)} kg'),
                    subtitle: Text(date),
                    trailing: m.bodyFatPercent != null
                        ? Text('${m.bodyFatPercent!.toStringAsFixed(1)}%')
                        : null,
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
