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
            const Icon(Icons.group_off, size: 72, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Join a group to see the leaderboard!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onJoinPressed,
              icon: const Icon(Icons.group_add, size: 16),
              label: const Text('Join or create group'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
