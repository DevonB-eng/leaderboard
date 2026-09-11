import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.trailing,
    this.navButton,
  });

  final String title;
  final Widget? trailing;
  final Widget? navButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(color: AppColors.surface),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          if (navButton != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: navButton,
            ),
        ],
      ),
    );
  }
}
