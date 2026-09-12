import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/providers/repository_providers.dart';
import 'package:leaderboard/screens/home/home_screen.dart';
import 'package:leaderboard/screens/sign_in/sign_in_screen.dart';

class AppUsageApp extends ConsumerWidget {
  const AppUsageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: authState.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const SignInScreen(),
        data: (state) {
          final session =
              state.session ?? ref.read(authRepositoryProvider).currentSession;
          if (session != null) {
            return const HomeScreen();
          }
          return const SignInScreen();
        },
      ),
    );
  }
}
