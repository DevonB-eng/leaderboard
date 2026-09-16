String formatMinutes(double minutes) {
  final total = minutes.round();
  final hrs = total ~/ 60;
  final mins = total % 60;
  return hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';
}

/// Compact "how long ago", for the leaderboard's freshness captions.
///
/// Clock skew can put [timestamp] slightly ahead of the device, which reads as
/// "just now" rather than as a negative age.
String formatTimeAgo(DateTime timestamp, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(timestamp);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}

String dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// The seven days of the calendar week containing [now], Monday first.
///
/// Anchoring to Monday rather than to a rolling window ending today keeps the
/// chart's first column on the same weekday every day of the week. Days later
/// in the week than today simply have no data yet.
List<String> currentWeekDateKeys({DateTime? now}) {
  final today = now ?? DateTime.now();
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return List.generate(7, (i) => dateKey(monday.add(Duration(days: i))));
}

List<String> dayLabelsForDates(List<String> dates) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return dates.map((date) {
    final d = DateTime.parse(date);
    return days[d.weekday - 1];
  }).toList();
}

const _fullDayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String fullDayLabel(String date) {
  return _fullDayNames[DateTime.parse(date).weekday - 1];
}
