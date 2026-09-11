import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/supabase/supabase_client.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> showErrorDialog({
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
          title: Text(
            'ERROR',
            style: AppTextStyles.heading(color: AppColors.error),
          ),
          content: Text(message, style: AppTextStyles.body()),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: AppTextStyles.body(color: AppColors.error),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<User?> signUpWithEmailAndPassword({
    required BuildContext context,
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      final user = response.user;

      if (user != null) {
        try {
          await _client.from('users').upsert({
            'id': user.id,
            'username': username,
            'email': email,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {
          // Auth account may already be created even if profile write fails.
        }
      }

      return user;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') ||
          msg.contains('email rate limit exceeded')) {
        await showErrorDialog(
          context: context,
          message:
              'Too many signup attempts in a short time. Wait a minute and try again.',
        );
      } else if (msg.contains('password')) {
        await showErrorDialog(
          context: context,
          message:
              'The password provided is too weak (must be at least 6 characters).',
        );
      } else if (msg.contains('already')) {
        await showErrorDialog(
          context: context,
          message: 'An account already exists for that email.',
        );
      } else {
        await showErrorDialog(
          context: context,
          message: 'Auth error during sign up: ${e.message}',
        );
      }
    } catch (_) {
      await showErrorDialog(
        context: context,
        message: 'Error occurred during sign up. Try again.',
      );
    }
    return null;
  }

  Future<User?> signInWithEmailAndPassword({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('email not confirmed')) {
        await showErrorDialog(
          context: context,
          message: 'Please verify your email first, then sign in.',
        );
      } else if (msg.contains('rate limit')) {
        await showErrorDialog(
          context: context,
          message: 'Too many login attempts. Please wait and try again.',
        );
      } else if (msg.contains('invalid login credentials') ||
          msg.contains('invalid')) {
        await showErrorDialog(
          context: context,
          message: 'Incorrect email and/or password.',
        );
      } else {
        await showErrorDialog(
          context: context,
          message: 'Auth error during sign in: ${e.message}',
        );
      }
    } catch (_) {
      await showErrorDialog(
        context: context,
        message: 'Error occurred during sign in. Try again.',
      );
    }
    return null;
  }

  Future<void> signOut({required BuildContext context}) async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      await showErrorDialog(
        context: context,
        message: 'Error signing out. Try again.',
      );
    }
  }
}
