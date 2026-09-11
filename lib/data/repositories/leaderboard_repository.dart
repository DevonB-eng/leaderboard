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

  Future<WeeklyHistory> fetchWeeklyHistory({
    required String userId,
    required String groupId,
    required List<String> dateKeys,
  }) async {
    final results = await Future.wait([
      _client
          .from('screentime_history')
          .select()
          .eq('user_id', userId)
          .inFilter('date_key', dateKeys),
      _client
          .from('group_history')
          .select()
          .eq('group_id', groupId)
          .inFilter('date_key', dateKeys),
    ]);

    final personalRows = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(results[0])) {
      final dk = row['date_key']?.toString();
      if (dk != null) personalRows[dk] = row;
    }

    final groupRows = <String, Map<String, dynamic>>{};
    for (final row in List<Map<String, dynamic>>.from(results[1])) {
      final dk = row['date_key']?.toString();
      if (dk != null) groupRows[dk] = row;
    }

    final personal = <String, double>{};
    final group = <String, double>{};
    for (final date in dateKeys) {
      personal[date] = personalRows.containsKey(date)
          ? ((personalRows[date]?['total_bad_minutes'] ?? 0) as num).toDouble()
          : 0;
      group[date] = groupRows.containsKey(date)
          ? ((groupRows[date]?['average_bad_minutes'] ?? 0) as num).toDouble()
          : 0;
    }

    return WeeklyHistory(personal: personal, group: group, dateKeys: dateKeys);
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

  Future<void> upsertGroupHistory({
    required String groupId,
    required String dateKey,
    required double averageBadMinutes,
  }) async {
    await _client.from('group_history').upsert({
      'group_id': groupId,
      'date_key': dateKey,
      'average_bad_minutes': averageBadMinutes,
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
