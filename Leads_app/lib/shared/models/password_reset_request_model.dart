import 'package:cloud_firestore/cloud_firestore.dart';

class PasswordResetRequestModel {
  final String requestId;
  final String companyId;
  final String employeeUid;
  final String employeeId;
  final String employeeName;
  final String? department;
  final String? registeredMobile;
  final String reason;
  final String requestType; // 'PASSWORD_RESET', 'RECOVERY_CODE_RESET'
  final List<String> assignedRecipients;
  final DateTime? updatedAt;
  final String status; // 'Pending', 'Approved', 'Rejected', 'Completed', 'Expired', 'Cancelled'
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? reviewedByUid;
  final String? reviewedByName;
  final String? reviewedByRole;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime? tempPasswordGeneratedAt;
  final DateTime? completedAt;

  PasswordResetRequestModel({
    required this.requestId,
    required this.companyId,
    required this.employeeUid,
    required this.employeeId,
    required this.employeeName,
    this.department,
    this.registeredMobile,
    required this.reason,
    this.requestType = 'PASSWORD_RESET',
    this.assignedRecipients = const [],
    this.updatedAt,
    this.status = 'Pending',
    required this.createdAt,
    required this.expiresAt,
    this.reviewedByUid,
    this.reviewedByName,
    this.reviewedByRole,
    this.reviewedAt,
    this.rejectionReason,
    this.tempPasswordGeneratedAt,
    this.completedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt) && status == 'Pending';

  factory PasswordResetRequestModel.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] != null
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    final expiresAt = map['expiresAt'] != null
        ? (map['expiresAt'] as Timestamp).toDate()
        : createdAt.add(const Duration(hours: 24));

    String status = map['status'] ?? 'Pending';
    if (status == 'Pending' && DateTime.now().isAfter(expiresAt)) {
      status = 'Expired';
    }

    return PasswordResetRequestModel(
      requestId: map['requestId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeUid: map['employeeUid'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      department: map['department'],
      registeredMobile: map['registeredMobile'],
      reason: map['reason'] ?? '',
      requestType: map['requestType'] ?? 'PASSWORD_RESET',
      assignedRecipients: (map['assignedRecipients'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      status: status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      reviewedByUid: map['reviewedByUid'],
      reviewedByName: map['reviewedByName'],
      reviewedByRole: map['reviewedByRole'],
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: map['rejectionReason'],
      tempPasswordGeneratedAt: map['tempPasswordGeneratedAt'] != null
          ? (map['tempPasswordGeneratedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'companyId': companyId,
      'employeeUid': employeeUid,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'department': department,
      'registeredMobile': registeredMobile,
      'reason': reason,
      'requestType': requestType,
      'assignedRecipients': assignedRecipients,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'reviewedByUid': reviewedByUid,
      'reviewedByName': reviewedByName,
      'reviewedByRole': reviewedByRole,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'rejectionReason': rejectionReason,
      'tempPasswordGeneratedAt': tempPasswordGeneratedAt != null
          ? Timestamp.fromDate(tempPasswordGeneratedAt!)
          : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  PasswordResetRequestModel copyWith({
    String? requestId,
    String? companyId,
    String? employeeUid,
    String? employeeId,
    String? employeeName,
    String? department,
    String? registeredMobile,
    String? reason,
    String? requestType,
    List<String>? assignedRecipients,
    DateTime? updatedAt,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? reviewedByUid,
    String? reviewedByName,
    String? reviewedByRole,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? tempPasswordGeneratedAt,
    DateTime? completedAt,
  }) {
    return PasswordResetRequestModel(
      requestId: requestId ?? this.requestId,
      companyId: companyId ?? this.companyId,
      employeeUid: employeeUid ?? this.employeeUid,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      registeredMobile: registeredMobile ?? this.registeredMobile,
      reason: reason ?? this.reason,
      requestType: requestType ?? this.requestType,
      assignedRecipients: assignedRecipients ?? this.assignedRecipients,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      reviewedByUid: reviewedByUid ?? this.reviewedByUid,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedByRole: reviewedByRole ?? this.reviewedByRole,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      tempPasswordGeneratedAt: tempPasswordGeneratedAt ?? this.tempPasswordGeneratedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
