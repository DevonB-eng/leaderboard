import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/screens/home/widgets/stats_summary.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('shows the hero number, rank, and an over-average pill', (
    tester,
  ) async {
    const entries = [
      LeaderboardEntry(
        userId: 'me',
        username: 'me',
        totalBadMinutes: 120,
        badAppsBreakdown: [],
      ),
      LeaderboardEntry(
        userId: 'other',
        username: 'other',
        totalBadMinutes: 60,
        badAppsBreakdown: [],
      ),
    ];

    await tester.pumpWidget(
      wrap(const StatsSummary(entries: entries, currentUserId: 'me')),
    );

    expect(find.text('2h 0m'), findsOneWidget); // my minutes, the hero number
    expect(find.text('1h 0m over'), findsOneWidget); // delta pill
    expect(find.text('1 of 2'), findsOneWidget); // rank
  });

  testWidgets('shows an under-average pill when the user is below the average', (
    tester,
  ) async {
    const entries = [
      LeaderboardEntry(
        userId: 'me',
        username: 'me',
        totalBadMinutes: 30,
        badAppsBreakdown: [],
      ),
      LeaderboardEntry(
        userId: 'other',
        username: 'other',
        totalBadMinutes: 90,
        badAppsBreakdown: [],
      ),
    ];

    await tester.pumpWidget(
      wrap(const StatsSummary(entries: entries, currentUserId: 'me')),
    );

    expect(find.text('1h 0m under'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets(
    'treats a missing current-user entry as zero minutes and hides the rank',
    (tester) async {
      const entries = [
        LeaderboardEntry(
          userId: 'other',
          username: 'other',
          totalBadMinutes: 60,
          badAppsBreakdown: [],
        ),
      ];

      await tester.pumpWidget(
        wrap(const StatsSummary(entries: entries, currentUserId: 'me')),
      );

      expect(find.text('0m'), findsOneWidget); // hero number for the absent user
      expect(find.textContaining(' of '), findsNothing); // no rank shown
    },
  );

  testWidgets('group average is zero when there are no other members', (
    tester,
  ) async {
    const entries = [
      LeaderboardEntry(
        userId: 'me',
        username: 'me',
        totalBadMinutes: 45,
        badAppsBreakdown: [],
      ),
    ];

    await tester.pumpWidget(
      wrap(const StatsSummary(entries: entries, currentUserId: 'me')),
    );

    expect(find.text('45m'), findsOneWidget); // hero number
    expect(find.text('0m'), findsOneWidget); // group avg stat
    expect(find.text('45m over'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
  });
}
