import 'package:flutter/material.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/widgets/app_header.dart';
import 'package:leaderboard/widgets/email_sign_in_button.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppHeader(title: 'LEADERBOARD'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: AppBorders.box,
                        borderRadius: AppBorders.radius,
                        color: AppColors.surface,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                            child: Text('SIGN IN', style: AppTextStyles.heading(size: 14)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Track your screen time.\nCompete with your friends.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const EmailSignInButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
