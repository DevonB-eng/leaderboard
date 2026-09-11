import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.index,
    required this.entry,
    required this.isCurrentUser,
  });

  final int index;
  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final timeStr = formatMinutes(entry.totalBadMinutes);
    final badAppsData = entry.badAppsBreakdown;

    return Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            leading: SizedBox(
              width: 32,
              child: Text(
                '${index + 1}.',
                style: AppTextStyles.display(
                  size: 22,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.username,
                    style: AppTextStyles.body(
                      color: isCurrentUser
                          ? AppColors.primaryBright
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: AppTextStyles.mono(color: AppColors.textPrimary),
                ),
              ],
            ),
            trailing: badAppsData.isNotEmpty
                ? const Icon(
                    Icons.expand_more,
                    color: AppColors.primaryLight,
                    size: 18,
                  )
                : const SizedBox(width: 18),
            children: [
              if (badAppsData.isNotEmpty)
                Container(
                  color: AppColors.surfaceRaised,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('APP BREAKDOWN', style: AppTextStyles.label()),
                      const SizedBox(height: AppSpacing.xs),
                      ...badAppsData.map((app) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.phone_android,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  app.appName,
                                  style: AppTextStyles.body(
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                formatMinutes(app.minutes),
                                style: AppTextStyles.mono(
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.primary),
      ],
    );
  }
}
