import 'package:flutter/material.dart';

import 'package:leaderboard/res/custom_colors.dart';
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
      backgroundColor: CustomColors.firebaseNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      'Leaderboard',
                      style: TextStyle(
                        color: CustomColors.firebaseYellow,
                        fontSize: 40,
                      ),
                    ),
                    Text(
                      'Sign In',
                      style: TextStyle(
                        color: CustomColors.firebaseOrange,
                        fontSize: 40,
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder(
                future: Authentication.initializeFirebase(context: context),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error initializing Firebase');
                  } else if (snapshot.connectionState == ConnectionState.done) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmailSignInButton() // the holy sign in button. I can add more here later
                      ],
                    );
                  }
                  return CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CustomColors.firebaseOrange,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

