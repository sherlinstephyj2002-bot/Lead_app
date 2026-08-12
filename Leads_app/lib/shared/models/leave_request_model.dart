import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String leaveRequestId;
  final String companyId;
  final String employeeId;
  final String leaveTypeId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalDays;
  final String reason;
  final String status; // Pending, Approved, Rejected, Cancelled
  final String? managerId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  LeaveRequestModel({
    required this.leaveRequestId,
    required this.companyId,
    required this.employeeId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    this.managerId,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map) {
    return LeaveRequestModel(
      leaveRequestId: map['leaveRequestId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      leaveTypeId: map['leaveTypeId'] ?? '',
      fromDate: map['fromDate'] != null ? (map['fromDate'] as Timestamp).toDate() : DateTime.now(),
      toDate: map['toDate'] != null ? (map['toDate'] as Timestamp).toDate() : DateTime.now(),
      totalDays: map['totalDays'] != null ? (map['totalDays'] as num).toInt() : 0,
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'Pending',
      managerId: map['managerId'],
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null ? (map['approvedAt'] as Timestamp).toDate() : null,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveRequestId': leaveRequestId,
      'companyId': companyId,
      'employeeId': employeeId,
      'leaveTypeId': leaveTypeId,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'totalDays': totalDays,
      'reason': reason,
      'status': status,
      'managerId': managerId,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  LeaveRequestModel copyWith({
    String? leaveRequestId,
    String? companyId,
    String? employeeId,
    String? leaveTypeId,
    DateTime? fromDate,
    DateTime? toDate,
    int? totalDays,
    String? reason,
    String? status,
    String? managerId,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
  }) {
    return LeaveRequestModel(
      leaveRequestId: leaveRequestId ?? this.leaveRequestId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      managerId: managerId ?? this.managerId,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
