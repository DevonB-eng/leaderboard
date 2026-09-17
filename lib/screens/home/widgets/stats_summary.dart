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
    // Averaged over the whole group — you included, and anyone who hasn't
    // reported today at zero — the same way the weekly chart averages each day.
    final groupTotal = entries.fold<double>(
      0,
      (sum, e) => sum + e.totalBadMinutes,
    );
    final groupAvg = entries.isNotEmpty ? groupTotal / entries.length : 0.0;
    final delta = myMinutes - groupAvg;
    final isUnder = delta < 0.5;
    // formatMinutes rounds to the minute, so a gap under half a minute would
    // read as "0m under"; treat it as level instead.
    final deltaLabel = delta.abs() < 0.5
        ? 'at group average'
        : '${formatMinutes(delta.abs())} ${isUnder ? 'under' : 'over'} group average';

    final sorted = [...entries]
      ..sort((a, b) => b.totalBadMinutes.compareTo(a.totalBadMinutes));
    final rank = myEntry == null
        ? null
        : sorted.indexWhere((e) => e.userId == currentUserId) + 1;

    return SectionCard(
      title: 'YOUR SCREENTIME',
      useHeroShadow: true,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMinutes(myMinutes), style: AppTextStyles.bigNumber()),
                const SizedBox(width: 12),
                // Flexible bounds the pill to the width left beside the hero
                // number, so a long label wraps instead of overflowing the card.
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isUnder ? AppColors.sageBg : AppColors.coralBg,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        deltaLabel,
                        style: AppTextStyles.pill(
                          color: isUnder ? AppColors.sageText : AppColors.coralText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(label: 'GROUP AVG', value: formatMinutes(groupAvg)),
                const SizedBox(width: 26),
                if (rank != null)
                  _Stat(label: 'YOUR RANK', value: '$rank of ${entries.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel()),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.body(size: 16)),
      ],
    );
  }
}
