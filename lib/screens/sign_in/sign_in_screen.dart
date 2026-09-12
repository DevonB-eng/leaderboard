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
            const AppHeader(title: 'Leaderboard'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        boxShadow: AppShadows.hero,
                      ),
                      child: Text(
                        'Track your screen time.\nCompete with your friends.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          size: 15,
                          color: AppColors.textMuted,
                        ),
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
