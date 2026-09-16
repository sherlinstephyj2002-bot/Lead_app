import 'package:cloud_firestore/cloud_firestore.dart';

class PasswordResetAuditLogModel {
  final String logId;
  final String companyId;
  final String requestId;
  final String employeeId;
  final String employeeName;
  final String action; // 'REQUESTED', 'REVIEWED', 'APPROVED', 'REJECTED', 'TEMPORARY_PASSWORD_GENERATED', 'TEMPORARY_PASSWORD_RESET_COMPLETED', 'EMPLOYEE_CHANGED_PASSWORD'
  final String triggeredBy; // 'Employee', 'HR', 'Reporting Manager', 'Team Leader', 'Company Admin', 'System'
  final String? triggeredByUid;
  final String? triggeredByName;
  final DateTime timestamp;
  final String? details;

  PasswordResetAuditLogModel({
    required this.logId,
    required this.companyId,
    required this.requestId,
    required this.employeeId,
    required this.employeeName,
    required this.action,
    required this.triggeredBy,
    this.triggeredByUid,
    this.triggeredByName,
    required this.timestamp,
    this.details,
  });

  factory PasswordResetAuditLogModel.fromMap(Map<String, dynamic> map) {
    return PasswordResetAuditLogModel(
      logId: map['logId'] ?? '',
      companyId: map['companyId'] ?? '',
      requestId: map['requestId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      action: map['action'] ?? '',
      triggeredBy: map['triggeredBy'] ?? 'System',
      triggeredByUid: map['triggeredByUid'],
      triggeredByName: map['triggeredByName'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      details: map['details'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'companyId': companyId,
      'requestId': requestId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'action': action,
      'triggeredBy': triggeredBy,
      'triggeredByUid': triggeredByUid,
      'triggeredByName': triggeredByName,
      'timestamp': Timestamp.fromDate(timestamp),
      'details': details,
    };
  }
}
