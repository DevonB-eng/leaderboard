import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';

/// Standings tint by position: the worst three stand out in warm colours, the
/// middle of the pack is neutral, and last place — the least screentime — is
/// sage, which wins over every other position (so a group of three reads
/// red, orange, sage).
Color rankTint(int rank, int total) {
  if (rank >= total) return AppColors.sageBg;
  return switch (rank) {
    1 => AppColors.coralBg,
    2 => AppColors.orangeBg,
    3 => AppColors.yellowBg,
    _ => AppColors.neutralBg,
  };
}

class LeaderboardRow extends StatefulWidget {
  const LeaderboardRow({
    super.key,
    required this.index,
    required this.entry,
    required this.isCurrentUser,
    required this.widthFraction,
    required this.totalEntries,
  });

  final int index;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final double widthFraction;
  final int totalEntries;

  @override
  State<LeaderboardRow> createState() => _LeaderboardRowState();
}

class _LeaderboardRowState extends State<LeaderboardRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final timeStr = formatMinutes(entry.totalBadMinutes);
    final badAppsData = entry.badAppsBreakdown;
    final hasBreakdown = badAppsData.isNotEmpty;

    // Background syncs are scheduled by the OS, so a member's figure can lag by
    // anywhere from minutes to hours. Stating its age keeps a stale number from
    // reading as a wrong one, and distinguishes "reported no usage" from
    // "hasn't reported".
    final reportedAt = entry.lastUpdatedAt;
    final freshness = reportedAt == null
        ? 'no data'
        : 'updated ${formatTimeAgo(reportedAt)}';

    // Position drives the tint even for the current user — the sky badge below
    // is what marks "you", so the standings keep one consistent colour order.
    final Color tint = rankTint(widget.index + 1, widget.totalEntries);
    final Color badgeColor = widget.isCurrentUser
        ? AppColors.sky
        : AppColors.surface;
    final Color badgeTextColor = widget.isCurrentUser
        ? AppColors.skyDark
        : AppColors.ink;
    final Color chevronColor = widget.isCurrentUser
        ? AppColors.skyText
        : AppColors.textMuted;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.row),
          child: InkWell(
            onTap: hasBreakdown
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.widthFraction.clamp(0.0, 1.0),
                    child: Container(color: tint),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.index + 1}',
                          style: AppTextStyles.body(
                            size: 12,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.username,
                              style: AppTextStyles.body(),
                            ),
                            Text(
                              freshness,
                              style: AppTextStyles.copy(
                                size: 11,
                                height: 1.3,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(timeStr, style: AppTextStyles.body()),
                      if (hasBreakdown) ...[
                        const SizedBox(width: 8),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 15,
                          color: chevronColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded && hasBreakdown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: badAppsData.map((app) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.5),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.skyBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          app.appName,
                          style: AppTextStyles.copy(
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        formatMinutes(app.minutes),
                        style: AppTextStyles.copy(
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
