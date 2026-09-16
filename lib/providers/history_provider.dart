import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/leaderboard_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

final historyDateKeysProvider = Provider<List<String>>((ref) {
  return currentWeekDateKeys();
});

final historyProvider = FutureProvider<WeeklyHistory?>((ref) async {
  final user = ref.watch(currentUserProvider);
  final group = await ref.watch(groupProvider.future);
  if (user == null || group == null) return null;

  final dateKeys = ref.watch(historyDateKeysProvider);
  return ref
      .watch(leaderboardRepositoryProvider)
      .fetchWeeklyHistory(
        userId: user.id,
        memberIds: group.memberIds,
        dateKeys: dateKeys,
      );
});

/// The leaderboard re-totalled over the whole week rather than today alone.
///
/// Usernames, per-app breakdowns and freshness still come from the live daily
/// leaderboard; only the headline figure and the ordering become cumulative.
final weeklyStandingsProvider = FutureProvider<List<LeaderboardEntry>>((
  ref,
) async {
  final leaderboard = await ref.watch(leaderboardProvider.future);
  final entries = leaderboard?.entries ?? [];
  if (entries.isEmpty) return [];

  final dateKeys = ref.watch(historyDateKeysProvider);
  final totals = await ref
      .watch(leaderboardRepositoryProvider)
      .fetchWeeklyTotals(
        userIds: entries.map((e) => e.userId).toList(),
        dateKeys: dateKeys,
      );

  final weekly = entries
      .map(
        (e) => LeaderboardEntry(
          userId: e.userId,
          username: e.username,
          totalBadMinutes: totals[e.userId] ?? 0,
          badAppsBreakdown: e.badAppsBreakdown,
          lastUpdated: e.lastUpdated,
        ),
      )
      .toList();

  weekly.sort((a, b) => b.totalBadMinutes.compareTo(a.totalBadMinutes));
  return weekly;
});

/// Standings for a single past day, keyed by its date key.
final dailyStandingsProvider =
    FutureProvider.family<List<LeaderboardEntry>, String>((ref, date) async {
      final leaderboard = await ref.watch(leaderboardProvider.future);
      final entries = leaderboard?.entries ?? [];
      if (entries.isEmpty) return [];

      return ref
          .watch(leaderboardRepositoryProvider)
          .fetchDayStandings(
            usernamesByUserId: {
              for (final entry in entries) entry.userId: entry.username,
            },
            dateKey: date,
          );
    });
