import 'package:leaderboard/data/models/group.dart';
import 'package:leaderboard/data/models/user_profile.dart';
import 'package:leaderboard/data/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepository {
  GroupRepository({SupabaseClient? client})
    : _client = client ?? supabaseClient;

  final SupabaseClient _client;

  Future<UserProfile?> fetchUser(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<String?> fetchUserGroupId(String userId) async {
    final user = await fetchUser(userId);
    return user?.groupId;
  }

  /// password_hash is deliberately excluded — clients no longer have SELECT
  /// privilege on that column (see supabase/schema.sql), so `select()`
  /// (equivalent to `select *`) would fail with a permission error.
  static const _groupColumns = 'id, name, member_ids, app_votes, created_by, created_at';

  Future<Group?> fetchGroup(String groupId) async {
    final row = await _client
        .from('groups')
        .select(_groupColumns)
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return null;
    return Group.fromJson(row);
  }

  Future<List<GroupSummary>> searchGroups(String query) async {
    if (query.isEmpty) return [];
    // Escape ILIKE wildcard characters so a literal "%" or "_" in the
    // search box can't turn a prefix search into a match-everything query.
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final results = await _client
        .from('groups')
        .select('id, name, member_ids')
        .ilike('name', '$escaped%');
    return List<Map<String, dynamic>>.from(
      results,
    ).map(GroupSummary.fromJson).toList();
  }

  /// Group creation, joining, and leaving all run as SECURITY DEFINER
  /// Postgres functions (see supabase/schema.sql) rather than direct table
  /// writes — that's what lets the password check and hash happen server
  /// side without ever exposing password_hash to clients, and what stops
  /// any signed-in user from writing straight into another group's
  /// member_ids or password_hash.
  Future<void> createGroup({
    required String name,
    required String password,
  }) async {
    try {
      await _client.rpc(
        'create_group',
        params: {'p_name': name.trim(), 'p_password': password},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<Group> joinGroup({
    required String groupId,
    required String password,
  }) async {
    try {
      final row = await _client.rpc(
        'join_group',
        params: {'p_group_id': groupId, 'p_password': password},
      );
      return Group.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> leaveGroup({required String groupId}) async {
    try {
      await _client.rpc('leave_group', params: {'p_group_id': groupId});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateAppVotes({
    required String groupId,
    required Map<String, List<String>> appVotes,
  }) async {
    await _client
        .from('groups')
        .update({'app_votes': appVotes})
        .eq('id', groupId);
  }

  Future<List<UserProfile>> fetchMembers(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    final profiles = await Future.wait(memberIds.map(fetchUser));
    return profiles.whereType<UserProfile>().toList();
  }
}
