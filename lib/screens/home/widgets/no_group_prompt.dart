import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';

class NoGroupPrompt extends StatelessWidget {
  const NoGroupPrompt({super.key, required this.onJoinPressed});

  final VoidCallback onJoinPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.group_off, size: 80, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Join a group to see the leaderboard!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onJoinPressed,
              icon: const Icon(Icons.group_add),
              label: Text(
                'JOIN OR CREATE GROUP',
                style: AppTextStyles.label(color: AppColors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                side: const BorderSide(width: 1),
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorders.radius,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
