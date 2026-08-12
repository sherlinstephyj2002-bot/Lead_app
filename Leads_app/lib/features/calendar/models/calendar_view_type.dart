enum CalendarViewType {
  month,
  week,
  day,
  agenda,
}

extension CalendarViewTypeExtension on CalendarViewType {
  String get label {
    switch (this) {
      case CalendarViewType.month:
        return 'Month View';
      case CalendarViewType.week:
        return 'Week View';
      case CalendarViewType.day:
        return 'Day View';
      case CalendarViewType.agenda:
        return 'Agenda View';
    }
  }
}
