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
          title: Text(
            isSignUp ? 'Sign up with email' : 'Sign in with email',
            style: AppTextStyles.title(size: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSignUp) ...[
                TextField(
                  controller: nameController,
                  style: AppTextStyles.body(),
                  decoration: const InputDecoration(labelText: 'Username'),
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: emailController,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                style: AppTextStyles.body(),
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setDialogState(() => isSignUp = !isSignUp),
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Sign up",
                  style: AppTextStyles.copy(size: 12, color: AppColors.skyText),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
              child: Text(isSignUp ? 'Sign up' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isSigningIn
        ? const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _showEmailPasswordDialog,
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Sign in with email'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          );
  }
}
