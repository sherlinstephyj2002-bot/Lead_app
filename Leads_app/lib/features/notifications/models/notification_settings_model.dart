class NotificationSettingsModel {
  final bool attendanceNotifications;
  final bool leaveNotifications;
  final bool leadNotifications;
  final bool orderNotifications;
  final bool taskNotifications;
  final bool expenseNotifications;
  final bool payrollNotifications;
  final bool companyNotifications;
  final bool announcementNotifications;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool desktopNotifications;

  const NotificationSettingsModel({
    this.attendanceNotifications = true,
    this.leaveNotifications = true,
    this.leadNotifications = true,
    this.orderNotifications = true,
    this.taskNotifications = true,
    this.expenseNotifications = true,
    this.payrollNotifications = true,
    this.companyNotifications = true,
    this.announcementNotifications = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.desktopNotifications = true,
  });

  NotificationSettingsModel copyWith({
    bool? attendanceNotifications,
    bool? leaveNotifications,
    bool? leadNotifications,
    bool? orderNotifications,
    bool? taskNotifications,
    bool? expenseNotifications,
    bool? payrollNotifications,
    bool? companyNotifications,
    bool? announcementNotifications,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? desktopNotifications,
  }) {
    return NotificationSettingsModel(
      attendanceNotifications: attendanceNotifications ?? this.attendanceNotifications,
      leaveNotifications: leaveNotifications ?? this.leaveNotifications,
      leadNotifications: leadNotifications ?? this.leadNotifications,
      orderNotifications: orderNotifications ?? this.orderNotifications,
      taskNotifications: taskNotifications ?? this.taskNotifications,
      expenseNotifications: expenseNotifications ?? this.expenseNotifications,
      payrollNotifications: payrollNotifications ?? this.payrollNotifications,
      companyNotifications: companyNotifications ?? this.companyNotifications,
      announcementNotifications: announcementNotifications ?? this.announcementNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      desktopNotifications: desktopNotifications ?? this.desktopNotifications,
    );
  }
}
