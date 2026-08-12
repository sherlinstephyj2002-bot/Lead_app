import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeRequestModel {
  final String requestId;
  final String companyId;
  final String requestedBy;
  final String requestedByName;
  final String requestType; // "ADD_EMPLOYEE", "DELETE_EMPLOYEE"
  final String status; // "Pending", "Approved", "Rejected"
  final DateTime createdAt;
  
  // ADD_EMPLOYEE details
  final Map<String, dynamic>? employeeData;

  // DELETE_EMPLOYEE details
  final String? employeeId;
  final String? employeeName;

  // Audit details
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? reason;

  EmployeeRequestModel({
    required this.requestId,
    required this.companyId,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestType,
    required this.status,
    required this.createdAt,
    this.employeeData,
    this.employeeId,
    this.employeeName,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.reason,
  });

  factory EmployeeRequestModel.fromMap(Map<String, dynamic> map) {
    return EmployeeRequestModel(
      requestId: map['requestId'] ?? '',
      companyId: map['companyId'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      requestType: map['requestType'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      employeeData: map['employeeData'] != null ? Map<String, dynamic>.from(map['employeeData']) : null,
      employeeId: map['employeeId'],
      employeeName: map['employeeName'],
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null ? (map['approvedAt'] as Timestamp).toDate() : null,
      rejectedBy: map['rejectedBy'],
      rejectedAt: map['rejectedAt'] != null ? (map['rejectedAt'] as Timestamp).toDate() : null,
      reason: map['reason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'companyId': companyId,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'requestType': requestType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'employeeData': employeeData,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectedBy': rejectedBy,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'reason': reason,
    };
  }
}
