class Group {
  const Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.appVotes,
  });

  final String id;
  final String name;
  final List<String> memberIds;
  final Map<String, List<String>> appVotes;

  factory Group.fromJson(Map<String, dynamic> json) {
    final rawVotes = Map<String, dynamic>.from((json['app_votes'] as Map?) ?? {});
    final parsedVotes = rawVotes.map(
      (app, voters) => MapEntry(app, List<String>.from(voters as List)),
    );

    return Group(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Unknown Group',
      memberIds: _memberIdsFromRow(json),
      appVotes: parsedVotes,
    );
  }

  static List<String> _memberIdsFromRow(Map<String, dynamic> row) {
    final v = row['member_ids'];
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  final String id;
  final String name;
  final int memberCount;

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    return GroupSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      memberCount: Group._memberIdsFromRow(json).length,
    );
  }
}
