import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/providers/repository_providers.dart';

class EmailSignInButton extends ConsumerStatefulWidget {
  const EmailSignInButton({super.key});

  @override
  ConsumerState<EmailSignInButton> createState() => _EmailSignInButtonState();
}

class _EmailSignInButtonState extends ConsumerState<EmailSignInButton> {
  bool _isSigningIn = false;

  void _showEmailPasswordDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var isSignUp = false;
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorders.radius,
            side: AppBorders.thin,
          ),
          title: Text(
            isSignUp ? 'Sign Up with Email' : 'Sign In with Email',
            style: AppTextStyles.heading(),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSignUp) ...[
                TextField(
                  controller: nameController,
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: emailController,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setDialogState(() => isSignUp = !isSignUp),
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign In'
                      : 'Don\'t have an account? Sign Up',
                  style: AppTextStyles.label(color: AppColors.primaryLight),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: AppTextStyles.body()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
              onPressed: () async {
                if (isSignUp && nameController.text.trim().isEmpty) {
                  await ref
                      .read(authRepositoryProvider)
                      .showErrorDialog(
                        context: dialogContext,
                        message: 'Please enter a username.',
                      );
                  return;
                }

                Navigator.pop(dialogContext);
                setState(() => _isSigningIn = true);

                try {
                  final auth = ref.read(authRepositoryProvider);
                  if (isSignUp) {
                    await auth.signUpWithEmailAndPassword(
                      context: scaffoldContext,
                      username: nameController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );
                  } else {
                    await auth.signInWithEmailAndPassword(
                      context: scaffoldContext,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSigningIn = false);
                }
              },
              child: Text(
                isSignUp ? 'Sign Up' : 'Sign In',
                style: AppTextStyles.body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: _isSigningIn
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryBright,
              ),
            )
          : ElevatedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                side: const BorderSide(color: AppColors.primaryLight, width: 1),
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppBorders.radius,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              onPressed: _showEmailPasswordDialog,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email, size: 35),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Sign in with Email',
                        style: AppTextStyles.body(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
