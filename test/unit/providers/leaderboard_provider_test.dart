import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leaderboard/providers/leaderboard_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockLeaderboardRepository mockLeaderboardRepository;
  late MockRealtimeChannel mockChannel;
  late ProviderContainer container;

  setUp(() {
    mockLeaderboardRepository = MockLeaderboardRepository();
    mockChannel = MockRealtimeChannel();
    when(() => mockChannel.unsubscribe()).thenAnswer((_) async => 'ok');
    when(
      () => mockLeaderboardRepository.subscribeToLeaderboard(
        groupId: any(named: 'groupId'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenReturn(mockChannel);

    container = ProviderContainer(
      overrides: [
        leaderboardRepositoryProvider.overrideWithValue(
          mockLeaderboardRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  group('LeaderboardRealtimeNotifier.subscribe', () {
    test('opens a channel for the group and bumps state on update', () async {
      final notifier = container.read(leaderboardRealtimeProvider.notifier);

      late void Function() capturedOnUpdate;
      when(
        () => mockLeaderboardRepository.subscribeToLeaderboard(
          groupId: any(named: 'groupId'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((invocation) {
        capturedOnUpdate =
            invocation.namedArguments[#onUpdate] as void Function();
        return mockChannel;
      });

      await notifier.subscribe('g1');
      expect(container.read(leaderboardRealtimeProvider), 0);

      capturedOnUpdate();
      expect(container.read(leaderboardRealtimeProvider), 1);

      capturedOnUpdate();
      expect(container.read(leaderboardRealtimeProvider), 2);
    });

    test('does not resubscribe when already subscribed to the same group', () async {
      final notifier = container.read(leaderboardRealtimeProvider.notifier);

      await notifier.subscribe('g1');
      await notifier.subscribe('g1');

      verify(
        () => mockLeaderboardRepository.subscribeToLeaderboard(
          groupId: 'g1',
          onUpdate: any(named: 'onUpdate'),
        ),
      ).called(1);
    });

    test('unsubscribes the old channel when switching groups', () async {
      final notifier = container.read(leaderboardRealtimeProvider.notifier);

      await notifier.subscribe('g1');
      await notifier.subscribe('g2');

      verify(() => mockChannel.unsubscribe()).called(1);
      verify(
        () => mockLeaderboardRepository.subscribeToLeaderboard(
          groupId: 'g2',
          onUpdate: any(named: 'onUpdate'),
        ),
      ).called(1);
    });
  });

  group('LeaderboardRealtimeNotifier.unsubscribe', () {
    test('tears down the channel and clears the subscribed group', () async {
      final notifier = container.read(leaderboardRealtimeProvider.notifier);

      await notifier.subscribe('g1');
      notifier.unsubscribe();

      verify(() => mockChannel.unsubscribe()).called(1);

      // Subscribing to the same group again after unsubscribe should re-open a channel.
      await notifier.subscribe('g1');
      verify(
        () => mockLeaderboardRepository.subscribeToLeaderboard(
          groupId: 'g1',
          onUpdate: any(named: 'onUpdate'),
        ),
      ).called(2);
    });
  });
}
