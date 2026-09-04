import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit trail for attendance automation events (reminders, auto-absent, auto-checkout, supervisor verification).
class AttendanceAutomationLogModel {
  final String logId;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String userEmployeeId;
  final String action; // 'Check-in Reminder', 'Auto Absent', 'Check-out Reminder', 'Field Verification Required', 'System Auto Checkout'
  final String triggeredBy; // 'System', 'Employee', 'HR', 'Manager', 'Company Admin'
  final String details;
  final List<String> notificationRecipients;
  final DateTime timestamp;

  AttendanceAutomationLogModel({
    required this.logId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.userEmployeeId,
    required this.action,
    required this.triggeredBy,
    required this.details,
    required this.notificationRecipients,
    required this.timestamp,
  });

  factory AttendanceAutomationLogModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return AttendanceAutomationLogModel(
      logId: map['logId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      userEmployeeId: map['userEmployeeId'] ?? '',
      action: map['action'] ?? '',
      triggeredBy: map['triggeredBy'] ?? 'System',
      details: map['details'] ?? '',
      notificationRecipients: (map['notificationRecipients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      timestamp: parseDate(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'userEmployeeId': userEmployeeId,
      'action': action,
      'triggeredBy': triggeredBy,
      'details': details,
      'notificationRecipients': notificationRecipients,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
