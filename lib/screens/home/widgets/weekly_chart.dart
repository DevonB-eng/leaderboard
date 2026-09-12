import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/widgets/section_card.dart';

/// Candidate y-axis tick spacings, in minutes, from fine to coarse.
const _niceStepsMinutes = [
  5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300, 360, 480, 600, 720, 1440,
];

/// Picks the smallest "nice" tick spacing that keeps the axis to 4 intervals,
/// so labels stay round numbers (e.g. 30m/1h/1h 30m) instead of collapsing
/// duplicate whole-hour labels when the data only spans a few minutes.
double _chartStepMinutes(double maxMinutes) {
  for (final step in _niceStepsMinutes) {
    if (maxMinutes / step <= 4) return step.toDouble();
  }
  return (maxMinutes / 4).ceilToDouble();
}

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({
    super.key,
    required this.history,
    required this.dateKeys,
    required this.dayLabels,
    required this.isLoading,
  });

  final WeeklyHistory? history;
  final List<String> dateKeys;
  final List<String> dayLabels;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final personal = history?.personal ?? {for (final d in dateKeys) d: 0.0};
    final group = history?.group ?? {for (final d in dateKeys) d: 0.0};

    final allValues = [...personal.values, ...group.values];
    final maxMinutes = allValues.isEmpty
        ? 0.0
        : allValues.reduce((a, b) => a > b ? a : b);
    final step = _chartStepMinutes(maxMinutes <= 0 ? 60 : maxMinutes);
    final maxY = step * 4;

    return SectionCard(
      title: 'LAST 7 DAYS',
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _LegendDot(color: AppColors.sky, label: 'YOU'),
                const SizedBox(width: 16),
                const _LegendDot(
                  color: AppColors.chartAvg,
                  label: 'GROUP AVG',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : BarChart(
                      BarChartData(
                        maxY: maxY,
                        minY: 0,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final label = rodIndex == 0 ? 'You' : 'Group Avg';
                              return BarTooltipItem(
                                '$label\n${formatMinutes(rod.toY)}',
                                AppTextStyles.copy(
                                  size: 11,
                                  color: AppColors.background,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= dayLabels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dayLabels[i],
                                    style: AppTextStyles.copy(
                                      size: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 28,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              interval: step,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  formatMinutes(value),
                                  style: AppTextStyles.copy(
                                    size: 10,
                                    color: AppColors.textMuted,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: step,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.ink.withValues(alpha: 0.09),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(dateKeys.length, (i) {
                          final date = dateKeys[i];
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: personal[date] ?? 0,
                                color: AppColors.sky,
                                width: 8,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(999),
                                ),
                              ),
                              BarChartRodData(
                                toY: group[date] ?? 0,
                                color: AppColors.chartAvg,
                                width: 8,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(999),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
            if (!isLoading && allValues.every((v) => v == 0))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'No history yet — check back after your first full day.',
                  style: AppTextStyles.copy(size: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.fieldLabel(size: 10)),
      ],
    );
  }
}
