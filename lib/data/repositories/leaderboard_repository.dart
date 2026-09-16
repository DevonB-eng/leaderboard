import 'package:leaderboard/data/models/history_day.dart';
import 'package:leaderboard/data/models/leaderboard_entry.dart';
import 'package:leaderboard/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardRepository {
  LeaderboardRepository({SupabaseClient? client})
    : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<Leaderboard?> fetchLeaderboard(String groupId) async {
    final row = await _client
        .from('group_leaderboard')
        .select()
        .eq('group_id', groupId)
        .maybeSingle();
    if (row == null) return null;
    return Leaderboard.fromJson(groupId, row);
  }

  Future<void> upsertLeaderboard({
    required String groupId,
    required List<Map<String, dynamic>> entries,
  }) async {
    await _client.from('group_leaderboard').upsert({
      'group_id': groupId,
      'entries': entries,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Your minutes and the group's per-member average for each of [dateKeys],
  /// both taken from the members' `screentime_history` rows — the same rows
  /// the per-day standings are built from, so the chart and the standings
  /// under it always agree.
  Future<WeeklyHistory> fetchWeeklyHistory({
    required String userId,
    required List<String> memberIds,
    required List<String> dateKeys,
  }) async {
    final rows = memberIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('screentime_history')
                .select('user_id, date_key, total_bad_minutes')
                .inFilter('user_id', memberIds)
                .inFilter('date_key', dateKeys),
          );

    return WeeklyHistory.fromHistoryRows(
      rows: rows,
      userId: userId,
      memberCount: memberIds.length,
      dateKeys: dateKeys,
    );
  }

  /// Each member's summed minutes across [dateKeys], for the weekly standings.
  Future<Map<String, double>> fetchWeeklyTotals({
    required List<String> userIds,
    required List<String> dateKeys,
  }) async {
    if (userIds.isEmpty) return {};

    final rows = await _client
        .from('screentime_history')
        .select('user_id, total_bad_minutes')
        .inFilter('user_id', userIds)
        .inFilter('date_key', dateKeys);

    final totals = <String, double>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final uid = row['user_id'] as String?;
      if (uid == null) continue;
      final minutes = ((row['total_bad_minutes'] ?? 0) as num).toDouble();
      totals[uid] = (totals[uid] ?? 0) + minutes;
    }
    return totals;
  }

  /// One day's standings for a group, built from each member's history row.
  ///
  /// Members with no row for [dateKey] are kept at zero so the day still shows
  /// the whole group.
  Future<List<LeaderboardEntry>> fetchDayStandings({
    required Map<String, String> usernamesByUserId,
    required String dateKey,
  }) async {
    if (usernamesByUserId.isEmpty) return [];

    final rows = await _client
        .from('screentime_history')
        .select()
        .inFilter('user_id', usernamesByUserId.keys.toList())
        .eq('date_key', dateKey);

    final rowsByUserId = <String, Map<String, dynamic>>{
      for (final row in List<Map<String, dynamic>>.from(rows))
        row['user_id'] as String: row,
    };

    final entries = usernamesByUserId.entries.map((member) {
      final row = rowsByUserId[member.key];
      final breakdown =
          (row?['bad_apps_breakdown'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AppBreakdown.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          <AppBreakdown>[];

      return LeaderboardEntry(
        userId: member.key,
        username: member.value,
        totalBadMinutes: ((row?['total_bad_minutes'] ?? 0) as num).toDouble(),
        badAppsBreakdown: breakdown,
        lastUpdated: row?['recorded_at'] as String?,
      );
    }).toList();

    entries.sort((a, b) => b.totalBadMinutes.compareTo(a.totalBadMinutes));
    return entries;
  }

  Future<void> upsertUserHistory({
    required String userId,
    required String dateKey,
    required double totalBadMinutes,
    required List<Map<String, dynamic>> badAppsBreakdown,
  }) async {
    await _client.from('screentime_history').upsert({
      'user_id': userId,
      'date_key': dateKey,
      'total_bad_minutes': totalBadMinutes,
      'bad_apps_breakdown': badAppsBreakdown,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  RealtimeChannel subscribeToLeaderboard({
    required String groupId,
    required void Function() onUpdate,
  }) {
    return _client
        .channel('group_leaderboard:$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_leaderboard',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
