import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/history_provider.dart';
import 'package:leaderboard/providers/leaderboard_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

class ScreentimeSyncNotifier extends StateNotifier<AsyncValue<void>> {
  ScreentimeSyncNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> sync({bool refreshHistory = true}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(screentimeRepositoryProvider).syncAndUpload();
      _ref.invalidate(leaderboardProvider);
      if (refreshHistory) {
        _ref.invalidate(historyProvider);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final screentimeSyncProvider =
    StateNotifierProvider<ScreentimeSyncNotifier, AsyncValue<void>>((ref) {
  return ScreentimeSyncNotifier(ref);
});
