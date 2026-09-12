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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('USERNAME', style: AppTextStyles.fieldLabel()),
          const SizedBox(height: 4),
          Text(
            (user?.userMetadata?['username'] as String?) ?? 'No username set',
            style: AppTextStyles.body(size: 16),
          ),
          const SizedBox(height: 16),
          Text('EMAIL', style: AppTextStyles.fieldLabel()),
          const SizedBox(height: 4),
          Text(
            user?.email ?? 'No email found',
            style: AppTextStyles.body(size: 16),
          ),
          const SizedBox(height: 20),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            onTap: () => _signOut(context, ref, auth),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.tan,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign out',
                    style: AppTextStyles.pill(color: AppColors.textSecondary),
                  ),
                ],
              ),
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
        title: Text('Sign out', style: AppTextStyles.title(size: 18)),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.copy(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No', style: AppTextStyles.body()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Yes',
              style: AppTextStyles.body(color: AppColors.coralText),
            ),
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
