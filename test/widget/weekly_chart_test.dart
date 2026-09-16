import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/providers/history_provider.dart';
import 'package:leaderboard/screens/home/widgets/weekly_chart.dart';

void main() {
  const dateKeys = [
    '2026-09-14',
    '2026-09-15',
    '2026-09-16',
    '2026-09-17',
    '2026-09-18',
    '2026-09-19',
    '2026-09-20',
  ];
  const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const mondayStandings = [
    LeaderboardEntry(
      userId: 'u1',
      username: 'alice',
      totalBadMinutes: 90,
      badAppsBreakdown: [AppBreakdown(appName: 'TikTok', minutes: 90)],
    ),
    LeaderboardEntry(
      userId: 'u2',
      username: 'bob',
      totalBadMinutes: 20,
      badAppsBreakdown: [],
    ),
  ];

  Widget wrap({required List<Override> overrides}) {
    const history = WeeklyHistory(
      personal: {'2026-09-14': 90},
      group: {'2026-09-14': 55},
      dateKeys: dateKeys,
    );

    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyChart(
              history: history,
              dateKeys: dateKeys,
              dayLabels: dayLabels,
              isLoading: false,
              currentUserId: 'u1',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('tapping a day opens that day\'s standings', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          dailyStandingsProvider(
            '2026-09-14',
          ).overrideWith((ref) async => mondayStandings),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alice'), findsNothing);

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    expect(find.text('MONDAY STANDINGS'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('20m'), findsOneWidget); // bob's figure for that day
  });

  testWidgets('tapping the open day closes it again', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          dailyStandingsProvider(
            '2026-09-14',
          ).overrideWith((ref) async => mondayStandings),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(find.text('alice'), findsOneWidget);

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('says so when a day has no recorded usage', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          dailyStandingsProvider('2026-09-17').overrideWith(
            (ref) async => const [
              LeaderboardEntry(
                userId: 'u1',
                username: 'alice',
                totalBadMinutes: 0,
                badAppsBreakdown: [],
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thu'));
    await tester.pumpAndSettle();

    expect(find.text('THURSDAY STANDINGS'), findsOneWidget);
    expect(find.text('No usage recorded.'), findsOneWidget);
  });
}
