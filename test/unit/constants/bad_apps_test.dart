import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/core/constants/bad_apps.dart';

void main() {
  group('badApps', () {
    test('maps every package name to a non-empty display name', () {
      for (final entry in badApps.entries) {
        expect(entry.key, isNotEmpty);
        expect(entry.value, isNotEmpty);
      }
    });
  });

  group('badAppDisplayNames', () {
    test('de-duplicates multiple packages sharing a display name', () {
      // Several browser packages (Chrome, Firefox, Edge, ...) all map to 'Browser'.
      final browserPackages = badApps.entries
          .where((e) => e.value == 'Browser')
          .length;
      expect(browserPackages, greaterThan(1));

      final browserOccurrences = badAppDisplayNames
          .where((name) => name == 'Browser')
          .length;
      expect(browserOccurrences, 1);
    });

    test('contains no duplicate names', () {
      final names = badAppDisplayNames;
      expect(names.toSet().length, names.length);
    });
  });
}
