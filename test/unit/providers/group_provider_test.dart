import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leaderboard/data/models/group.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockGroupRepository mockGroupRepository;
  late ProviderContainer container;

  const testGroup = Group(
    id: 'g1',
    name: 'Roomies',
    memberIds: ['u1', 'u2', 'u3'],
    appVotes: {},
  );

  setUpAll(() {
    registerFallbackValue(<String, List<String>>{});
  });

  setUp(() {
    mockGroupRepository = MockGroupRepository();
    container = ProviderContainer(
      overrides: [
        groupRepositoryProvider.overrideWithValue(mockGroupRepository),
        groupProvider.overrideWith((ref) => Future.value(testGroup)),
      ],
    );
    addTearDown(container.dispose);
  });

  group('AppVotesNotifier.toggleVote', () {
    test(
      'removes the current user from an untracked app (everyone defaults to voted)',
      () async {
        when(
          () => mockGroupRepository.updateAppVotes(
            groupId: any(named: 'groupId'),
            appVotes: any(named: 'appVotes'),
          ),
        ).thenAnswer((_) async {});

        final notifier = container.read(appVotesProvider.notifier);
        await notifier.toggleVote('Instagram', 'u1', 'g1');

        expect(container.read(appVotesProvider)['Instagram'], ['u2', 'u3']);
      },
    );

    test('adds the current user back to an app they had unvoted', () async {
      when(
        () => mockGroupRepository.updateAppVotes(
          groupId: any(named: 'groupId'),
          appVotes: any(named: 'appVotes'),
        ),
      ).thenAnswer((_) async {});

      final notifier = container.read(appVotesProvider.notifier);
      notifier.setVotes({
        'Instagram': ['u2', 'u3'],
      });

      await notifier.toggleVote('Instagram', 'u1', 'g1');

      expect(
        container.read(appVotesProvider)['Instagram'],
        containsAll(['u1', 'u2', 'u3']),
      );
    });

    test('removes the current user from an already-voted app', () async {
      when(
        () => mockGroupRepository.updateAppVotes(
          groupId: any(named: 'groupId'),
          appVotes: any(named: 'appVotes'),
        ),
      ).thenAnswer((_) async {});

      final notifier = container.read(appVotesProvider.notifier);
      notifier.setVotes({
        'Instagram': ['u1', 'u2'],
      });

      await notifier.toggleVote('Instagram', 'u1', 'g1');

      expect(container.read(appVotesProvider)['Instagram'], ['u2']);
    });

    test('rolls back the optimistic update when the write fails', () async {
      when(
        () => mockGroupRepository.updateAppVotes(
          groupId: any(named: 'groupId'),
          appVotes: any(named: 'appVotes'),
        ),
      ).thenThrow(Exception('network error'));

      final notifier = container.read(appVotesProvider.notifier);
      notifier.setVotes({
        'Instagram': ['u2'],
      });

      await expectLater(
        () => notifier.toggleVote('Instagram', 'u1', 'g1'),
        throwsException,
      );

      expect(container.read(appVotesProvider)['Instagram'], ['u2']);
    });
  });

  group('AppVotesNotifier.isVotedByCurrentUser', () {
    test('defaults to true (voted) for an app with no vote entry yet', () {
      final notifier = container.read(appVotesProvider.notifier);
      expect(notifier.isVotedByCurrentUser('Instagram', 'u1'), isTrue);
    });

    test('reflects the actual voters list once an entry exists', () {
      final notifier = container.read(appVotesProvider.notifier);
      notifier.setVotes({
        'Instagram': ['u2'],
      });
      expect(notifier.isVotedByCurrentUser('Instagram', 'u1'), isFalse);
      expect(notifier.isVotedByCurrentUser('Instagram', 'u2'), isTrue);
    });
  });

  group('AppVotesNotifier.voteCount', () {
    test('shows total/total for an untracked app', () {
      final notifier = container.read(appVotesProvider.notifier);
      expect(notifier.voteCount('Instagram', 3), '3/3');
    });

    test('shows the actual voter count once an entry exists', () {
      final notifier = container.read(appVotesProvider.notifier);
      notifier.setVotes({
        'Instagram': ['u1'],
      });
      expect(notifier.voteCount('Instagram', 3), '1/3');
    });
  });
}
