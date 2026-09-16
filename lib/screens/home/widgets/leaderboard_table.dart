import 'package:flutter/material.dart';

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
    final maxMinutes = entries.fold<double>(
      0,
      (m, e) => e.totalBadMinutes > m ? e.totalBadMinutes : m,
    );

    return SectionCard(
      title: 'CURRENT WEEKLY STANDINGS',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
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
        ),
      ),
    );
  }
}
