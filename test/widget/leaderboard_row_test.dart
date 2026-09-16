import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/core/theme/app_theme.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_row.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('shows rank, username, and formatted time', (tester) async {
    const entry = LeaderboardEntry(
      userId: 'u1',
      username: 'devon',
      totalBadMinutes: 125,
      badAppsBreakdown: [],
    );

    await tester.pumpWidget(
      wrap(
        const LeaderboardRow(
          index: 0,
          entry: entry,
          isCurrentUser: false,
          widthFraction: 1.0,
          totalEntries: 3,
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('devon'), findsOneWidget);
    expect(find.text('2h 5m'), findsOneWidget);
  });

  testWidgets('hides the expand arrow when there is no app breakdown', (
    tester,
  ) async {
    const entry = LeaderboardEntry(
      userId: 'u1',
      username: 'devon',
      totalBadMinutes: 0,
      badAppsBreakdown: [],
    );

    await tester.pumpWidget(
      wrap(
        const LeaderboardRow(
          index: 0,
          entry: entry,
          isCurrentUser: false,
          widthFraction: 0.16,
          totalEntries: 3,
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('labels a member who has not reported today', (tester) async {
    // A null lastUpdated means no figure is known, not that the member used
    // nothing — the row must not let 0m read as a real measurement.
    const entry = LeaderboardEntry(
      userId: 'u1',
      username: 'devon',
      totalBadMinutes: 0,
      badAppsBreakdown: [],
    );

    await tester.pumpWidget(
      wrap(
        const LeaderboardRow(
          index: 0,
          entry: entry,
          isCurrentUser: false,
          widthFraction: 0.16,
          totalEntries: 3,
        ),
      ),
    );

    expect(find.text('no data'), findsOneWidget);
  });

  testWidgets('shows how stale a reported figure is', (tester) async {
    final entry = LeaderboardEntry(
      userId: 'u1',
      username: 'devon',
      totalBadMinutes: 30,
      badAppsBreakdown: const [],
      lastUpdated: DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
    );

    await tester.pumpWidget(
      wrap(
        LeaderboardRow(
          index: 0,
          entry: entry,
          isCurrentUser: false,
          widthFraction: 0.5,
          totalEntries: 3,
        ),
      ),
    );

    expect(find.text('updated 3h ago'), findsOneWidget);
  });

  testWidgets('expanding reveals the per-app breakdown', (tester) async {
    const entry = LeaderboardEntry(
      userId: 'u1',
      username: 'devon',
      totalBadMinutes: 90,
      badAppsBreakdown: [
        AppBreakdown(appName: 'TikTok', minutes: 60),
        AppBreakdown(appName: 'Instagram', minutes: 30),
      ],
    );

    await tester.pumpWidget(
      wrap(
        const LeaderboardRow(
          index: 2,
          entry: entry,
          isCurrentUser: false,
          widthFraction: 0.6,
          totalEntries: 3,
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.text('TikTok'), findsNothing);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
  });

  group('rankTint', () {
    test('runs red, orange, yellow, then neutral down the table', () {
      expect(rankTint(1, 6), AppColors.coralBg);
      expect(rankTint(2, 6), AppColors.orangeBg);
      expect(rankTint(3, 6), AppColors.yellowBg);
      expect(rankTint(4, 6), AppColors.neutralBg);
      expect(rankTint(5, 6), AppColors.neutralBg);
      expect(rankTint(6, 6), AppColors.sageBg);
    });

    test('gives last place sage even when it would be a top-three colour', () {
      expect(rankTint(3, 3), AppColors.sageBg);
      expect(rankTint(2, 2), AppColors.sageBg);
      expect(rankTint(1, 1), AppColors.sageBg);
    });
  });
}
