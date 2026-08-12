import 'package:flutter/material.dart';

enum NotificationCategory {
  attendance,
  leaves,
  leads,
  orders,
  tasks,
  expenses,
  payroll,
  hr,
  employees,
  company,
  subscription,
  announcements,
  system,
}

extension NotificationCategoryExtension on NotificationCategory {
  String get displayName {
    switch (this) {
      case NotificationCategory.attendance:
        return 'Attendance';
      case NotificationCategory.leaves:
        return 'Leaves';
      case NotificationCategory.leads:
        return 'Leads';
      case NotificationCategory.orders:
        return 'Orders';
      case NotificationCategory.tasks:
        return 'Tasks';
      case NotificationCategory.expenses:
        return 'Expenses';
      case NotificationCategory.payroll:
        return 'Payroll';
      case NotificationCategory.hr:
        return 'HR Management';
      case NotificationCategory.employees:
        return 'Employees';
      case NotificationCategory.company:
        return 'Company';
      case NotificationCategory.subscription:
        return 'Subscription';
      case NotificationCategory.announcements:
        return 'Announcements';
      case NotificationCategory.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationCategory.attendance:
        return Icons.fingerprint_rounded;
      case NotificationCategory.leaves:
        return Icons.event_busy_rounded;
      case NotificationCategory.leads:
        return Icons.person_search_rounded;
      case NotificationCategory.orders:
        return Icons.receipt_long_rounded;
      case NotificationCategory.tasks:
        return Icons.task_alt_rounded;
      case NotificationCategory.expenses:
        return Icons.account_balance_wallet_rounded;
      case NotificationCategory.payroll:
        return Icons.payments_rounded;
      case NotificationCategory.hr:
        return Icons.badge_rounded;
      case NotificationCategory.employees:
        return Icons.groups_rounded;
      case NotificationCategory.company:
        return Icons.corporate_fare_rounded;
      case NotificationCategory.subscription:
        return Icons.card_membership_rounded;
      case NotificationCategory.announcements:
        return Icons.campaign_rounded;
      case NotificationCategory.system:
        return Icons.settings_suggest_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationCategory.attendance:
        return const Color(0xFF0284C7); // Sky Blue
      case NotificationCategory.leaves:
        return const Color(0xFF10B981); // Emerald
      case NotificationCategory.leads:
        return const Color(0xFF5B4CF0); // Primary Purple
      case NotificationCategory.orders:
        return const Color(0xFF8B5CF6); // Violet
      case NotificationCategory.tasks:
        return const Color(0xFF3B82F6); // Blue
      case NotificationCategory.expenses:
        return const Color(0xFFF59E0B); // Amber
      case NotificationCategory.payroll:
        return const Color(0xFF059669); // Green
      case NotificationCategory.hr:
        return const Color(0xFFD97706); // Dark Amber
      case NotificationCategory.employees:
        return const Color(0xFF6366F1); // Indigo
      case NotificationCategory.company:
        return const Color(0xFF475569); // Slate
      case NotificationCategory.subscription:
        return const Color(0xFFEC4899); // Pink
      case NotificationCategory.announcements:
        return const Color(0xFFEAB308); // Yellow
      case NotificationCategory.system:
        return const Color(0xFF64748B); // Cool Grey
    }
  }
}
