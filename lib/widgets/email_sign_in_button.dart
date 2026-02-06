import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:leaderboard/utils/authentication.dart';
//import 'package:leaderboard/screens/user_info_screen.dart';

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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isSignUp ? 'Sign Up with Email' : 'Sign In with Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only show username field during sign up
              if (isSignUp) ...[
                TextField(
                  controller: nameController,
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
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: passwordController,
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
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                setState(() {
                  _isSigningIn = true;
                });

                User? user;

                if (isSignUp) {
                  // Only validate username during sign up
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a username')),
                    );
                    setState(() {
                      _isSigningIn = false;
                    });
                    return;
                  }
                  user = await Authentication.signUpwithEmailAndPassword(
                    context: context,
                    username: nameController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                } else {
                  // Sign in flow should not require a username
                  user = await Authentication.signInWithEmailAndPassword(
                    context: context,
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                }

                setState(() {
                  _isSigningIn = false;
                });
              },
              child: Text(isSignUp ? 'Sign Up' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), 
      child: _isSigningIn
          ? CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : OutlinedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),
              onPressed: _showEmailPasswordDialog,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.email, size: 35, color: Colors.black54),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        'Sign in with Email',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}