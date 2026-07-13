import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_row.dart';

class LeaderboardTable extends StatelessWidget {
  const LeaderboardTable({
    super.key,
    required this.entries,
    required this.currentUserId,
  });

  final List<LeaderboardEntry> entries;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: AppBorders.box,
        borderRadius: AppBorders.radius,
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text('GROUP LEADERBOARD', style: AppTextStyles.heading()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text('RANK', style: AppTextStyles.label())),
                Expanded(child: Text('USER', style: AppTextStyles.label())),
                Text('TIME TODAY', style: AppTextStyles.label()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.primaryLight),
          ...entries.asMap().entries.map((e) {
            final entry = e.value;
            return LeaderboardRow(
              index: e.key,
              entry: entry,
              isCurrentUser: entry.userId == currentUserId,
            );
          }),
        ],
      ),
    );
  }
}
