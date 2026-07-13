import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:leaderboard/data/models/group.dart';
import 'package:leaderboard/data/models/user_profile.dart';
import 'package:leaderboard/providers/repository_providers.dart';

final groupIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(groupRepositoryProvider).fetchUserGroupId(user.id);
});

final groupProvider = FutureProvider<Group?>((ref) async {
  final groupId = await ref.watch(groupIdProvider.future);
  if (groupId == null) return null;
  return ref.watch(groupRepositoryProvider).fetchGroup(groupId);
});

final groupMembersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final group = await ref.watch(groupProvider.future);
  if (group == null) return [];
  return ref.watch(groupRepositoryProvider).fetchMembers(group.memberIds);
});

class AppVotesNotifier extends StateNotifier<Map<String, List<String>>> {
  AppVotesNotifier(this._ref) : super({});

  final Ref _ref;

  void setVotes(Map<String, List<String>> votes) {
    state = votes;
  }

  Future<void> toggleVote(String appName, String userId, String groupId) async {
    final hasEntry = state.containsKey(appName);
    final currentlyVoted = _isVotedByCurrentUser(appName, userId);
    final initialList = hasEntry
        ? List<String>.from(state[appName]!)
        : await _allMemberIds();

    final updated = List<String>.from(initialList);
    if (currentlyVoted) {
      updated.remove(userId);
    } else if (!updated.contains(userId)) {
      updated.add(userId);
    }

    state = {...state, appName: updated};

    try {
      await _ref.read(groupRepositoryProvider).updateAppVotes(
            groupId: groupId,
            appVotes: state,
          );
    } catch (_) {
      state = {...state, appName: initialList};
      rethrow;
    }
  }

  bool isVotedByCurrentUser(String appName, String userId) {
    if (!state.containsKey(appName)) return true;
    return state[appName]!.contains(userId);
  }

  String voteCount(String appName, int totalMembers) {
    if (!state.containsKey(appName)) return '$totalMembers/$totalMembers';
    return '${state[appName]!.length}/$totalMembers';
  }

  bool _isVotedByCurrentUser(String appName, String userId) {
    return isVotedByCurrentUser(appName, userId);
  }

  Future<List<String>> _allMemberIds() async {
    final group = await _ref.read(groupProvider.future);
    return group?.memberIds ?? [];
  }
}

final appVotesProvider =
    StateNotifierProvider<AppVotesNotifier, Map<String, List<String>>>((ref) {
  return AppVotesNotifier(ref);
});
