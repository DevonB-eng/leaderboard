class AppBreakdown {
  const AppBreakdown({
    required this.appName,
    required this.minutes,
  });

  final String appName;
  final double minutes;

  factory AppBreakdown.fromJson(Map<String, dynamic> json) {
    return AppBreakdown(
      appName: (json['appName'] as String?) ?? 'Unknown',
      minutes: (json['minutes'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'minutes': minutes,
      };
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.totalBadMinutes,
    required this.badAppsBreakdown,
    this.lastUpdated,
  });

  final String userId;
  final String username;
  final double totalBadMinutes;
  final List<AppBreakdown> badAppsBreakdown;
  final String? lastUpdated;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['badAppsBreakdown'] as List<dynamic>?)
            ?.map((e) => AppBreakdown.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return LeaderboardEntry(
      userId: (json['uid'] as String?) ?? '',
      username: (json['username'] as String?) ?? 'Anonymous',
      totalBadMinutes: (json['totalBadMinutes'] as num?)?.toDouble() ?? 0,
      badAppsBreakdown: breakdown,
      lastUpdated: json['lastUpdated'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': userId,
        'username': username,
        'totalBadMinutes': totalBadMinutes,
        'badAppsBreakdown': badAppsBreakdown.map((e) => e.toJson()).toList(),
        'lastUpdated': lastUpdated,
      };
}

class Leaderboard {
  const Leaderboard({
    required this.groupId,
    required this.entries,
    this.lastUpdated,
  });

  final String groupId;
  final List<LeaderboardEntry> entries;
  final String? lastUpdated;

  factory Leaderboard.fromJson(String groupId, Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List<dynamic>?) ?? [];
    return Leaderboard(
      groupId: groupId,
      entries: rawEntries
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      lastUpdated: json['last_updated'] as String?,
    );
  }
}
