class CalendarSettingsModel {
  final List<int> workingDays; // 1 = Mon, 7 = Sun
  final List<int> weekendDays;
  final String defaultShift;
  final int payrollDate; // Day of month
  final int defaultReminderMinutes;
  final String businessStartTime;
  final String businessEndTime;
  final String timeZone;
  final int firstDayOfWeek; // 1 = Mon, 7 = Sun
  final String colorTheme;

  const CalendarSettingsModel({
    this.workingDays = const [1, 2, 3, 4, 5],
    this.weekendDays = const [6, 7],
    this.defaultShift = 'General Shift (09:00 AM - 06:00 PM)',
    this.payrollDate = 28,
    this.defaultReminderMinutes = 30,
    this.businessStartTime = '09:00 AM',
    this.businessEndTime = '06:00 PM',
    this.timeZone = 'Asia/Kolkata (GMT+5:30)',
    this.firstDayOfWeek = 1,
    this.colorTheme = 'WorkTrack Purple',
  });

  CalendarSettingsModel copyWith({
    List<int>? workingDays,
    List<int>? weekendDays,
    String? defaultShift,
    int? payrollDate,
    int? defaultReminderMinutes,
    String? businessStartTime,
    String? businessEndTime,
    String? timeZone,
    int? firstDayOfWeek,
    String? colorTheme,
  }) {
    return CalendarSettingsModel(
      workingDays: workingDays ?? this.workingDays,
      weekendDays: weekendDays ?? this.weekendDays,
      defaultShift: defaultShift ?? this.defaultShift,
      payrollDate: payrollDate ?? this.payrollDate,
      defaultReminderMinutes: defaultReminderMinutes ?? this.defaultReminderMinutes,
      businessStartTime: businessStartTime ?? this.businessStartTime,
      businessEndTime: businessEndTime ?? this.businessEndTime,
      timeZone: timeZone ?? this.timeZone,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }
}
