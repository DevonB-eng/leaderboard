import 'package:flutter/material.dart';

import 'package:leaderboard/utils/authentication.dart';
import 'package:leaderboard/assets/design.dart';

/*
email_sign_in_button.dart - the button that users click to sign in with email
- when clicked, shows a dialog where users can enter their email and password to sign in or sign up
- also has a loading state while signing in which is super pimp
*/

class EmailSignInButton extends StatefulWidget {
  @override
  _EmailSignInButtonState createState() => _EmailSignInButtonState();
}

class _EmailSignInButtonState extends State<EmailSignInButton> {
  bool _isSigningIn = false;

  void _showEmailPasswordDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    bool isSignUp = false;

    // Capture scaffold context here, before the dialog opens
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
          title: Text(isSignUp ? 'Sign Up with Email' : 'Sign In with Email', 
          style: AppTextStyles.heading()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSignUp) ...[
                TextField(
                  controller: nameController,
                  style: AppTextStyles.body(),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                ),
                SizedBox(height: 16),
              ],
              TextField(
                controller: emailController,
                style: AppTextStyles.body(),
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
                style: AppTextStyles.body(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    isSignUp = !isSignUp;
                  });
                },
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign In'
                      : 'Don\'t have an account? Sign Up',
                  style: AppTextStyles.label(),
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
                // Validate username before doing anything
                if (isSignUp && nameController.text.trim().isEmpty) {
                  await Authentication.showErrorDialog(
                    context: dialogContext,
                    message: 'Please enter a username.',
                  );
                  return;
                }

                // Close dialog first, then start loading
                Navigator.pop(dialogContext);
                setState(() {
                  _isSigningIn = true;
                });

                try {
                  if (isSignUp) {
                    await Authentication.signUpwithEmailAndPassword(
                      context: scaffoldContext,
                      username: nameController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );
                  } else {
                    await Authentication.signInWithEmailAndPassword(
                      context: scaffoldContext,
                      email: emailController.text.trim(),
                      password: passwordController.text,
                    );
                  }
                } finally {
                  // finally ensures _isSigningIn is ALWAYS set to false
                  // even if an unexpected exception slips through
                  setState(() {
                    _isSigningIn = false;
                  });
                }
              },
              child: Text(isSignUp ? 'Sign Up' : 'Sign In', style: AppTextStyles.body(),),
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
          ? CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBright),
            )
          : ElevatedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0), // add this
                side: const BorderSide(color: AppColors.primaryLight, width: 1),
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppBorders.radius),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              onPressed: _showEmailPasswordDialog,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.email, size: 35),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Sign in with Email',
                        style: AppTextStyles.body()
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}