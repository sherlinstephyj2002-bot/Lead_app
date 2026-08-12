import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String departmentId;
  final String companyId;
  final String departmentName;
  final String departmentCode;
  final String description;
  final String? managerId;
  final String status; // 'active', 'suspended', 'deleted', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? branchId;
  final String? branchName;

  // Backwards compatibility getter
  String get name => departmentName;

  DepartmentModel({
    required this.departmentId,
    required this.companyId,
    required this.departmentName,
    required this.departmentCode,
    this.description = '',
    this.managerId,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.branchId,
    this.branchName,
  });

  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    return DepartmentModel(
      departmentId: map['departmentId'] ?? '',
      companyId: map['companyId'] ?? '',
      departmentName: map['departmentName'] ?? map['name'] ?? '',
      departmentCode: map['departmentCode'] ?? '',
      description: map['description'] ?? '',
      managerId: map['managerId'],
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      branchId: map['branchId'],
      branchName: map['branchName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departmentId': departmentId,
      'companyId': companyId,
      'departmentName': departmentName,
      'departmentCode': departmentCode,
      'description': description,
      'managerId': managerId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'branchId': branchId,
      'branchName': branchName,
    };
  }

  DepartmentModel copyWith({
    String? departmentId,
    String? companyId,
    String? departmentName,
    String? departmentCode,
    String? description,
    String? managerId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? branchId,
    String? branchName,
  }) {
    return DepartmentModel(
      departmentId: departmentId ?? this.departmentId,
      companyId: companyId ?? this.companyId,
      departmentName: departmentName ?? this.departmentName,
      departmentCode: departmentCode ?? this.departmentCode,
      description: description ?? this.description,
      managerId: managerId ?? this.managerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
    );
  }
}
