import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:leaderboard/providers/repository_providers.dart';
import 'package:leaderboard/providers/screentime_provider.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockScreentimeRepository mockScreentimeRepository;
  late ProviderContainer container;

  setUp(() {
    mockScreentimeRepository = MockScreentimeRepository();
    container = ProviderContainer(
      overrides: [
        screentimeRepositoryProvider.overrideWithValue(
          mockScreentimeRepository,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ScreentimeSyncNotifier.sync', () {
    test('transitions loading -> data on success', () async {
      when(
        () => mockScreentimeRepository.syncAndUpload(),
      ).thenAnswer((_) async => true);

      final notifier = container.read(screentimeSyncProvider.notifier);
      expect(container.read(screentimeSyncProvider), const AsyncData<void>(null));

      final future = notifier.sync();
      expect(container.read(screentimeSyncProvider).isLoading, isTrue);

      await future;
      expect(container.read(screentimeSyncProvider), const AsyncData<void>(null));
      verify(() => mockScreentimeRepository.syncAndUpload()).called(1);
    });

    test('transitions loading -> error when the repository throws', () async {
      when(
        () => mockScreentimeRepository.syncAndUpload(),
      ).thenThrow(Exception('sync failed'));

      final notifier = container.read(screentimeSyncProvider.notifier);
      await notifier.sync();

      final state = container.read(screentimeSyncProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<Exception>());
    });
  });
}
