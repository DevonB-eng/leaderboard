import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/widgets/password_dialog.dart';

class GroupJoinSection extends ConsumerWidget {
  const GroupJoinSection({super.key, required this.onGroupChanged});

  final VoidCallback onGroupChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => showJoinGroupDialog(
              context: context,
              ref: ref,
              onJoined: onGroupChanged,
            ),
            icon: const Icon(Icons.group_add, size: 16),
            label: Text('JOIN GROUP', style: AppTextStyles.body()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              side: const BorderSide(color: AppColors.primaryLight, width: 1),
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: AppBorders.radius,
                side: AppBorders.thin,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            onPressed: () => showCreateGroupDialog(
              context: context,
              ref: ref,
              onCreated: onGroupChanged,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text('CREATE GROUP', style: AppTextStyles.body()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 0),
              side: const BorderSide(color: AppColors.primaryLight, width: 1),
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppBorders.radius),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }
}
