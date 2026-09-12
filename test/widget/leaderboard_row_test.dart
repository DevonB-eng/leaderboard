import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          isAboveAverage: false,
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
          isAboveAverage: false,
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
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
          isAboveAverage: false,
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
}
