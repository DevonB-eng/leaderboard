import 'package:leaderboard/core/utils/password_hash.dart';
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

  Future<Group?> fetchGroup(String groupId) async {
    final row = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return null;
    return Group.fromJson(row);
  }

  Future<List<GroupSummary>> searchGroups(String query) async {
    if (query.isEmpty) return [];
    final results = await _client
        .from('groups')
        .select('id, name, member_ids')
        .ilike('name', '$query%');
    return List<Map<String, dynamic>>.from(
      results,
    ).map(GroupSummary.fromJson).toList();
  }

  Future<void> createGroup({
    required String userId,
    required String name,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final existing = await _client
        .from('groups')
        .select('id')
        .eq('name_lower', normalizedName.toLowerCase())
        .limit(1);
    if (existing.isNotEmpty) {
      throw Exception('A group with that name already exists.');
    }

    final row = await _client
        .from('groups')
        .insert({
          'name': normalizedName,
          'name_lower': normalizedName.toLowerCase(),
          'password_hash': hashPassword(password),
          'member_ids': [userId],
          'created_by': userId,
        })
        .select()
        .single();

    await _client
        .from('users')
        .update({'group_id': row['id']})
        .eq('id', userId);
  }

  Future<Group> joinGroup({
    required String userId,
    required String groupId,
    required String password,
  }) async {
    final group = await fetchGroup(groupId);
    if (group == null) {
      throw Exception('Group not found.');
    }

    final row = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    final passwordHash = row?['password_hash'] as String?;
    if (passwordHash == null || passwordHash != hashPassword(password)) {
      throw Exception('Incorrect password.');
    }

    final memberIds = List<String>.from(group.memberIds);
    if (!memberIds.contains(userId)) {
      memberIds.add(userId);
      await _client
          .from('groups')
          .update({'member_ids': memberIds})
          .eq('id', groupId);
    }
    await _client.from('users').update({'group_id': groupId}).eq('id', userId);

    return Group(
      id: group.id,
      name: group.name,
      memberIds: memberIds,
      appVotes: group.appVotes,
    );
  }

  Future<void> leaveGroup({
    required String userId,
    required String groupId,
  }) async {
    final group = await fetchGroup(groupId);
    if (group == null) return;

    final updatedMemberIds = group.memberIds
        .where((id) => id != userId)
        .toList();

    if (updatedMemberIds.isEmpty) {
      await _client.from('groups').delete().eq('id', groupId);
      await _client.from('group_leaderboard').delete().eq('group_id', groupId);
      await _client.from('group_history').delete().eq('group_id', groupId);
    } else {
      await _client
          .from('groups')
          .update({'member_ids': updatedMemberIds})
          .eq('id', groupId);
    }

    await _client.from('users').update({'group_id': null}).eq('id', userId);
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
