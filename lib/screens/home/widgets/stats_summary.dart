import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/widgets/section_card.dart';

class StatsSummary extends StatelessWidget {
  const StatsSummary({
    super.key,
    required this.entries,
    required this.currentUserId,
  });

  final List<LeaderboardEntry> entries;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    LeaderboardEntry? myEntry;
    for (final entry in entries) {
      if (entry.userId == currentUserId) {
        myEntry = entry;
        break;
      }
    }

    final myMinutes = myEntry?.totalBadMinutes ?? 0.0;
    final otherEntries = entries
        .where((e) => e.userId != currentUserId)
        .toList();
    final otherTotal = otherEntries.fold<double>(
      0,
      (sum, e) => sum + e.totalBadMinutes,
    );
    final groupAvg = otherEntries.isNotEmpty
        ? otherTotal / otherEntries.length
        : 0.0;
    final delta = myMinutes - groupAvg;
    final deltaStr = delta >= 0
        ? '+${formatMinutes(delta)} above avg'
        : '-${formatMinutes(delta.abs())} below avg';
    final deltaColor = delta > 0 ? AppColors.error : AppColors.success;

    return SectionCard(
      title: 'TODAY\'S STATS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('You', style: AppTextStyles.body()),
                Text(
                  formatMinutes(myMinutes),
                  style: AppTextStyles.mono(color: AppColors.primaryBright),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Group Avg', style: AppTextStyles.body()),
                Text(
                  formatMinutes(groupAvg),
                  style: AppTextStyles.mono(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Divider(height: 1, color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'vs Average',
                  style: AppTextStyles.label(color: AppColors.textSecondary),
                ),
                Text(deltaStr, style: AppTextStyles.mono(color: deltaColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
