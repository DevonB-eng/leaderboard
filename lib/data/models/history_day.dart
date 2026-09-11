class WeeklyHistory {
  const WeeklyHistory({
    required this.personal,
    required this.group,
    required this.dateKeys,
  });

  final Map<String, double> personal;
  final Map<String, double> group;
  final List<String> dateKeys;
}
