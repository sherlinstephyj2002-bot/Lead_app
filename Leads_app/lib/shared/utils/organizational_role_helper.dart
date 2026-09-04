import '../../../shared/models/department_model.dart';
import '../../features/company_admin/models/designation_model.dart';
import '../../features/company_admin/models/role_model.dart';

/// Helper to generate and resolve available roles for any Department + Designation combination.
/// Guarantees that the Role dropdown is always populated with meaningful organizational
/// role options even if no custom role name was typed during setup.
class OrganizationalRoleHelper {
  static List<RoleModel> getAvailableRoles({
    required DepartmentModel? department,
    required DesignationModel? designation,
    required List<RoleModel> allRoles,
  }) {
    if (department == null || designation == null) {
      return const [];
    }

    final result = <RoleModel>[];
    final seenNames = <String>{};

    // 1. Include explicit custom roles matching this org assignment
    final matchingCustom = allRoles.where((r) {
      return r.matchesOrgAssignment(department.departmentId, designation.designationId);
    }).toList();

    for (final role in matchingCustom) {
      if (role.roleName.trim().isNotEmpty && seenNames.add(role.roleName.trim().toLowerCase())) {
        result.add(role);
      }
    }

    // 2. Generate organizational role option: "DesignationName – DepartmentName"
    final orgRoleName = '${designation.designationName} – ${department.departmentName}';
    if (seenNames.add(orgRoleName.toLowerCase())) {
      result.add(RoleModel(
        roleId: 'org_${department.departmentId}_${designation.designationId}',
        companyId: department.companyId,
        roleName: orgRoleName,
        departmentId: department.departmentId,
        designationId: designation.designationId,
        departmentIds: [department.departmentId],
        designationIds: [designation.designationId],
        organizationalAssignments: [
          RoleOrganizationalAssignment(
            departmentId: department.departmentId,
            designationId: designation.designationId,
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // 3. Include Designation Name alone
    if (seenNames.add(designation.designationName.trim().toLowerCase())) {
      result.add(RoleModel(
        roleId: 'desig_${designation.designationId}',
        companyId: designation.companyId,
        roleName: designation.designationName.trim(),
        departmentId: department.departmentId,
        designationId: designation.designationId,
        departmentIds: [department.departmentId],
        designationIds: [designation.designationId],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return result;
  }
}
