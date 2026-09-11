String formatMinutes(double minutes) {
  final hrs = (minutes / 60).floor();
  final mins = (minutes % 60).round();
  return hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';
}

String dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

List<String> lastSevenDateKeys() {
  return List.generate(7, (i) {
    final day = DateTime.now().subtract(Duration(days: 6 - i));
    return dateKey(day);
  });
}

List<String> dayLabelsForDates(List<String> dates) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return dates.map((date) {
    final d = DateTime.parse(date);
    return days[d.weekday - 1];
  }).toList();
}
