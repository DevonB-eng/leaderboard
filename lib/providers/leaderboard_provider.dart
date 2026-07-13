import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/providers/group_provider.dart';
import 'package:leaderboard/providers/repository_providers.dart';

final leaderboardProvider = FutureProvider<Leaderboard?>((ref) async {
  final groupId = await ref.watch(groupIdProvider.future);
  if (groupId == null) return null;
  return ref.watch(leaderboardRepositoryProvider).fetchLeaderboard(groupId);
});

class LeaderboardRealtimeNotifier extends StateNotifier<int> {
  LeaderboardRealtimeNotifier(this._ref) : super(0);

  final Ref _ref;
  RealtimeChannel? _channel;
  String? _subscribedGroupId;

  Future<void> subscribe(String groupId) async {
    if (_subscribedGroupId == groupId) return;
    _channel?.unsubscribe();
    _subscribedGroupId = groupId;
    _channel = _ref.read(leaderboardRepositoryProvider).subscribeToLeaderboard(
          groupId: groupId,
          onUpdate: () {
            state++;
            _ref.invalidate(leaderboardProvider);
          },
        );
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribedGroupId = null;
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}

final leaderboardRealtimeProvider =
    StateNotifierProvider<LeaderboardRealtimeNotifier, int>((ref) {
  final notifier = LeaderboardRealtimeNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
