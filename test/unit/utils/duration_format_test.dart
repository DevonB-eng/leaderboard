import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/core/utils/duration_format.dart';

void main() {
  group('formatMinutes', () {
    test('formats sub-hour durations as minutes only', () {
      expect(formatMinutes(0), '0m');
      expect(formatMinutes(45), '45m');
    });

    test('formats hour-plus durations as hours and minutes', () {
      expect(formatMinutes(60), '1h 0m');
      expect(formatMinutes(125), '2h 5m');
    });

    test('rounds fractional minutes', () {
      expect(formatMinutes(30.4), '30m');
      expect(formatMinutes(30.6), '31m');
    });

    test('carries a minute rounded up to 60 into the next hour', () {
      expect(formatMinutes(59.6), '1h 0m');
    });
  });

  group('formatTimeAgo', () {
    final now = DateTime(2026, 9, 12, 15, 0);

    test('reports sub-minute ages as just now', () {
      expect(formatTimeAgo(now.subtract(const Duration(seconds: 30)), now: now),
          'just now');
    });

    test('reports minutes, then hours, then days', () {
      expect(formatTimeAgo(now.subtract(const Duration(minutes: 34)), now: now),
          '34m ago');
      expect(formatTimeAgo(now.subtract(const Duration(hours: 3)), now: now),
          '3h ago');
      expect(formatTimeAgo(now.subtract(const Duration(days: 2)), now: now),
          '2d ago');
    });

    test('treats a timestamp ahead of the clock as just now', () {
      // Server/device clock skew, which must not render as a negative age.
      expect(formatTimeAgo(now.add(const Duration(minutes: 5)), now: now),
          'just now');
    });

    test('compares absolute time across UTC and local timestamps', () {
      // Supabase returns UTC; the device clock is local.
      final utc = now.toUtc().subtract(const Duration(hours: 2));
      expect(formatTimeAgo(utc, now: now), '2h ago');
    });
  });

  group('dateKey', () {
    test('formats as YYYY-MM-DD with zero-padding', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('currentWeekDateKeys', () {
    test('runs Monday to Sunday of the week containing the given day', () {
      // 2026-09-16 is a Wednesday.
      expect(currentWeekDateKeys(now: DateTime(2026, 9, 16)), [
        '2026-09-14',
        '2026-09-15',
        '2026-09-16',
        '2026-09-17',
        '2026-09-18',
        '2026-09-19',
        '2026-09-20',
      ]);
    });

    test('starts on Monday even when that day is today', () {
      final keys = currentWeekDateKeys(now: DateTime(2026, 9, 14));
      expect(keys.first, '2026-09-14');
      expect(keys, hasLength(7));
    });

    test('returns 7 ascending, consecutive days starting on a Monday', () {
      final parsed = currentWeekDateKeys().map(DateTime.parse).toList();
      expect(parsed, hasLength(7));
      expect(parsed.first.weekday, DateTime.monday);
      for (var i = 1; i < parsed.length; i++) {
        expect(parsed[i].difference(parsed[i - 1]).inDays, 1);
      }
    });
  });

  group('fullDayLabel', () {
    test('names the weekday of a date key', () {
      expect(fullDayLabel('2026-09-14'), 'Monday');
      expect(fullDayLabel('2026-09-20'), 'Sunday');
    });
  });

  group('dayLabelsForDates', () {
    test('maps ISO date strings to weekday abbreviations', () {
      // 2026-01-05 is a Monday.
      expect(dayLabelsForDates(['2026-01-05']), ['Mon']);
      expect(dayLabelsForDates(['2026-01-05', '2026-01-11']), ['Mon', 'Sun']);
    });
  });
}
