import 'package:flutter/services.dart';

import 'package:leaderboard/core/constants/bad_apps.dart';
import 'package:leaderboard/core/utils/duration_format.dart';
import 'package:leaderboard/data/repositories/group_repository.dart';
import 'package:leaderboard/data/repositories/leaderboard_repository.dart';
import 'package:leaderboard/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backed by MainActivity.kt. Reads usage-stats permission and per-package
/// foreground time without the side effects and bucket-aggregation errors of
/// the app_usage plugin — see the doc comment in MainActivity.kt.
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

  /// Minutes of foreground time per tracked package between [from] and [to].
  ///
  /// Returns null when usage data can't be read at all — permission missing, or
  /// the platform channel absent (it is registered by MainActivity, so it does
  /// not exist in background isolates, and never on iOS). Null means "unknown"
  /// and must never be collapsed into zero: writing zeros would wipe the day's
  /// real total out of both `screentime` and `screentime_history`.
  Future<Map<String, double>?> fetchBadAppUsage(DateTime from, DateTime to) async {
    if (!await checkUsageStatsGranted()) return null;

    final Map<String, int>? usage;
    try {
      usage = await _usageAccessChannel.invokeMapMethod<String, int>('getUsage', {
        'start': from.millisecondsSinceEpoch,
        'end': to.millisecondsSinceEpoch,
      });
    } catch (_) {
      return null;
    }
    if (usage == null) return null;

    final map = <String, double>{};
    for (final entry in usage.entries) {
      if (badApps.containsKey(entry.key)) {
        map[entry.key] = entry.value / Duration.millisecondsPerMinute;
      }
    }
    return map;
  }

  List<MapEntry<String, double>> groupForDisplay(
    Map<String, double> packageMap,
  ) {
    final map = <String, double>{};
    for (final entry in packageMap.entries) {
      final name = badApps[entry.key] ?? entry.key;
      map[name] = (map[name] ?? 0) + entry.value;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Future<void> uploadScreentime(
    Map<String, double> packageMap,
    DateTime day,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final grouped = groupForDisplay(packageMap);
    final totalBadMinutes = grouped.fold<double>(0, (sum, e) => sum + e.value);
    final badAppsBreakdown = grouped
        .map((e) => {'appName': e.key, 'minutes': e.value})
        .toList();
    final today = dateKey(day);

    await _client.from('screentime').upsert({
      'user_id': user.id,
      'date_key': today,
      'total_bad_minutes': totalBadMinutes,
      'bad_apps_breakdown': badAppsBreakdown,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });

    await _rebuildGroupLeaderboard(user.id, badAppsBreakdown, today);
  }

  Future<void> syncAndUpload() async {
    // One clock reading for the whole sync. Deriving the window start and the
    // date_key independently would mis-file a sync that straddles midnight,
    // filing a fresh day's minutes under the previous day.
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final badAppUsage = await fetchBadAppUsage(startOfDay, now);
    if (badAppUsage == null) return;

    await uploadScreentime(badAppUsage, startOfDay);
  }

  Future<void> _rebuildGroupLeaderboard(
    String userId,
    List<Map<String, dynamic>> myBreakdown,
    String today,
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

      // `screentime` holds one row per user, overwritten on their last sync —
      // it carries no date of its own beyond date_key. A member who stopped
      // syncing yesterday still has yesterday's row, so without this check
      // their old total is republished as today's figure every rebuild and
      // never resets. Treat anything not stamped with today as no data.
      if (st == null || st['date_key'] != today) {
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
