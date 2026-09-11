import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/repositories/auth_repository.dart';
import 'package:leaderboard/providers/repository_providers.dart';

class PersonalInfoSection extends ConsumerWidget {
  const PersonalInfoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final auth = ref.read(authRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USERNAME', style: AppTextStyles.label()),
                  Text(
                    (user?.userMetadata?['username'] as String?) ??
                        'No username set',
                    style: AppTextStyles.body(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.primary),
          Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 16,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EMAIL', style: AppTextStyles.label()),
                  Text(
                    user?.email ?? 'No email found',
                    style: AppTextStyles.body(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref, auth),
            icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
            label: Text(
              'SIGN OUT',
              style: AppTextStyles.label(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 0),
              side: const BorderSide(color: AppColors.primary, width: 1),
              shape: const RoundedRectangleBorder(
                borderRadius: AppBorders.radius,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AuthRepository auth,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.radius,
          side: AppBorders.thin,
        ),
        title: Text('SIGN OUT', style: AppTextStyles.heading()),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.label(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('NO', style: AppTextStyles.body()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('YES', style: AppTextStyles.body()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await auth.signOut(context: context);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
