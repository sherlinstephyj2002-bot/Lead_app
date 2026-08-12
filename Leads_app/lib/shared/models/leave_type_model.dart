import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveTypeModel {
  final String leaveTypeId;
  final String companyId;
  final String leaveName;
  final int annualQuota;
  final bool carryForwardAllowed;
  final bool requiresApproval;
  final String status; // active, archived
  final DateTime createdAt;

  LeaveTypeModel({
    required this.leaveTypeId,
    required this.companyId,
    required this.leaveName,
    required this.annualQuota,
    required this.carryForwardAllowed,
    required this.requiresApproval,
    this.status = 'active',
    required this.createdAt,
  });

  factory LeaveTypeModel.fromMap(Map<String, dynamic> map) {
    return LeaveTypeModel(
      leaveTypeId: map['leaveTypeId'] ?? '',
      companyId: map['companyId'] ?? '',
      leaveName: map['leaveName'] ?? '',
      annualQuota: map['annualQuota'] != null ? (map['annualQuota'] as num).toInt() : 0,
      carryForwardAllowed: map['carryForwardAllowed'] ?? true,
      requiresApproval: map['requiresApproval'] ?? true,
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveTypeId': leaveTypeId,
      'companyId': companyId,
      'leaveName': leaveName,
      'annualQuota': annualQuota,
      'carryForwardAllowed': carryForwardAllowed,
      'requiresApproval': requiresApproval,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  LeaveTypeModel copyWith({
    String? leaveTypeId,
    String? companyId,
    String? leaveName,
    int? annualQuota,
    bool? carryForwardAllowed,
    bool? requiresApproval,
    String? status,
    DateTime? createdAt,
  }) {
    return LeaveTypeModel(
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      companyId: companyId ?? this.companyId,
      leaveName: leaveName ?? this.leaveName,
      annualQuota: annualQuota ?? this.annualQuota,
      carryForwardAllowed: carryForwardAllowed ?? this.carryForwardAllowed,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
