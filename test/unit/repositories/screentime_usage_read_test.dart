import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leaderboard/data/repositories/screentime_repository.dart';

import '../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('leaderboard/usage_access');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final repository = ScreentimeRepository(client: MockSupabaseClient());
  final from = DateTime(2026, 9, 12);
  final to = DateTime(2026, 9, 12, 10, 30);

  final calls = <MethodCall>[];

  void handle(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('ScreentimeRepository.fetchBadAppUsage', () {
    test('converts milliseconds to minutes and drops untracked packages', () async {
      handle((call) async {
        if (call.method == 'isGranted') return true;
        return <String, int>{
          'com.instagram.android': 90000, // 1.5 min
          'com.devonbeng.leaderboard': 600000, // not a tracked app
        };
      });

      expect(await repository.fetchBadAppUsage(from, to), {
        'com.instagram.android': 1.5,
      });
    });

    test('requests exactly the window it was given, in epoch millis', () async {
      handle((call) async => call.method == 'isGranted' ? true : <String, int>{});

      await repository.fetchBadAppUsage(from, to);

      final getUsage = calls.firstWhere((c) => c.method == 'getUsage');
      expect(getUsage.arguments, {
        'start': from.millisecondsSinceEpoch,
        'end': to.millisecondsSinceEpoch,
      });
    });

    test('a day with no tracked usage reads as empty, not unavailable', () async {
      handle((call) async => call.method == 'isGranted' ? true : <String, int>{});

      expect(await repository.fetchBadAppUsage(from, to), isEmpty);
    });

    // The null cases below all mean "unknown". syncAndUpload must skip the
    // upload entirely for them — treating them as zero would overwrite the
    // day's real total with 0 in both `screentime` and `screentime_history`.
    test('returns null without reading usage when permission is denied', () async {
      handle((call) async => call.method == 'isGranted' ? false : <String, int>{});

      expect(await repository.fetchBadAppUsage(from, to), isNull);
      expect(calls.map((c) => c.method), isNot(contains('getUsage')));
    });

    test('returns null when the platform channel is unavailable', () async {
      // Stands in for a background isolate, where MainActivity never runs and
      // so never registers this channel, and for iOS.
      messenger.setMockMethodCallHandler(channel, null);

      expect(await repository.fetchBadAppUsage(from, to), isNull);
    });

    test('returns null when reading usage fails', () async {
      handle((call) async {
        if (call.method == 'isGranted') return true;
        throw PlatformException(code: 'bad_range');
      });

      expect(await repository.fetchBadAppUsage(from, to), isNull);
    });
  });
}
