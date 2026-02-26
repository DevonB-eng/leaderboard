import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';

import 'package:leaderboard/screens/sign_in_screen.dart';
import 'package:leaderboard/screens/home_screen.dart';
import 'package:leaderboard/background_sync.dart';

/*
main.dart - the main entry point for the app
- initializes firebase and forwards user to appropriate screen based on authentication state
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize workmanager with the top-level callback dispatcher.
  // isInDebugMode: true prints workmanager logs to the console during dev —
  // remember to set this to false before releasing.
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Register the periodic background sync task.
  // - uniqueName: used to deduplicate — re-registering with the same name
  //   replaces the existing task rather than creating a duplicate.
  // - taskName: passed into the callback so it knows what to run.
  // - frequency: 30 minutes. Note that Android enforces a minimum of 15 min.
  //   iOS honors this as a hint but the OS decides actual timing.
  // - existingWorkPolicy.replace: if the task is already scheduled,
  //   replace it with this fresh registration on every app launch.
  await Workmanager().registerPeriodicTask(
    kSyncTaskName,           // uniqueName
    kSyncTaskName,           // taskName passed to callback
    frequency: const Duration(minutes: 30),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(
      networkType: NetworkType.connected, // only run if online
    ),
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