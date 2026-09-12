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

  group('dateKey', () {
    test('formats as YYYY-MM-DD with zero-padding', () {
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('lastSevenDateKeys', () {
    test('returns 7 ascending, consecutive date keys ending today', () {
      final keys = lastSevenDateKeys();
      expect(keys, hasLength(7));
      expect(keys.last, dateKey(DateTime.now()));

      final parsed = keys.map(DateTime.parse).toList();
      for (var i = 1; i < parsed.length; i++) {
        expect(parsed[i].difference(parsed[i - 1]).inDays, 1);
      }
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
