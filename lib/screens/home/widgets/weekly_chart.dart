import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/widgets/section_card.dart';

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
    final maxY = allValues.isEmpty
        ? 100.0
        : (allValues.reduce((a, b) => a > b ? a : b) * 1.2).clamp(
            10.0,
            double.infinity,
          );

    return SectionCard(
      title: 'WEEKLY SCREENTIME',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: AppColors.primaryBright,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('You', style: AppTextStyles.label()),
                const SizedBox(width: AppSpacing.md),
                Container(width: 12, height: 12, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text('Group Avg', style: AppTextStyles.label()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 240,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : BarChart(
                      BarChartData(
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final label = rodIndex == 0 ? 'You' : 'Group Avg';
                              return BarTooltipItem(
                                '$label\n${formatMinutes(rod.toY)}',
                                AppTextStyles.label(
                                  color: AppColors.textPrimary,
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
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    dayLabels[i],
                                    style: AppTextStyles.label(),
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
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  formatMinutes(value),
                                  style: AppTextStyles.label(
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
                          horizontalInterval: maxY / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.3,
                            ),
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
                                color: AppColors.primaryBright,
                                width: 12,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                              BarChartRodData(
                                toY: group[date] ?? 0,
                                color: AppColors.textMuted,
                                width: 12,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
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
                  style: AppTextStyles.label(color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
