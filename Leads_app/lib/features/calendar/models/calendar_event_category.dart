import 'package:flutter/material.dart';

enum CalendarEventCategory {
  holidays,
  birthdays,
  meetings,
  leaves,
  attendance,
  payroll,
  shifts,
  crm,
  tasks,
}

extension CalendarEventCategoryExtension on CalendarEventCategory {
  String get displayName {
    switch (this) {
      case CalendarEventCategory.holidays:
        return 'Company Holidays';
      case CalendarEventCategory.birthdays:
        return 'Birthdays & Anniversaries';
      case CalendarEventCategory.meetings:
        return 'Meetings & Interviews';
      case CalendarEventCategory.leaves:
        return 'Leave Schedule';
      case CalendarEventCategory.attendance:
        return 'Attendance & WFH';
      case CalendarEventCategory.payroll:
        return 'Payroll & Statutory';
      case CalendarEventCategory.shifts:
        return 'Shift Rosters';
      case CalendarEventCategory.crm:
        return 'CRM & Sales';
      case CalendarEventCategory.tasks:
        return 'Tasks & Deadlines';
    }
  }

  Color get color {
    switch (this) {
      case CalendarEventCategory.holidays:
        return const Color(0xFFEF4444); // Red
      case CalendarEventCategory.birthdays:
        return const Color(0xFFEC4899); // Pink
      case CalendarEventCategory.meetings:
        return const Color(0xFF5B4CF0); // WorkTrack Purple
      case CalendarEventCategory.leaves:
        return const Color(0xFFF59E0B); // Amber
      case CalendarEventCategory.attendance:
        return const Color(0xFF0284C7); // Sky Blue
      case CalendarEventCategory.payroll:
        return const Color(0xFF10B981); // Emerald Green
      case CalendarEventCategory.shifts:
        return const Color(0xFF8B5CF6); // Violet
      case CalendarEventCategory.crm:
        return const Color(0xFF3B82F6); // Blue
      case CalendarEventCategory.tasks:
        return const Color(0xFFD97706); // Dark Amber
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarEventCategory.holidays:
        return Icons.nature_people_rounded;
      case CalendarEventCategory.birthdays:
        return Icons.cake_rounded;
      case CalendarEventCategory.meetings:
        return Icons.groups_rounded;
      case CalendarEventCategory.leaves:
        return Icons.event_busy_rounded;
      case CalendarEventCategory.attendance:
        return Icons.fingerprint_rounded;
      case CalendarEventCategory.payroll:
        return Icons.payments_rounded;
      case CalendarEventCategory.shifts:
        return Icons.schedule_rounded;
      case CalendarEventCategory.crm:
        return Icons.handshake_rounded;
      case CalendarEventCategory.tasks:
        return Icons.task_alt_rounded;
    }
  }
}
