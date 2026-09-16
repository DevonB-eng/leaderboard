import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/screens/home/widgets/leaderboard_table.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  const entries = [
    LeaderboardEntry(
      userId: 'u1',
      username: 'alice',
      totalBadMinutes: 120,
      badAppsBreakdown: [],
    ),
    LeaderboardEntry(
      userId: 'u2',
      username: 'bob',
      totalBadMinutes: 60,
      badAppsBreakdown: [],
    ),
  ];

  testWidgets('renders one row per entry, in the given order', (tester) async {
    await tester.pumpWidget(
      wrap(const LeaderboardTable(entries: entries, currentUserId: 'u2')),
    );

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('renders nothing but the section title for an empty entry list', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const LeaderboardTable(entries: [], currentUserId: 'u1')),
    );

    expect(find.text('CURRENT WEEKLY STANDINGS'), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });
}
