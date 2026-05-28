import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' as intl;

import 'dart:math' as math;

import '../../../../core/theme/athlos_dialog.dart';
import '../../../../core/widgets/feedback/athlos_dialog_actions.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_scaffold.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../domain/enums/muscle_group.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/training_metrics_provider.dart';

/// Bar chart showing weekly **working set counts** per muscle group (Mon–Sun weeks).
class VolumeTrendChartScreen extends ConsumerStatefulWidget {
  const VolumeTrendChartScreen({super.key});

  @override
  ConsumerState<VolumeTrendChartScreen> createState() =>
      _VolumeTrendChartScreenState();
}

class _VolumeTrendChartScreenState
    extends ConsumerState<VolumeTrendChartScreen> {
  String? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final trendAsync = ref.watch(weeklyVolumeTrendProvider());
    final profileAsync = ref.watch(profileProvider);
    final experienceLevel = profileAsync.value?.experienceLevel?.name;
    final target = volumeTargetForLevel(experienceLevel);

    return AthlosScaffold(
      appBar: AppBar(
        title: Text(l10n.volumeTrendTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: l10n.weeklyVolumeTooltip,
            onPressed: () => showAthlosDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.weeklyVolume),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Text(l10n.volumeTrendDescription)],
                ),
                actions: [
                  AthlosStackedDialogActions(
                    children: [
                      FilledButton(
                        style: AthlosDialogButtonStyles.stackedFilled(
                          dialogContext,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.okButton),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: trendAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.genericError)),
        data: (trend) {
          if (trend.isEmpty) {
            return Center(
              child: Text(
                l10n.bodyMetricsNoData,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final groups = trend.keys.toList()..sort();
          final selected = _selectedGroup ?? groups.first;
          final points = trend[selected] ?? [];

          return Padding(
            padding: const EdgeInsets.all(AthlosSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.volumeTrendSubtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(AthlosSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: groups
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(
                              right: AthlosSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text(_muscleGroupLabel(g, l10n)),
                              selected: g == selected,
                              onSelected: (_) =>
                                  setState(() => _selectedGroup = g),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Gap(AthlosSpacing.sm),
                Row(
                  children: [
                    _LegendItem(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                      label: l10n.volumeTrendLegendMin(target.min),
                      textTheme: textTheme,
                    ),
                    const Gap(AthlosSpacing.md),
                    _LegendItem(
                      color: colorScheme.tertiary.withValues(alpha: 0.6),
                      label: l10n.volumeTrendLegendMax(target.max),
                      textTheme: textTheme,
                    ),
                  ],
                ),
                const Gap(AthlosSpacing.md),
                Expanded(
                  child: points.isEmpty
                      ? Center(
                          child: Text(
                            l10n.bodyMetricsNoData,
                            style: textTheme.bodyMedium,
                          ),
                        )
                      : _buildBarChart(
                          points,
                          target,
                          colorScheme,
                          textTheme,
                          l10n,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBarChart(
    List<({DateTime weekStartMonday, int workingSetCount})> points,
    ({int min, int max}) target,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    final dateFormat = intl.DateFormat.MMMd();
    final maxSets = points
        .map((p) => p.workingSetCount)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final chartMax = math.max(maxSets, target.max) + 2;

    return BarChart(
      BarChartData(
        barGroups: points.asMap().entries.map((e) {
          final sets = e.value.workingSetCount;
          Color barColor;
          if (sets < target.min) {
            barColor = colorScheme.error.withValues(alpha: 0.7);
          } else if (sets > target.max) {
            barColor = colorScheme.tertiary.withValues(alpha: 0.7);
          } else {
            barColor = colorScheme.primary;
          }
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: sets.toDouble(),
                color: barColor,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    dateFormat.format(points[idx].weekStartMonday),
                    style: textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
        maxY: chartMax.toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: target.min.toDouble(),
              color: colorScheme.primary.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [6, 4],
            ),
            HorizontalLine(
              y: target.max.toDouble(),
              color: colorScheme.tertiary.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [6, 4],
            ),
          ],
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              final p = points[group.x];
              return BarTooltipItem(
                '${dateFormat.format(p.weekStartMonday)}\n'
                '${l10n.weeklyVolumeSets(p.workingSetCount)}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _muscleGroupLabel(String name, AppLocalizations l10n) {
  final group = MuscleGroup.values.where((g) => g.name == name).firstOrNull;
  if (group != null) return localizedMuscleGroupName(group, l10n);
  return name;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final TextTheme textTheme;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(color: color),
        ),
        const Gap(AthlosSpacing.xs),
        Text(label, style: textTheme.labelSmall),
      ],
    );
  }
}
