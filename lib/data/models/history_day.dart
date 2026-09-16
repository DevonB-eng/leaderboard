class WeeklyHistory {
  const WeeklyHistory({
    required this.personal,
    required this.group,
    required this.dateKeys,
  });

  final Map<String, double> personal;
  final Map<String, double> group;
  final List<String> dateKeys;

  /// Builds both chart series from the group members' `screentime_history`
  /// [rows].
  ///
  /// The group figure is averaged over all [memberCount] members, and a member
  /// with no row for a day counts as zero. Averaging only the members who had
  /// reported made a lone reporter's own total read as the group average.
  factory WeeklyHistory.fromHistoryRows({
    required List<Map<String, dynamic>> rows,
    required String userId,
    required int memberCount,
    required List<String> dateKeys,
  }) {
    final personal = {for (final date in dateKeys) date: 0.0};
    final groupTotals = {for (final date in dateKeys) date: 0.0};

    for (final row in rows) {
      final date = row['date_key']?.toString();
      if (date == null || !groupTotals.containsKey(date)) continue;

      final minutes = ((row['total_bad_minutes'] ?? 0) as num).toDouble();
      groupTotals[date] = groupTotals[date]! + minutes;
      if (row['user_id'] == userId) personal[date] = minutes;
    }

    return WeeklyHistory(
      personal: personal,
      group: {
        for (final entry in groupTotals.entries)
          entry.key: memberCount > 0 ? entry.value / memberCount : 0.0,
      },
      dateKeys: dateKeys,
    );
  }
}
