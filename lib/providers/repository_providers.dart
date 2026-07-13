import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leaderboard/data/repositories/auth_repository.dart';
import 'package:leaderboard/data/repositories/group_repository.dart';
import 'package:leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:leaderboard/data/repositories/screentime_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository();
});

final screentimeRepositoryProvider = Provider<ScreentimeRepository>((ref) {
  return ScreentimeRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});
