import 'package:flutter/material.dart';

import 'package:leaderboard/assets/design.dart';
import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/widgets/email_sign_in_button.dart';

/*
sign_in_screen.dart - the screen that users see when they are not authenticated
- has a button to sign in with email (maybe add some other authentication but idk...)
*/

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ===== header banner (mirrors home_screen _buildHeader) =====
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text('LEADERBOARD', textAlign: TextAlign.center, style: AppTextStyles.display(),
              ),
            ),

            // ===== body =====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ===== title card =====
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
                                  top: Radius.circular(4)),
                            ),
                            child: Text(
                              'SIGN IN',
                              style: AppTextStyles.heading(size: 14),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Track your screen time.\nCompete with your friends.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ===== sign in button / loading =====
                    FutureBuilder(
                      future:
                          Authentication.initializeFirebase(context: context),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Error initializing Firebase',
                            style: AppTextStyles.body(color: AppColors.error),
                            textAlign: TextAlign.center,
                          );
                        } else if (snapshot.connectionState ==
                            ConnectionState.done) {
                          return EmailSignInButton();
                        }
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
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