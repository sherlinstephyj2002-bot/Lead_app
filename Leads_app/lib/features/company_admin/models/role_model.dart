import 'package:cloud_firestore/cloud_firestore.dart';

/// Preserves the organizational mapping between Department and Designation for a Role.
class RoleOrganizationalAssignment {
  final String departmentId;
  final String designationId;

  RoleOrganizationalAssignment({
    required this.departmentId,
    required this.designationId,
  });

  factory RoleOrganizationalAssignment.fromMap(Map<String, dynamic> map) {
    return RoleOrganizationalAssignment(
      departmentId: map['departmentId'] ?? '',
      designationId: map['designationId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departmentId': departmentId,
      'designationId': designationId,
    };
  }
}

class RoleModel {
  final String roleId;
  final String companyId;
  final String roleName;
  final String departmentId; // Backwards compatibility
  final String designationId; // Backwards compatibility
  final List<String> departmentIds;
  final List<String> designationIds;
  final List<RoleOrganizationalAssignment> organizationalAssignments;
  final String description;
  final String status; // 'active', 'suspended', 'archived', 'deleted'
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get applicableDepartmentIds {
    if (departmentIds.isNotEmpty) return departmentIds;
    if (organizationalAssignments.isNotEmpty) {
      return organizationalAssignments.map((a) => a.departmentId).where((id) => id.isNotEmpty).toSet().toList();
    }
    if (departmentId.isNotEmpty) return [departmentId];
    return const [];
  }

  List<String> get applicableDesignationIds {
    if (designationIds.isNotEmpty) return designationIds;
    if (organizationalAssignments.isNotEmpty) {
      return organizationalAssignments.map((a) => a.designationId).where((id) => id.isNotEmpty).toSet().toList();
    }
    if (designationId.isNotEmpty) return [designationId];
    return const [];
  }

  /// Checks whether this role is valid for a given Department ID + Designation ID combination.
  bool matchesOrgAssignment(String deptId, String desigId) {
    if (organizationalAssignments.isNotEmpty) {
      return organizationalAssignments.any((a) =>
          (a.departmentId.isEmpty || a.departmentId == 'all' || a.departmentId == deptId) &&
          (a.designationId.isEmpty || a.designationId == 'all' || a.designationId == desigId));
    }
    final deptMatch = departmentId.isEmpty || departmentId == 'all' || departmentId == deptId || (departmentIds.isNotEmpty && departmentIds.contains(deptId));
    final desigMatch = designationId.isEmpty || designationId == 'all' || designationId == desigId || (designationIds.isNotEmpty && designationIds.contains(desigId));
    return deptMatch && desigMatch;
  }

  RoleModel({
    required this.roleId,
    required this.companyId,
    required this.roleName,
    this.departmentId = '',
    this.designationId = '',
    this.departmentIds = const [],
    this.designationIds = const [],
    this.organizationalAssignments = const [],
    this.description = '',
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoleModel.fromMap(Map<String, dynamic> map) {
    final rawOrg = map['organizationalAssignments'];
    final List<RoleOrganizationalAssignment> orgAssignments = rawOrg is List
        ? rawOrg.map((e) => RoleOrganizationalAssignment.fromMap(Map<String, dynamic>.from(e))).toList()
        : [];

    final rawDeptIds = map['departmentIds'];
    final List<String> parsedDeptIds = rawDeptIds is List ? rawDeptIds.map((e) => e.toString()).toList() : [];

    final rawDesigIds = map['designationIds'];
    final List<String> parsedDesigIds = rawDesigIds is List ? rawDesigIds.map((e) => e.toString()).toList() : [];

    final singleDept = (map['departmentId'] ?? '').toString();
    final singleDesig = (map['designationId'] ?? '').toString();

    if (parsedDeptIds.isEmpty && singleDept.isNotEmpty) {
      parsedDeptIds.add(singleDept);
    }
    if (parsedDesigIds.isEmpty && singleDesig.isNotEmpty) {
      parsedDesigIds.add(singleDesig);
    }

    return RoleModel(
      roleId: map['roleId'] ?? '',
      companyId: map['companyId'] ?? '',
      roleName: map['roleName'] ?? '',
      departmentId: singleDept.isNotEmpty ? singleDept : (parsedDeptIds.isNotEmpty ? parsedDeptIds.first : ''),
      designationId: singleDesig.isNotEmpty ? singleDesig : (parsedDesigIds.isNotEmpty ? parsedDesigIds.first : ''),
      departmentIds: parsedDeptIds,
      designationIds: parsedDesigIds,
      organizationalAssignments: orgAssignments,
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
    final effectiveDept = departmentId.isNotEmpty ? departmentId : (departmentIds.isNotEmpty ? departmentIds.first : '');
    final effectiveDesig = designationId.isNotEmpty ? designationId : (designationIds.isNotEmpty ? designationIds.first : '');

    return {
      'roleId': roleId,
      'companyId': companyId,
      'roleName': roleName,
      'departmentId': effectiveDept,
      'designationId': effectiveDesig,
      'departmentIds': departmentIds,
      'designationIds': designationIds,
      'organizationalAssignments': organizationalAssignments.map((a) => a.toMap()).toList(),
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RoleModel copyWith({
    String? roleId,
    String? companyId,
    String? roleName,
    String? departmentId,
    String? designationId,
    List<String>? departmentIds,
    List<String>? designationIds,
    List<RoleOrganizationalAssignment>? organizationalAssignments,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoleModel(
      roleId: roleId ?? this.roleId,
      companyId: companyId ?? this.companyId,
      roleName: roleName ?? this.roleName,
      departmentId: departmentId ?? this.departmentId,
      designationId: designationId ?? this.designationId,
      departmentIds: departmentIds ?? this.departmentIds,
      designationIds: designationIds ?? this.designationIds,
      organizationalAssignments: organizationalAssignments ?? this.organizationalAssignments,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

