import 'package:app_usage/app_usage.dart';
import 'package:flutter/services.dart';

import 'package:leaderboard/core/constants/bad_apps.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/repositories/group_repository.dart';
import 'package:leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:leaderboard/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The app_usage plugin's getAppUsage() launches the OS usage-access
/// settings screen as an unconditional side effect whenever permission is
/// missing — even when it's just being used to check status. This channel
/// (backed by MainActivity.kt) checks/opens usage access without that side
/// effect, so callers can test for permission before ever touching the
/// plugin.
const _usageAccessChannel = MethodChannel('leaderboard/usage_access');

class ScreentimeRepository {
  ScreentimeRepository({
    SupabaseClient? client,
    GroupRepository? groupRepository,
    LeaderboardRepository? leaderboardRepository,
  }) : _client = client ?? supabaseClient,
       _groupRepository = groupRepository ?? GroupRepository(client: client),
       _leaderboardRepository =
           leaderboardRepository ?? LeaderboardRepository(client: client);

  final SupabaseClient _client;
  final GroupRepository _groupRepository;
  final LeaderboardRepository _leaderboardRepository;

  static Future<bool> checkUsageStatsGranted() async {
    try {
      final granted = await _usageAccessChannel.invokeMethod<bool>(
        'isGranted',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the OS "Usage access" settings list directly, bypassing the
  /// app_usage plugin entirely.
  static Future<void> openUsageAccessSettings() async {
    try {
      await _usageAccessChannel.invokeMethod<void>('openSettings');
    } catch (_) {
      // Best-effort; nothing to recover if the platform channel is missing.
    }
  }

  Future<Map<String, int>> fetchBadAppUsage() async {
    // Never call the plugin while permission is missing — see the class
    // doc comment on _usageAccessChannel for why.
    if (!await checkUsageStatsGranted()) return {};

    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(days: 1));
    final usage = await AppUsage().getAppUsage(oneDayAgo, now);
    final map = <String, int>{};
    for (final info in usage) {
      if (badApps.containsKey(info.packageName)) {
        map[info.packageName] = info.usage.inMinutes;
      }
    }
    return map;
  }

  List<MapEntry<String, int>> groupForDisplay(Map<String, int> packageMap) {
    final map = <String, int>{};
    for (final entry in packageMap.entries) {
      final name = badApps[entry.key] ?? entry.key;
      map[name] = (map[name] ?? 0) + entry.value;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Future<void> uploadScreentime(Map<String, int> packageMap) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final grouped = groupForDisplay(packageMap);
    final totalBadMinutes = grouped.fold<double>(0, (sum, e) => sum + e.value);
    final badAppsBreakdown = grouped
        .map((e) => {'appName': e.key, 'minutes': e.value.toDouble()})
        .toList();

    await _client.from('screentime').upsert({
      'user_id': user.id,
      'total_bad_minutes': totalBadMinutes,
      'bad_apps_breakdown': badAppsBreakdown,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });

    await _rebuildGroupLeaderboard(user.id, badAppsBreakdown);
  }

  Future<void> syncAndUpload() async {
    final badAppUsage = await fetchBadAppUsage();
    await uploadScreentime(badAppUsage);
  }

  Future<void> _rebuildGroupLeaderboard(
    String userId,
    List<Map<String, dynamic>> myBreakdown,
  ) async {
    final userDoc = await _groupRepository.fetchUser(userId);
    final groupId = userDoc?.groupId;
    if (groupId == null) return;

    final group = await _groupRepository.fetchGroup(groupId);
    if (group == null) return;

    final memberIds = group.memberIds;
    if (memberIds.isEmpty) return;

    final activeApps = _getActiveApps(group.appVotes, memberIds.length);

    final screentimeRows = await _client
        .from('screentime')
        .select()
        .inFilter('user_id', memberIds);
    final usersRows = await _client
        .from('users')
        .select()
        .inFilter('id', memberIds);

    final screentimeByUid = <String, Map<String, dynamic>>{
      for (final row in screentimeRows) row['user_id'] as String: row,
    };
    final usersByUid = <String, Map<String, dynamic>>{
      for (final row in usersRows) row['id'] as String: row,
    };

    final entries = <Map<String, dynamic>>[];
    for (final uid in memberIds) {
      final user = usersByUid[uid];
      final st = screentimeByUid[uid];
      final username = (user?['username'] as String?) ?? 'Unknown';

      if (st == null) {
        entries.add({
          'uid': uid,
          'username': username,
          'totalBadMinutes': 0,
          'badAppsBreakdown': <Map<String, dynamic>>[],
          'lastUpdated': null,
        });
        continue;
      }

      final rawBreakdown = List<Map<String, dynamic>>.from(
        st['bad_apps_breakdown'] ?? [],
      );
      final filteredBreakdown = rawBreakdown
          .where((e) => activeApps.contains(e['appName']))
          .toList();
      final totalBadMinutes = filteredBreakdown.fold<double>(
        0,
        (sum, item) => sum + ((item['minutes'] as num?)?.toDouble() ?? 0),
      );

      entries.add({
        'uid': uid,
        'username': username,
        'totalBadMinutes': totalBadMinutes,
        'badAppsBreakdown': filteredBreakdown,
        'lastUpdated': st['last_updated'],
      });
    }

    entries.sort(
      (a, b) => ((b['totalBadMinutes'] as num?) ?? 0).compareTo(
        (a['totalBadMinutes'] as num?) ?? 0,
      ),
    );

    await _leaderboardRepository.upsertLeaderboard(
      groupId: groupId,
      entries: entries,
    );

    final today = dateKey(DateTime.now());
    final myFiltered = myBreakdown
        .where((e) => activeApps.contains(e['appName']))
        .toList();
    final myTotal = myFiltered.fold<double>(
      0,
      (sum, item) => sum + ((item['minutes'] as num?)?.toDouble() ?? 0),
    );
    await _leaderboardRepository.upsertUserHistory(
      userId: userId,
      dateKey: today,
      totalBadMinutes: myTotal,
      badAppsBreakdown: myFiltered,
    );

    final withData = entries.where((e) => e['lastUpdated'] != null).toList();
    if (withData.isNotEmpty) {
      final avg =
          withData.fold<double>(
            0,
            (sum, e) => sum + ((e['totalBadMinutes'] as num?)?.toDouble() ?? 0),
          ) /
          withData.length;
      await _leaderboardRepository.upsertGroupHistory(
        groupId: groupId,
        dateKey: today,
        averageBadMinutes: avg,
      );
    }
  }

  /// An app with no entry in [appVotes] has never been explicitly voted on,
  /// which the UI (see AppVotesNotifier.isVotedByCurrentUser) treats as
  /// everyone implicitly voting for it. Mirror that default here per-app —
  /// otherwise a single explicit vote on one app silently untracks every
  /// other app that was never touched.
  Set<String> _getActiveApps(
    Map<String, List<String>> appVotes,
    int totalMembers,
  ) {
    final activeApps = <String>{};
    for (final appName in badAppDisplayNames) {
      final voters = appVotes[appName];
      if (voters == null || voters.length > totalMembers / 2) {
        activeApps.add(appName);
      }
    }
    return activeApps;
  }
}
