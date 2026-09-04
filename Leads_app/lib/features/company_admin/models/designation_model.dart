import 'package:cloud_firestore/cloud_firestore.dart';

class DesignationModel {
  final String designationId;
  final String companyId;
  final String designationName;
  final int designationLevel;
  final String departmentId;
  final List<String> managedDepartmentIds;
  final bool canManageDepartments;
  final String description;
  final String status; // 'active', 'suspended', 'deleted'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Backwards compatibility & Helper getters
  int get level => designationLevel;
  String get name => designationName;

  List<String> get applicableDepartmentIds {
    if (managedDepartmentIds.isNotEmpty) return managedDepartmentIds;
    if (departmentId.isNotEmpty) return [departmentId];
    return const [];
  }

  bool get isManagerial {
    if (canManageDepartments) return true;
    final lower = designationName.toLowerCase();
    return lower.contains('manager') ||
        lower.contains('lead') ||
        lower.contains('head') ||
        lower.contains('supervisor') ||
        lower.contains('director') ||
        lower.contains('vp') ||
        lower.contains('chief');
  }

  DesignationModel({
    required this.designationId,
    required this.companyId,
    required this.designationName,
    required this.designationLevel,
    this.departmentId = '',
    this.managedDepartmentIds = const [],
    this.canManageDepartments = false,
    this.description = '',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory DesignationModel.fromMap(Map<String, dynamic> map) {
    final rawManaged = map['managedDepartmentIds'];
    final List<String> parsedManaged = rawManaged is List
        ? rawManaged.map((e) => e.toString()).toList()
        : [];

    final rawDeptId = (map['departmentId'] ?? '').toString();
    if (parsedManaged.isEmpty && rawDeptId.isNotEmpty) {
      parsedManaged.add(rawDeptId);
    }

    return DesignationModel(
      designationId: map['designationId'] ?? '',
      companyId: map['companyId'] ?? '',
      designationName: map['designationName'] ?? '',
      designationLevel: map['designationLevel'] != null
          ? (map['designationLevel'] as num).toInt()
          : (map['level'] != null ? (map['level'] as num).toInt() : 1),
      departmentId: rawDeptId.isNotEmpty
          ? rawDeptId
          : (parsedManaged.isNotEmpty ? parsedManaged.first : ''),
      managedDepartmentIds: parsedManaged,
      canManageDepartments: map['canManageDepartments'] ?? map['isManagerial'] ?? false,
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
    final effectiveDeptId = departmentId.isNotEmpty
        ? departmentId
        : (managedDepartmentIds.isNotEmpty ? managedDepartmentIds.first : '');
    return {
      'designationId': designationId,
      'companyId': companyId,
      'designationName': designationName,
      'designationLevel': designationLevel,
      'departmentId': effectiveDeptId,
      'managedDepartmentIds': managedDepartmentIds,
      'canManageDepartments': canManageDepartments,
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
    List<String>? managedDepartmentIds,
    bool? canManageDepartments,
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
      managedDepartmentIds: managedDepartmentIds ?? this.managedDepartmentIds,
      canManageDepartments: canManageDepartments ?? this.canManageDepartments,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
