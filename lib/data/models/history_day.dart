class HistoryDay {
  const HistoryDay({
    required this.dateKey,
    required this.personalMinutes,
    required this.groupAverageMinutes,
  });

  final String dateKey;
  final double personalMinutes;
  final double groupAverageMinutes;
}

class WeeklyHistory {
  const WeeklyHistory({
    required this.personal,
    required this.group,
    required this.dateKeys,
  });

  final Map<String, double> personal;
  final Map<String, double> group;
  final List<String> dateKeys;

  List<HistoryDay> get days => dateKeys
      .map(
        (key) => HistoryDay(
          dateKey: key,
          personalMinutes: personal[key] ?? 0,
          groupAverageMinutes: group[key] ?? 0,
        ),
      )
      .toList();
}
