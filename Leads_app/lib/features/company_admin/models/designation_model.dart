import 'package:cloud_firestore/cloud_firestore.dart';

class DesignationModel {
  final String designationId;
  final String companyId;
  final String designationName;
  final int designationLevel;
  final String departmentId;
  final String description;
  final String status; // 'active', 'suspended', 'deleted'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Backwards compatibility getters
  int get level => designationLevel;
  String get name => designationName;

  DesignationModel({
    required this.designationId,
    required this.companyId,
    required this.designationName,
    required this.designationLevel,
    required this.departmentId,
    this.description = '',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory DesignationModel.fromMap(Map<String, dynamic> map) {
    return DesignationModel(
      designationId: map['designationId'] ?? '',
      companyId: map['companyId'] ?? '',
      designationName: map['designationName'] ?? '',
      designationLevel: map['designationLevel'] != null
          ? (map['designationLevel'] as num).toInt()
          : (map['level'] != null ? (map['level'] as num).toInt() : 1),
      departmentId: map['departmentId'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'designationId': designationId,
      'companyId': companyId,
      'designationName': designationName,
      'designationLevel': designationLevel,
      'departmentId': departmentId,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DesignationModel copyWith({
    String? designationId,
    String? companyId,
    String? designationName,
    int? designationLevel,
    String? departmentId,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DesignationModel(
      designationId: designationId ?? this.designationId,
      companyId: companyId ?? this.companyId,
      designationName: designationName ?? this.designationName,
      designationLevel: designationLevel ?? this.designationLevel,
      departmentId: departmentId ?? this.departmentId,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
