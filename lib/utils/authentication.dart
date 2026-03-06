import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:leaderboard/assets/design.dart';

/*
authentication.dart - handles signing in and whatnot
- sign up with email and password (also adds user to users collection in firestore)
- sign in with email and password
- sign out
*/

class Authentication {
  // Shows an error dialog in the center of the screen
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String message,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorders.radius,
            side: const BorderSide(color: AppColors.error, width: 1.0),
          ),
          title: Text('ERROR', style: AppTextStyles.heading(color: AppColors.error)),
          content: Text(message, style: AppTextStyles.body()),
          actions: [
            TextButton(
              child: Text('OK', style: AppTextStyles.body(color: AppColors.error)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
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
        await credential.user!.updateDisplayName(username);
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
        await showErrorDialog(context: context, message: 'Incorrect email and/or password. Try again.');
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