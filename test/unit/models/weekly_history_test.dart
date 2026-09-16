import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/history_day.dart';

void main() {
  group('WeeklyHistory.fromHistoryRows', () {
    const dateKeys = ['2026-09-14', '2026-09-15', '2026-09-16'];

    test('counts a member with no row as zero rather than leaving them out', () {
      // You logged 7m; the only other member never synced that day.
      final history = WeeklyHistory.fromHistoryRows(
        rows: [
          {'user_id': 'me', 'date_key': '2026-09-15', 'total_bad_minutes': 7},
        ],
        userId: 'me',
        memberCount: 2,
        dateKeys: dateKeys,
      );

      expect(history.personal['2026-09-15'], 7.0);
      expect(history.group['2026-09-15'], 3.5);
    });

    test('sums every member for each day before averaging', () {
      final history = WeeklyHistory.fromHistoryRows(
        rows: [
          {'user_id': 'me', 'date_key': '2026-09-14', 'total_bad_minutes': 30},
          {'user_id': 'u2', 'date_key': '2026-09-14', 'total_bad_minutes': 90},
          {'user_id': 'u3', 'date_key': '2026-09-14', 'total_bad_minutes': 0},
          {'user_id': 'u2', 'date_key': '2026-09-15', 'total_bad_minutes': 60},
        ],
        userId: 'me',
        memberCount: 3,
        dateKeys: dateKeys,
      );

      expect(history.personal, {
        '2026-09-14': 30.0,
        '2026-09-15': 0.0,
        '2026-09-16': 0.0,
      });
      expect(history.group, {
        '2026-09-14': 40.0,
        '2026-09-15': 20.0,
        '2026-09-16': 0.0,
      });
    });

    test('is all zeros for a group with no members', () {
      final history = WeeklyHistory.fromHistoryRows(
        rows: const [],
        userId: 'me',
        memberCount: 0,
        dateKeys: dateKeys,
      );

      expect(history.group.values, everyElement(0.0));
      expect(history.personal.values, everyElement(0.0));
    });
  });
}
