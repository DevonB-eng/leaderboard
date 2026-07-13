import 'package:leaderboard/data/models/leaderboard_entry.dart';

class ScreentimeRecord {
  const ScreentimeRecord({
    required this.userId,
    required this.totalBadMinutes,
    required this.badAppsBreakdown,
    this.lastUpdated,
  });

  final String userId;
  final double totalBadMinutes;
  final List<AppBreakdown> badAppsBreakdown;
  final String? lastUpdated;

  factory ScreentimeRecord.fromJson(Map<String, dynamic> json) {
    final breakdown = (json['bad_apps_breakdown'] as List<dynamic>?)
            ?.map((e) => AppBreakdown.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    return ScreentimeRecord(
      userId: json['user_id'] as String,
      totalBadMinutes: (json['total_bad_minutes'] as num?)?.toDouble() ?? 0,
      badAppsBreakdown: breakdown,
      lastUpdated: json['last_updated'] as String?,
    );
  }
}
