import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

final historyDateKeysProvider = Provider<List<String>>((ref) {
  return lastSevenDateKeys();
});

final historyProvider = FutureProvider<WeeklyHistory?>((ref) async {
  final user = ref.watch(currentUserProvider);
  final groupId = await ref.watch(groupIdProvider.future);
  if (user == null || groupId == null) return null;

  final dateKeys = ref.watch(historyDateKeysProvider);
  return ref.watch(leaderboardRepositoryProvider).fetchWeeklyHistory(
        userId: user.id,
        groupId: groupId,
        dateKeys: dateKeys,
      );
});
