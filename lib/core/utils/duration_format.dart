String formatMinutes(double minutes) {
  final total = minutes.round();
  final hrs = total ~/ 60;
  final mins = total % 60;
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
