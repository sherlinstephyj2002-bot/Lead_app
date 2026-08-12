import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryComponentAuditLogModel {
  final String logId;
  final String companyId;
  final String componentId;
  final String componentName;
  final String action; // 'Create', 'Edit', 'Archive', 'Restore'
  final String details;
  final String performedBy;
  final DateTime timestamp;

  SalaryComponentAuditLogModel({
    required this.logId,
    required this.companyId,
    required this.componentId,
    required this.componentName,
    required this.action,
    required this.details,
    required this.performedBy,
    required this.timestamp,
  });

  factory SalaryComponentAuditLogModel.fromMap(Map<String, dynamic> map) {
    return SalaryComponentAuditLogModel(
      logId: map['logId'] ?? '',
      companyId: map['companyId'] ?? '',
      componentId: map['componentId'] ?? '',
      componentName: map['componentName'] ?? '',
      action: map['action'] ?? '',
      details: map['details'] ?? '',
      performedBy: map['performedBy'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(map['timestamp'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'companyId': companyId,
      'componentId': componentId,
      'componentName': componentName,
      'action': action,
      'details': details,
      'performedBy': performedBy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
