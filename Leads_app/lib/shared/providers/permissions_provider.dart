import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/constants/user_roles.dart';

class PermissionModel {
  final String roleName;
  final List<String> permissions;
  final String companyId;

  PermissionModel({
    required this.roleName,
    required this.permissions,
    required this.companyId,
  });

  factory PermissionModel.fromMap(Map<String, dynamic> map) {
    return PermissionModel(
      roleName: map['roleName'] ?? '',
      permissions: List<String>.from(map['permissions'] ?? []),
      companyId: map['companyId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roleName': roleName,
      'permissions': permissions,
      'companyId': companyId,
    };
  }
}

class PermissionService {
  final List<String> permissions;
  PermissionService(this.permissions);

  bool hasPermission(String permission) {
    final normInput = permission.replaceAll('.', '_');
    return permissions.any((p) {
      final normP = p.replaceAll('.', '_');
      return normP == normInput;
    });
  }

  bool hasAnyPermission(List<String> list) {
    return list.any((p) => hasPermission(p));
  }
}

// Map containing default permissions for each role
const Map<String, List<String>> defaultRolePermissions = {
  UserRoles.superAdmin: [
    'employee_create', 'employee_edit', 'employee_delete', 'employee_view',
    'department_create', 'department_edit', 'department_delete',
    'attendance_view', 'attendance_approve', 'attendance_correct',
    'leave_apply', 'leave_approve', 'leave_reject',
    'payroll_view', 'payroll_generate', 'payroll_approve', 'payroll_manage',
    'reports_view', 'reports_export', 'settings_manage',
    'lead_view', 'lead_create', 'lead_edit', 'lead_delete', 'lead_convert_order',
    'followup_view', 'followup_create', 'followup_edit', 'followup_complete', 'followup_delete',
    'order_view', 'order_create', 'order_edit', 'order_delete', 'order_close', 'order_cancel',
    'task_view', 'task_create', 'task_edit', 'task_delete', 'task_assign', 'task_complete', 'task_reassign'
  ],
  UserRoles.companyAdmin: [
    'employee_create', 'employee_edit', 'employee_delete', 'employee_view',
    'department_create', 'department_edit', 'department_delete',
    'designation_create', 'designation_edit', 'designation_delete',
    'attendance_view', 'attendance_approve', 'attendance_correct',
    'leave_apply', 'leave_approve', 'leave_reject',
    'hr_manage',
    'payroll_view', 'payroll_generate', 'payroll_approve', 'payroll_manage',
    'reports_view', 'reports_export', 'settings_manage',
    'subscription_view',
    'lead_view', 'lead_create', 'lead_edit', 'lead_delete', 'lead_convert_order',
    'followup_view', 'followup_create', 'followup_edit', 'followup_complete', 'followup_delete',
    'order_view', 'order_create', 'order_edit', 'order_delete', 'order_close', 'order_cancel',
    'task_view', 'task_create', 'task_edit', 'task_delete', 'task_assign', 'task_complete', 'task_reassign'
  ],
  UserRoles.hr: [
    'employee_create', 'employee_edit', 'employee_delete', 'employee_view',
    'department_create', 'department_edit', 'department_delete',
    'attendance_view', 'attendance_approve', 'attendance_correct',
    'leave_apply', 'leave_approve', 'leave_reject',
    'payroll_view', 'payroll_generate', 'payroll_approve', 'payroll_manage',
    'reports_view', 'reports_export', 'settings_manage'
  ],
  UserRoles.hrAdmin: [
    'employee_create', 'employee_edit', 'employee_delete', 'employee_view',
    'department_create', 'department_edit', 'department_delete',
    'attendance_view', 'attendance_approve', 'attendance_correct',
    'leave_apply', 'leave_approve', 'leave_reject',
    'payroll_view', 'payroll_generate', 'payroll_approve', 'payroll_manage',
    'reports_view', 'reports_export', 'settings_manage'
  ],
  UserRoles.hrExecutive: [
    'employee_create', 'employee_edit', 'employee_view',
    'attendance_view', 'attendance_correct', 'leave_apply', 'leave_approve', 'reports_view'
  ],
  UserRoles.manager: [
    'employee_view', 'attendance_view', 'leave_apply', 'leave_approve', 'leave_reject', 'reports_view',
    'lead_view', 'lead_create', 'lead_edit', 'lead_delete', 'lead_convert_order',
    'followup_view', 'followup_create', 'followup_edit', 'followup_complete', 'followup_delete',
    'order_view', 'order_create', 'order_edit', 'order_close', 'order_cancel',
    'task_view', 'task_create', 'task_edit', 'task_delete', 'task_assign', 'task_complete', 'task_reassign'
  ],
  UserRoles.teamLeader: [
    'employee_view', 'attendance_view', 'leave_apply', 'leave_approve',
    'lead_view', 'lead_create', 'lead_edit',
    'followup_view', 'followup_create', 'followup_edit', 'followup_complete',
    'order_view', 'order_create', 'order_edit',
    'task_view', 'task_create', 'task_edit', 'task_assign', 'task_complete'
  ],
  UserRoles.employee: [
    'employee_view', 'attendance_view', 'leave_apply',
    'lead_view', 'lead_create', 'lead_edit',
    'followup_view', 'followup_create', 'followup_complete',
    'task_view', 'task_create', 'task_complete'
  ],
};

Future<void> seedDefaultRolesAndPermissions(String companyId) async {
  if (companyId.isEmpty) return;

  final db = FirebaseFirestore.instance;
  try {
    // 1. Check if permissions are seeded in permissions collection
    final permissionsCount = await db.collection('permissions').limit(1).get();
    if (permissionsCount.docs.isEmpty) {
      final allPermissions = [
        {'id': 'employee_view', 'module': 'Employee', 'action': 'View'},
        {'id': 'employee_create', 'module': 'Employee', 'action': 'Create'},
        {'id': 'employee_edit', 'module': 'Employee', 'action': 'Edit'},
        {'id': 'employee_delete', 'module': 'Employee', 'action': 'Delete'},
        {'id': 'department_create', 'module': 'Department', 'action': 'Create'},
        {'id': 'department_edit', 'module': 'Department', 'action': 'Edit'},
        {'id': 'department_delete', 'module': 'Department', 'action': 'Delete'},
        {'id': 'attendance_view', 'module': 'Attendance', 'action': 'View'},
        {'id': 'attendance_approve', 'module': 'Attendance', 'action': 'Approve'},
        {'id': 'attendance_correct', 'module': 'Attendance', 'action': 'Correct'},
        {'id': 'leave_apply', 'module': 'Leave', 'action': 'Apply'},
        {'id': 'leave_approve', 'module': 'Leave', 'action': 'Approve'},
        {'id': 'leave_reject', 'module': 'Leave', 'action': 'Reject'},
        {'id': 'payroll_view', 'module': 'Payroll', 'action': 'View'},
        {'id': 'payroll_generate', 'module': 'Payroll', 'action': 'Generate'},
        {'id': 'payroll_approve', 'module': 'Payroll', 'action': 'Approve'},
        {'id': 'payroll_manage', 'module': 'Payroll', 'action': 'Manage'},
        {'id': 'reports_view', 'module': 'Reports', 'action': 'View'},
        {'id': 'reports_export', 'module': 'Reports', 'action': 'Export'},
        {'id': 'settings_manage', 'module': 'Settings', 'action': 'Manage'},

        // Lead permissions
        {'id': 'lead_view', 'module': 'Lead', 'action': 'View'},
        {'id': 'lead_create', 'module': 'Lead', 'action': 'Create'},
        {'id': 'lead_edit', 'module': 'Lead', 'action': 'Edit'},
        {'id': 'lead_delete', 'module': 'Lead', 'action': 'Delete'},
        {'id': 'lead_convert_order', 'module': 'Lead', 'action': 'Convert to Order'},

        // Follow-up permissions
        {'id': 'followup_view', 'module': 'Follow-up', 'action': 'View'},
        {'id': 'followup_create', 'module': 'Follow-up', 'action': 'Create'},
        {'id': 'followup_edit', 'module': 'Follow-up', 'action': 'Edit'},
        {'id': 'followup_complete', 'module': 'Follow-up', 'action': 'Complete'},
        {'id': 'followup_delete', 'module': 'Follow-up', 'action': 'Delete'},

        // Order permissions
        {'id': 'order_view', 'module': 'Orders', 'action': 'View'},
        {'id': 'order_create', 'module': 'Orders', 'action': 'Create'},
        {'id': 'order_edit', 'module': 'Orders', 'action': 'Edit'},
        {'id': 'order_delete', 'module': 'Orders', 'action': 'Delete'},
        {'id': 'order_close', 'module': 'Orders', 'action': 'Close'},
        {'id': 'order_cancel', 'module': 'Orders', 'action': 'Cancel'},

        // Task permissions
        {'id': 'task_view', 'module': 'Task', 'action': 'View'},
        {'id': 'task_create', 'module': 'Task', 'action': 'Create'},
        {'id': 'task_edit', 'module': 'Task', 'action': 'Edit'},
        {'id': 'task_delete', 'module': 'Task', 'action': 'Delete'},
        {'id': 'task_assign', 'module': 'Task', 'action': 'Assign'},
        {'id': 'task_complete', 'module': 'Task', 'action': 'Complete'},
        {'id': 'task_reassign', 'module': 'Task', 'action': 'Reassign'},
      ];

      final batch = db.batch();
      for (final p in allPermissions) {
        batch.set(db.collection('permissions').doc(p['id']!), {
          'permissionId': p['id'],
          'module': p['module'],
          'action': p['action'],
        });
      }
      await batch.commit();
    }

    // 2. Check if roles are seeded for this company
    final rolesCount = await db
        .collection('roles')
        .where('companyId', isEqualTo: companyId)
        .limit(1)
        .get();

    if (rolesCount.docs.isEmpty) {
      final systemRoles = [
        {
          'id': '${companyId}_company_admin',
          'roleName': 'Company Admin',
          'description': 'Full control over company settings and data.',
          'isSystemRole': true,
          'perms': defaultRolePermissions[UserRoles.companyAdmin] ?? []
        },
        {
          'id': '${companyId}_hr_admin',
          'roleName': 'HR Admin',
          'description': 'Manage employee records, attendance, and leave approvals.',
          'isSystemRole': true,
          'perms': defaultRolePermissions[UserRoles.hrAdmin] ?? []
        },
        {
          'id': '${companyId}_hr_executive',
          'roleName': 'HR Executive',
          'description': 'Onboard employees, view attendance, and process leave requests.',
          'isSystemRole': true,
          'perms': defaultRolePermissions[UserRoles.hrExecutive] ?? []
        },
        {
          'id': '${companyId}_employee',
          'roleName': 'Employee',
          'description': 'Standard employee access (View directory, apply leaves).',
          'isSystemRole': true,
          'perms': defaultRolePermissions[UserRoles.employee] ?? []
        },
      ];

      final batch = db.batch();
      for (final r in systemRoles) {
        batch.set(db.collection('roles').doc(r['id'] as String), {
          'roleId': r['id'],
          'companyId': companyId,
          'roleName': r['roleName'],
          'description': r['description'],
          'isSystemRole': r['isSystemRole'],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final permsList = r['perms'] as List<String>;
        for (final p in permsList) {
          final mappingId = '${r['id']}_$p';
          batch.set(db.collection('role_permissions').doc(mappingId), {
            'roleId': r['id'],
            'permissionId': p,
          });
        }
      }
      await batch.commit();
    }
  } catch (e) {
    debugPrint('Failed to seed default roles and permissions: $e');
  }
}

String _normalizeRoleStr(String r) => r.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();

// StreamProvider that fetches permissions dynamically from Firestore
final userPermissionsProvider = StreamProvider<List<String>>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null) {
    return Stream.value([]);
  }

  // Seeding run in background
  seedDefaultRolesAndPermissions(user.companyId);

  // Fetch dynamic permissions from roles & role_permissions collections
  return FirebaseFirestore.instance
      .collection('roles')
      .where('companyId', isEqualTo: user.companyId)
      .snapshots()
      .asyncMap((rolesSnapshot) async {
        final targetRoleNorm = _normalizeRoleStr(user.role);
        final match = rolesSnapshot.docs.where((doc) {
          final name = doc.data()['roleName'] ?? '';
          return _normalizeRoleStr(name.toString()) == targetRoleNorm;
        });

        if (match.isEmpty) {
          // System fallback
          return defaultRolePermissions[user.role] ?? [];
        }

        final roleDoc = match.first;
        final roleId = roleDoc.id;

        final permsQuery = await FirebaseFirestore.instance
            .collection('role_permissions')
            .where('roleId', isEqualTo: roleId)
            .get();

        return permsQuery.docs.map((doc) => doc.data()['permissionId'] as String).toList();
      });
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  final permissions = ref.watch(userPermissionsProvider).value ?? [];
  
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user != null && user.role == UserRoles.superAdmin) {
    return PermissionService(defaultRolePermissions[user.role] ?? []);
  }
  
  return PermissionService(permissions);
});
