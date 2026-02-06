import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'package:leaderboard/screens/sign_in_screen.dart';
import 'package:leaderboard/screens/home_screen.dart';

/*
main.dart - the main entry point for the app
- initializes firebase and forwards user to appropriate screen based on authentication state
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AppUsageApp());
}

class AppUsageApp extends StatelessWidget {
  const AppUsageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Do I want this here? 
      theme: ThemeData(primarySwatch: Colors.green),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) { // Route User to home screen or to sign in screen based on authentication state
            return const HomeScreen();
          }
          return SignInScreen();
        },
      ),
    );
  }
}