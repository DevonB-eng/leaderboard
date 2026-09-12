import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';

class LeaderboardRow extends StatefulWidget {
  const LeaderboardRow({
    super.key,
    required this.index,
    required this.entry,
    required this.isCurrentUser,
    required this.widthFraction,
    required this.isAboveAverage,
  });

  final int index;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
  final double widthFraction;
  final bool isAboveAverage;

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

    final Color tint = widget.isCurrentUser
        ? AppColors.skyBg
        : widget.isAboveAverage
            ? AppColors.coralBg
            : AppColors.sageBg;
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
                        child: Text(entry.username, style: AppTextStyles.body()),
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
