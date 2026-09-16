import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/providers/history_provider.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_row.dart';
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

class WeeklyChart extends ConsumerStatefulWidget {
  const WeeklyChart({
    super.key,
    required this.history,
    required this.dateKeys,
    required this.dayLabels,
    required this.isLoading,
    required this.currentUserId,
  });

  final WeeklyHistory? history;
  final List<String> dateKeys;
  final List<String> dayLabels;
  final bool isLoading;
  final String? currentUserId;

  @override
  ConsumerState<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends ConsumerState<WeeklyChart> {
  String? _selectedDate;

  void _toggleDay(int index) {
    if (index < 0 || index >= widget.dateKeys.length) return;
    final date = widget.dateKeys[index];
    setState(() => _selectedDate = _selectedDate == date ? null : date);
  }

  @override
  Widget build(BuildContext context) {
    final dateKeys = widget.dateKeys;
    final dayLabels = widget.dayLabels;
    final isLoading = widget.isLoading;
    final history = widget.history;

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
      subtitle: 'Tap a day to see that day\'s standings.',
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
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;
                            final spot = response?.spot;
                            if (spot == null) return;
                            _toggleDay(spot.touchedBarGroupIndex);
                          },
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
                                final selected = _selectedDate == dateKeys[i];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _toggleDay(i),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.skyBg
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.pill,
                                        ),
                                      ),
                                      child: Text(
                                        dayLabels[i],
                                        style: AppTextStyles.copy(
                                          size: 10,
                                          color: selected
                                              ? AppColors.skyText
                                              : AppColors.textMuted,
                                        ),
                                      ),
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
            if (_selectedDate != null)
              _DayStandings(
                date: _selectedDate!,
                currentUserId: widget.currentUserId,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayStandings extends ConsumerWidget {
  const _DayStandings({required this.date, required this.currentUserId});

  final String date;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standings = ref.watch(dailyStandingsProvider(date));

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 12),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Text(
            '${fullDayLabel(date).toUpperCase()} STANDINGS',
            style: AppTextStyles.fieldLabel(),
          ),
          const SizedBox(height: 6),
          standings.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Could not load this day.',
                style: AppTextStyles.copy(size: 12, color: AppColors.error),
              ),
            ),
            data: (entries) => _DayRows(
              entries: entries,
              currentUserId: currentUserId,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRows extends StatelessWidget {
  const _DayRows({required this.entries, required this.currentUserId});

  final List<LeaderboardEntry> entries;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty || entries.every((e) => e.totalBadMinutes == 0)) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('No usage recorded.', style: AppTextStyles.copy(size: 12)),
      );
    }

    final maxMinutes = entries.fold<double>(
      0,
      (m, e) => e.totalBadMinutes > m ? e.totalBadMinutes : m,
    );

    return Column(
      children: entries.asMap().entries.map((e) {
        final entry = e.value;
        final fraction = maxMinutes > 0
            ? (0.16 + 0.84 * (entry.totalBadMinutes / maxMinutes))
            : 0.16;
        return LeaderboardRow(
          index: e.key,
          entry: entry,
          isCurrentUser: entry.userId == currentUserId,
          widthFraction: fraction,
          totalEntries: entries.length,
        );
      }).toList(),
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
