import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/*
authentication.dart - handles signing in and whatnot
- sign up with email and password (also adds user to users collection in firestore)
- sign in with email and password
- sign out
*/

class Authentication {
  // Shows an error dialog in the center of the screen
  //TODO; verify errors are being shown and possibly update formatting
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String message,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            'Error',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white, letterSpacing: 0.5),
          ),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  static Future<FirebaseApp> initializeFirebase({
    required BuildContext context,
  }) async {
    FirebaseApp firebaseApp = await Firebase.initializeApp();
    return firebaseApp;
  }

  static Future<User?> signUpwithEmailAndPassword({
    required BuildContext context,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'username': username,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      // TODO: formatting of error code should be updated to fit the app when I do my graphic design shit
      if (e.code == 'weak-password') {
        await showErrorDialog(context: context, message: 'The password provided is too weak (must be at least 6 characters).'); 
      } else if (e.code == 'email-already-in-use') {
        await showErrorDialog(context: context, message: 'An account already exists for that email.');
      } else {
        await showErrorDialog(context: context, message: 'Auth error during sign up: ${e.message}');
      }
    } catch (e) {
      await showErrorDialog(context: context, message: 'Error occurred during sign up. Try again.');
    }
    return null;
  }

  static Future<User?> signInWithEmailAndPassword({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await showErrorDialog(context: context, message: 'No user found for that email.');
      } else if (e.code == 'wrong-password') {
        await showErrorDialog(context: context, message: 'Wrong password provided.');
      } else if (e.code == 'invalid-email') {
        await showErrorDialog(context: context, message: 'Invalid email address.');
      } else {
        await showErrorDialog(context: context, message: 'Incorrect email  and/or password. Try again.');
      }
    } catch (e) {
      await showErrorDialog(context: context, message: 'Error occurred during sign in. Try again.');
    }
    return null;
  }

  static Future<void> signOut({required BuildContext context}) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      await showErrorDialog(context: context, message: 'Error signing out. Try again.');
    }
  }
}