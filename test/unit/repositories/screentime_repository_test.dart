import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/repositories/screentime_repository.dart';

import '../../helpers/mocks.dart';

void main() {
  group('ScreentimeRepository.groupForDisplay', () {
    // groupForDisplay is pure and never touches the client, but the
    // constructor's default `?? supabaseClient` still evaluates eagerly,
    // so a client must be injected to avoid requiring Supabase.initialize().
    final repository = ScreentimeRepository(client: MockSupabaseClient());

    // MapEntry has no structural `==`, so assertions compare key/value pairs
    // directly rather than the MapEntry instances themselves.
    List<List<Object>> asPairs(List<MapEntry<String, int>> entries) =>
        entries.map((e) => [e.key, e.value]).toList();

    test('maps package names to display names', () {
      final result = repository.groupForDisplay({
        'com.instagram.android': 10,
      });
      expect(asPairs(result), [
        ['Instagram', 10],
      ]);
    });

    test('sums minutes for packages that share a display name', () {
      final result = repository.groupForDisplay({
        'com.android.chrome': 15,
        'org.mozilla.firefox': 5,
      });
      expect(asPairs(result), [
        ['Browser', 20],
      ]);
    });

    test('sorts descending by minutes', () {
      final result = repository.groupForDisplay({
        'com.instagram.android': 5,
        'com.zhiliaoapp.musically': 30,
        'com.snapchat.android': 15,
      });
      expect(result.map((e) => e.key).toList(), ['TikTok', 'Snapchat', 'Instagram']);
    });

    test('falls back to the raw package name for unmapped packages', () {
      final result = repository.groupForDisplay({'com.unknown.app': 7});
      expect(asPairs(result), [
        ['com.unknown.app', 7],
      ]);
    });

    test('returns an empty list for empty input', () {
      expect(repository.groupForDisplay({}), isEmpty);
    });
  });
}
