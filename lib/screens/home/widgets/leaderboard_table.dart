import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_row.dart';
import 'package:leaderboard/widgets/section_card.dart';

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
    return SectionCard(
      title: 'GROUP LEADERBOARD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text('RANK', style: AppTextStyles.label()),
                ),
                Expanded(child: Text('USER', style: AppTextStyles.label())),
                Text('TIME TODAY', style: AppTextStyles.label()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.primary),
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
