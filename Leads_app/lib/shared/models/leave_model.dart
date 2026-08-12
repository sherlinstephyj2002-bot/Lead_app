import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String leaveId;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String type; // 'Casual', 'Sick', 'Earned', 'Paternity', 'Others'
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime createdAt;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? updatedAt;

  LeaveModel({
    required this.leaveId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.approvedBy,
    this.approvedByName,
    this.updatedAt,
  });

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      leaveId: map['leaveId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      type: map['type'] ?? 'Casual',
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      approvedBy: map['approvedBy'],
      approvedByName: map['approvedByName'],
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveId': leaveId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  LeaveModel copyWith({
    String? leaveId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? status,
    DateTime? createdAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? updatedAt,
  }) {
    return LeaveModel(
      leaveId: leaveId ?? this.leaveId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
