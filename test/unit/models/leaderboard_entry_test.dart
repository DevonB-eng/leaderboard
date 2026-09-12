import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/models/leaderboard_entry.dart';

void main() {
  group('AppBreakdown.fromJson', () {
    test('parses appName and minutes', () {
      final breakdown = AppBreakdown.fromJson({
        'appName': 'Instagram',
        'minutes': 42.5,
      });
      expect(breakdown.appName, 'Instagram');
      expect(breakdown.minutes, 42.5);
    });

    test('defaults appName to Unknown and minutes to 0 when missing', () {
      final breakdown = AppBreakdown.fromJson({});
      expect(breakdown.appName, 'Unknown');
      expect(breakdown.minutes, 0);
    });
  });

  group('LeaderboardEntry.fromJson', () {
    test('parses a full entry including breakdown', () {
      final entry = LeaderboardEntry.fromJson({
        'uid': 'u1',
        'username': 'devon',
        'totalBadMinutes': 90,
        'badAppsBreakdown': [
          {'appName': 'TikTok', 'minutes': 90},
        ],
        'lastUpdated': '2026-01-05T00:00:00Z',
      });

      expect(entry.userId, 'u1');
      expect(entry.username, 'devon');
      expect(entry.totalBadMinutes, 90);
      expect(entry.badAppsBreakdown, hasLength(1));
      expect(entry.badAppsBreakdown.first.appName, 'TikTok');
      expect(entry.lastUpdated, '2026-01-05T00:00:00Z');
    });

    test('defaults username to Anonymous and zero-fills missing data', () {
      final entry = LeaderboardEntry.fromJson({'uid': 'u1'});
      expect(entry.username, 'Anonymous');
      expect(entry.totalBadMinutes, 0);
      expect(entry.badAppsBreakdown, isEmpty);
      expect(entry.lastUpdated, isNull);
    });

    test('defaults userId to empty string when uid missing', () {
      final entry = LeaderboardEntry.fromJson({});
      expect(entry.userId, '');
    });
  });

  group('Leaderboard.fromJson', () {
    test('parses entries and preserves the passed-in groupId', () {
      final leaderboard = Leaderboard.fromJson('g1', {
        'entries': [
          {'uid': 'u1', 'username': 'a', 'totalBadMinutes': 10},
          {'uid': 'u2', 'username': 'b', 'totalBadMinutes': 20},
        ],
        'last_updated': '2026-01-05T00:00:00Z',
      });

      expect(leaderboard.groupId, 'g1');
      expect(leaderboard.entries, hasLength(2));
      expect(leaderboard.lastUpdated, '2026-01-05T00:00:00Z');
    });

    test('defaults entries to an empty list when missing', () {
      final leaderboard = Leaderboard.fromJson('g1', {});
      expect(leaderboard.entries, isEmpty);
    });
  });
}
