import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../helpers/exercise_l10n.dart';
import '../providers/exercise_notifier.dart';
import '../providers/training_metrics_provider.dart';

/// Full-screen line chart showing estimated 1RM over time for a single exercise.
class ExerciseLoadChartScreen extends ConsumerStatefulWidget {
  final String exerciseId;

  const ExerciseLoadChartScreen({super.key, required this.exerciseId});

  @override
  ConsumerState<ExerciseLoadChartScreen> createState() =>
      _ExerciseLoadChartScreenState();
}

class _ExerciseLoadChartScreenState
    extends ConsumerState<ExerciseLoadChartScreen> {
  ChartTimeRange _range = ChartTimeRange.allTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final exercisesAsync = ref.watch(exerciseListProvider);
    final exercise = exercisesAsync.value
        ?.where((e) => e.id == widget.exerciseId)
        .firstOrNull;
    final exerciseName = exercise != null
        ? localizedExerciseName(
            exercise.name,
            isVerified: exercise.isVerified,
            l10n: l10n,
          )
        : '...';

    final dataAsync = ref.watch(
      exerciseLoadHistoryProvider(widget.exerciseId, range: _range),
    );

    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: Padding(
        padding: const EdgeInsets.all(AthlosSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.loadChartTitle, style: textTheme.titleMedium),
            const Gap(AthlosSpacing.sm),
            SegmentedButton<ChartTimeRange>(
              segments: [
                ButtonSegment(
                  value: ChartTimeRange.days30,
                  label: Text(l10n.loadChartRange30),
                ),
                ButtonSegment(
                  value: ChartTimeRange.days90,
                  label: Text(l10n.loadChartRange90),
                ),
                ButtonSegment(
                  value: ChartTimeRange.allTime,
                  label: Text(l10n.loadChartRangeAll),
                ),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const Gap(AthlosSpacing.lg),
            Expanded(
              child: dataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(child: Text(l10n.genericError)),
                data: (points) {
                  if (points.length < 2) {
                    return Center(
                      child: Text(
                        l10n.bodyMetricsNoData,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return _buildChart(points, colorScheme, textTheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    List<LoadDataPoint> points,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateFormat = intl.DateFormat.MMMd();
    final firstDate = points.first.date;
    final spots = points
        .map(
          (p) => FlSpot(
            p.date.difference(firstDate).inDays.toDouble(),
            double.parse(p.estimated1RM.toStringAsFixed(1)),
          ),
        )
        .toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yMargin = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: spots.length <= 30,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3,
                color: colorScheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
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
              interval: _bottomInterval(spots),
              getTitlesWidget: (value, meta) {
                final date = firstDate.add(Duration(days: value.toInt()));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    dateFormat.format(date),
                    style: textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
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
        minY: (minY - yMargin).floorToDouble(),
        maxY: (maxY + yMargin).ceilToDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final date = firstDate.add(Duration(days: s.x.toInt()));
              return LineTooltipItem(
                '${dateFormat.format(date)}\n${s.y.toStringAsFixed(1)} kg',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  double _bottomInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final range = spots.last.x - spots.first.x;
    if (range <= 30) return 7;
    if (range <= 90) return 14;
    return 30;
  }
}
