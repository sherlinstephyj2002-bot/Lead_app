import 'package:flutter/material.dart';

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

extension NotificationPriorityExtension on NotificationPriority {
  String get label {
    switch (this) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.medium:
        return 'Medium';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case NotificationPriority.low:
        return const Color(0xFF64748B);
      case NotificationPriority.medium:
        return const Color(0xFF0EA5E9);
      case NotificationPriority.high:
        return const Color(0xFFF59E0B);
      case NotificationPriority.urgent:
        return const Color(0xFFEF4444);
    }
  }

  Color get badgeBg {
    switch (this) {
      case NotificationPriority.low:
        return const Color(0xFFF1F5F9);
      case NotificationPriority.medium:
        return const Color(0xFFE0F2FE);
      case NotificationPriority.high:
        return const Color(0xFFFEF3C7);
      case NotificationPriority.urgent:
        return const Color(0xFFFEE2E2);
    }
  }
}
