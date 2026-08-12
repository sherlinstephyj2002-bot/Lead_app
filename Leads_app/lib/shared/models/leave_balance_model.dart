import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveBalanceModel {
  final String employeeId;
  final String companyId;
  final String leaveTypeId;
  final int allocated;
  final int used;
  final int remaining;
  final DateTime updatedAt;

  LeaveBalanceModel({
    required this.employeeId,
    required this.companyId,
    required this.leaveTypeId,
    required this.allocated,
    required this.used,
    required this.remaining,
    required this.updatedAt,
  });

  factory LeaveBalanceModel.fromMap(Map<String, dynamic> map) {
    return LeaveBalanceModel(
      employeeId: map['employeeId'] ?? '',
      companyId: map['companyId'] ?? '',
      leaveTypeId: map['leaveTypeId'] ?? '',
      allocated: map['allocated'] != null ? (map['allocated'] as num).toInt() : 0,
      used: map['used'] != null ? (map['used'] as num).toInt() : 0,
      remaining: map['remaining'] != null ? (map['remaining'] as num).toInt() : 0,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'companyId': companyId,
      'leaveTypeId': leaveTypeId,
      'allocated': allocated,
      'used': used,
      'remaining': remaining,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeaveBalanceModel copyWith({
    String? employeeId,
    String? companyId,
    String? leaveTypeId,
    int? allocated,
    int? used,
    int? remaining,
    DateTime? updatedAt,
  }) {
    return LeaveBalanceModel(
      employeeId: employeeId ?? this.employeeId,
      companyId: companyId ?? this.companyId,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      allocated: allocated ?? this.allocated,
      used: used ?? this.used,
      remaining: remaining ?? this.remaining,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
