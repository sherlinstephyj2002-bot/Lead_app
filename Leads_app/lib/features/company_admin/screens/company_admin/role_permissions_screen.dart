import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/providers/permissions_provider.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/constants/firestore_collections.dart';
import 'package:worktrack/shared/utils/app_notification.dart';

class RolePermissionsScreen extends ConsumerStatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  ConsumerState<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  bool _isLoading = true;
  String? _selectedRoleId;
  String _selectedRoleName = '';
  String _selectedRoleDescription = '';
  DateTime? _selectedRoleCreatedAt;
  String _roleSearchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _roles = [];
  List<String> _selectedPermissions = [];
  Map<String, List<UserModel>> _assignedUsersByRole = {};

  // All permissions catalog grouped by module
  final Map<String, List<Map<String, String>>> _permissionModules = {
    'EMPLOYEES': [
      {'id': 'employee_view', 'name': 'View Employees', 'desc': 'Access employee directory and basic profile details.'},
      {'id': 'employee_create', 'name': 'Create Employees', 'desc': 'Onboard new employees and generate login credentials.'},
      {'id': 'employee_edit', 'name': 'Edit Employees', 'desc': 'Modify employee profiles, departments, and designations.'},
      {'id': 'employee_delete', 'name': 'Delete Employees', 'desc': 'Soft-delete or suspend employee accounts.'},
    ],
    'LEADS': [
      {'id': 'lead_view', 'name': 'View Leads', 'desc': 'Access lead lists, pipeline stages, and lead details.'},
      {'id': 'lead_create', 'name': 'Create Leads', 'desc': 'Add new sales leads into the system.'},
      {'id': 'lead_edit', 'name': 'Edit Leads', 'desc': 'Update lead info, status, estimated values, and assignees.'},
      {'id': 'lead_delete', 'name': 'Delete Leads', 'desc': 'Archive or remove lead records.'},
      {'id': 'lead_convert_order', 'name': 'Convert to Order', 'desc': 'Convert won sales leads into trackable client orders.'},
    ],
    'ORDERS': [
      {'id': 'order_view', 'name': 'View Orders', 'desc': 'Access orders dashboard, order lists, and project details.'},
      {'id': 'order_create', 'name': 'Create Orders', 'desc': 'Create new client orders into the system.'},
      {'id': 'order_edit', 'name': 'Edit Orders', 'desc': 'Modify order details, item entries, and assignees.'},
      {'id': 'order_delete', 'name': 'Delete Orders', 'desc': 'Delete or archive order records.'},
      {'id': 'order_close', 'name': 'Close Orders', 'desc': 'Mark active orders as completed/closed.'},
      {'id': 'order_cancel', 'name': 'Cancel Orders', 'desc': 'Cancel active or pending client orders.'},
    ],
    'ATTENDANCE': [
      {'id': 'attendance_view', 'name': 'View Attendance', 'desc': 'View daily attendance check-ins and hours logs.'},
      {'id': 'attendance_approve', 'name': 'Approve Attendance', 'desc': 'Approve regularizations or manager overrides.'},
      {'id': 'attendance_correct', 'name': 'Correct Logs', 'desc': 'Manually alter work shifts or check-in logs.'},
    ],
    'LEAVE': [
      {'id': 'leave_apply', 'name': 'Apply Leaves', 'desc': 'Submit personal leave requests.'},
      {'id': 'leave_approve', 'name': 'Approve Leaves', 'desc': 'Approve team leave requests.'},
      {'id': 'leave_reject', 'name': 'Reject Leaves', 'desc': 'Reject team leave requests.'},
    ],
    'PAYROLL': [
      {'id': 'payroll_view', 'name': 'View Payroll', 'desc': 'Access payroll details and payslips.'},
      {'id': 'payroll_generate', 'name': 'Generate Payroll', 'desc': 'Configure and process monthly payroll cycles.'},
      {'id': 'payroll_approve', 'name': 'Approve Payroll', 'desc': 'Authorize monthly payroll releases.'},
      {'id': 'payroll_manage', 'name': 'Manage Payroll', 'desc': 'Configure statutory rates, salary structures, and process payroll.'},
    ],
    'REPORTS': [
      {'id': 'reports_view', 'name': 'View Reports', 'desc': 'Access high-level dashboards and analytics.'},
      {'id': 'reports_export', 'name': 'Export Data', 'desc': 'Download and export spreadsheets or PDFs.'},
    ],
    'COMPANY ADMINISTRATION': [
      {'id': 'department_create', 'name': 'Manage Departments', 'desc': 'Create, edit, and manage departments.'},
      {'id': 'designation_create', 'name': 'Manage Designations', 'desc': 'Create, edit, and manage designations.'},
      {'id': 'settings_manage', 'name': 'Settings Administration', 'desc': 'Alter geo-fencing borders, late grace times, office shifts, and feature modules.'},
    ],
    'TASKS': [
      {'id': 'task_view', 'name': 'View Tasks', 'desc': 'Access task dashboard and personal/team task lists.'},
      {'id': 'task_create', 'name': 'Create Tasks', 'desc': 'Create new tasks for self or team members.'},
      {'id': 'task_edit', 'name': 'Edit Tasks', 'desc': 'Modify task details, priority, and due dates.'},
      {'id': 'task_delete', 'name': 'Delete Tasks', 'desc': 'Delete task entries.'},
      {'id': 'task_assign', 'name': 'Assign Tasks', 'desc': 'Assign tasks to other team members.'},
    ],
    'FOLLOW-UPS': [
      {'id': 'followup_view', 'name': 'View Follow-ups', 'desc': 'View scheduled client call and meeting follow-ups.'},
      {'id': 'followup_create', 'name': 'Create Follow-ups', 'desc': 'Schedule new follow-ups for leads and clients.'},
      {'id': 'followup_edit', 'name': 'Edit Follow-ups', 'desc': 'Modify follow-up schedules, dates, and notes.'},
      {'id': 'followup_complete', 'name': 'Complete Follow-ups', 'desc': 'Mark follow-up activities as completed.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadRolesAndEmployees();
  }

  Future<void> _loadRolesAndEmployees() async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      // 1. Fetch custom roles created specifically for this company
      final snapshot = await FirebaseFirestore.instance
          .collection('roles')
          .where('companyId', isEqualTo: user.companyId)
          .get();

      final rolesList = snapshot.docs.map((doc) {
        final data = doc.data();
        DateTime? createdAt;
        if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        }
        return {
          'roleId': doc.id,
          'roleName': data['roleName'] ?? '',
          'description': data['description'] ?? '',
          'isSystemRole': data['isSystemRole'] ?? false,
          'createdAt': createdAt ?? DateTime.now(),
        };
      }).toList();

      rolesList.sort((a, b) => (a['roleName'] as String).compareTo(b['roleName'] as String));

      // 2. Fetch company employees to calculate assigned users count & names
      final employeesAsync = ref.read(adminEmployeesProvider);
      final employees = employeesAsync.value ?? [];

      final Map<String, List<UserModel>> userMapping = {};
      for (final r in rolesList) {
        final rName = (r['roleName'] as String).toLowerCase();
        final rId = r['roleId'] as String;

        final assigned = employees.where((emp) {
          final empRole = emp.role.toLowerCase();
          return empRole == rName || empRole == rId;
        }).toList();

        userMapping[rId] = assigned;
      }

      setState(() {
        _roles = rolesList;
        _assignedUsersByRole = userMapping;
        _isLoading = false;

        if (_selectedRoleId == null && rolesList.isNotEmpty) {
          _selectRole(rolesList.first);
        } else if (_selectedRoleId != null) {
          final current = rolesList.where((r) => r['roleId'] == _selectedRoleId);
          if (current.isNotEmpty) {
            _selectRole(current.first);
          } else if (rolesList.isNotEmpty) {
            _selectRole(rolesList.first);
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load roles: $e', isError: true);
    }
  }

  Future<void> _selectRole(Map<String, dynamic> role) async {
    setState(() {
      _selectedRoleId = role['roleId'];
      _selectedRoleName = role['roleName'];
      _selectedRoleDescription = role['description'];
      _selectedRoleCreatedAt = role['createdAt'] as DateTime?;
      _isLoading = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('role_permissions')
          .where('roleId', isEqualTo: _selectedRoleId)
          .get();

      final list = query.docs.map((doc) => doc.data()['permissionId'] as String).toList();
      if (!mounted) return;
      setState(() {
        _selectedPermissions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load role permissions: $e', isError: true);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedRoleId == null) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final existing = await db
          .collection('role_permissions')
          .where('roleId', isEqualTo: _selectedRoleId)
          .get();

      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      for (final permId in _selectedPermissions) {
        final docId = '${_selectedRoleId}_$permId';
        batch.set(db.collection('role_permissions').doc(docId), {
          'roleId': _selectedRoleId,
          'permissionId': permId,
        });
      }

      batch.update(db.collection('roles').doc(_selectedRoleId), {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      setState(() => _isLoading = false);
      AppNotification.showSuccess(context, 'Permissions for "$_selectedRoleName" updated successfully.');

      ref.invalidate(userPermissionsProvider);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save permissions: $e', isError: true);
    }
  }

  void _showCreateRoleDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create Custom Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Role Name *', hintText: 'e.g. Tech Lead, Senior Analyst, Team Lead'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final exists = _roles.any((r) => r['roleName'].toString().toLowerCase() == v.trim().toLowerCase());
                    if (exists) return 'Role name already exists';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe role duties'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                await _createRole(nameCtrl.text.trim(), descCtrl.text.trim());
              }
            },
            child: const Text('Create Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _createRole(String name, String description) async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final roleId = const Uuid().v4();
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.set(db.collection('roles').doc(roleId), {
        'roleId': roleId,
        'companyId': user.companyId,
        'roleName': name,
        'description': description,
        'isSystemRole': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Default basic permissions
      final defaultPerms = ['employee_view', 'attendance_view', 'leave_apply'];
      for (final permId in defaultPerms) {
        final docId = '${roleId}_$permId';
        batch.set(db.collection('role_permissions').doc(docId), {
          'roleId': roleId,
          'permissionId': permId,
        });
      }

      await batch.commit();
      _selectedRoleId = roleId;
      await _loadRolesAndEmployees();
      AppNotification.showSuccess(context, 'Custom role "$name" created successfully.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to create role: $e', isError: true);
    }
  }

  void _showEditRoleDialog(Map<String, dynamic> role) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: role['roleName']);
    final descCtrl = TextEditingController(text: role['description']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Role Details', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Role Name *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final exists = _roles.any((r) => r['roleId'] != role['roleId'] && r['roleName'].toString().toLowerCase() == v.trim().toLowerCase());
                  if (exists) return 'Role name exists';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                await _updateRole(role['roleId'], nameCtrl.text.trim(), descCtrl.text.trim());
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRole(String roleId, String name, String desc) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('roles').doc(roleId).update({
        'roleName': name,
        'description': desc,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadRolesAndEmployees();
      AppNotification.showSuccess(context, 'Role details updated successfully.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update role: $e', isError: true);
    }
  }

  void _confirmDeleteRole(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Custom Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${role['roleName']}"?', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteRole(role['roleId'], role['roleName']);
            },
            child: const Text('Delete Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRole(String roleId, String roleName) async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final assignedUsers = _assignedUsersByRole[roleId] ?? [];

      if (assignedUsers.isNotEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Role In Use', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'This role cannot be deleted because ${assignedUsers.length} employee(s) (${assignedUsers.map((u) => u.name).take(3).join(', ')}) are currently assigned to it.',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(fontFamily: 'Outfit'))),
              ],
            ),
          );
        }
        return;
      }

      final batch = db.batch();
      batch.delete(db.collection('roles').doc(roleId));

      final mappings = await db
          .collection('role_permissions')
          .where('roleId', isEqualTo: roleId)
          .get();

      for (final doc in mappings.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _selectedRoleId = null;
      await _loadRolesAndEmployees();
      AppNotification.showSuccess(context, 'Role "$roleName" deleted successfully.');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to delete role: $e', isError: true);
    }
  }

  void _showAssignRoleDialog() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final employeesAsync = ref.read(adminEmployeesProvider);
    final employees = employeesAsync.value ?? [];

    if (employees.isEmpty) {
      _showSnackBar('No employees available in your company.', isError: true);
      return;
    }

    UserModel? selectedEmployee = employees.first;
    String selectedRoleName = _roles.isNotEmpty ? _roles.first['roleName'] : 'Employee';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.person_add_rounded, color: Color(0xFF5B4CF0)),
                SizedBox(width: 10),
                Text('Assign Role to Employee', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Employee *', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UserModel>(
                    value: selectedEmployee,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: employees.map((emp) {
                      return DropdownMenuItem<UserModel>(
                        value: emp,
                        child: Text('${emp.name} (${emp.employeeId ?? emp.email})', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedEmployee = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  if (selectedEmployee != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Department: ${selectedEmployee!.department ?? "Unassigned"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                          const SizedBox(height: 2),
                          Text('Designation: ${selectedEmployee!.designation ?? "Unassigned"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                          const SizedBox(height: 2),
                          Text('Current Role: ${selectedEmployee!.role}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text('Select Custom Role *', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _roles.any((r) => r['roleName'] == selectedRoleName) ? selectedRoleName : (_roles.isNotEmpty ? _roles.first['roleName'] : ''),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: _roles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['roleName'] as String,
                        child: Text('${r['roleName']}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedRoleName = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: isSaving || selectedEmployee == null
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection(FirestoreCollections.users)
                              .doc(selectedEmployee!.uid)
                              .update({
                            'role': selectedRoleName,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          await ref.read(adminEmployeesProvider.notifier).loadEmployees();
                          await _loadRolesAndEmployees();

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppNotification.showSuccess(context, 'Role "$selectedRoleName" assigned to ${selectedEmployee!.name} successfully!');
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          _showSnackBar('Failed to assign role: $e', isError: true);
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Assign Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Roles & Permissions Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, fontFamily: 'Outfit')),
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showAssignRoleDialog,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(isDesktop ? 'Assign Role to Employee' : 'Assign Role', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5B4CF0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 340,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: _buildRolesList(),
                    ),
                    Expanded(
                      child: _buildPermissionSettingsPanel(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _roles.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _roles.length) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: TextButton.icon(
                                onPressed: _showCreateRoleDialog,
                                icon: const Icon(Icons.add, size: 16, color: Color(0xFF5B4CF0)),
                                label: const Text('Add Role', style: TextStyle(fontSize: 12, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                              ),
                            );
                          }

                          final r = _roles[index];
                          final isSelected = r['roleId'] == _selectedRoleId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(r['roleName']),
                              selected: isSelected,
                              selectedColor: const Color(0xFF5B4CF0).withValues(alpha: 0.12),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF5B4CF0) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? const Color(0xFF5B4CF0) : const Color(0xFFE2E8F0)),
                              ),
                              onSelected: (_) => _selectRole(r),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(child: _buildPermissionSettingsPanel()),
                  ],
                ),
    );
  }

  Widget _buildRolesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final filteredRoles = _roles.where((r) {
      if (_roleSearchQuery.isEmpty) return true;
      final name = (r['roleName'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      return name.contains(_roleSearchQuery) || desc.contains(_roleSearchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Company Roles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit')),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF5B4CF0), size: 24),
                onPressed: _showCreateRoleDialog,
                tooltip: 'Add Custom Role',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _roleSearchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search roles...',
              hintStyle: const TextStyle(fontSize: 12, fontFamily: 'Outfit'),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _roleSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _roleSearchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: borderCol),
        Expanded(
          child: filteredRoles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _roleSearchQuery.isEmpty ? 'No custom roles created for this company yet.' : 'No roles found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontFamily: 'Outfit'),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: filteredRoles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final r = filteredRoles[index];
                    final isSelected = r['roleId'] == _selectedRoleId;
                    final roleId = r['roleId'] as String;
                    final assignedUsers = _assignedUsersByRole[roleId] ?? [];
                    final userNames = assignedUsers.map((u) => u.name).join(', ');

                    return InkWell(
                      onTap: () => _selectRole(r),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF5B4CF0).withValues(alpha: 0.10) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF5B4CF0) : borderCol,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r['roleName'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 15,
                                      color: isSelected ? const Color(0xFF5B4CF0) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFF59E0B)),
                                      onPressed: () => _showEditRoleDialog(r),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Edit Role',
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                      onPressed: () => _confirmDeleteRole(r),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Delete Role',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if ((r['description'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r['description'], style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 13, color: isSelected ? const Color(0xFF5B4CF0) : const Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  '${assignedUsers.length} Employee(s)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF5B4CF0) : (isDark ? Colors.white70 : const Color(0xFF475569)), fontFamily: 'Outfit'),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Active', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                ),
                              ],
                            ),
                            if (userNames.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Assigned: $userNames',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPermissionSettingsPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    if (_selectedRoleId == null) {
      return const Center(child: Text('No role selected.', style: TextStyle(fontFamily: 'Outfit')));
    }

    final assignedUsers = _assignedUsersByRole[_selectedRoleId] ?? [];
    final formattedDate = _selectedRoleCreatedAt != null ? DateFormat('dd MMM yyyy').format(_selectedRoleCreatedAt!) : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel Header Card
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _selectedRoleName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit'),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF5B4CF0).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Custom Company Role', style: TextStyle(fontSize: 10, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                            ),
                          ],
                        ),
                        if (_selectedRoleDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_selectedRoleDescription, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          final allIds = _permissionModules.values.expand((list) => list.map((p) => p['id']!)).toList();
                          setState(() => _selectedPermissions = allIds);
                        },
                        child: const Text('Select All Global', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedPermissions.clear());
                        },
                        child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Outfit')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: dividerCol),
              const SizedBox(height: 10),
              // Role Summary Info Bar
              Row(
                children: [
                  _infoChip(Icons.people_outline, 'Assigned Users: ${assignedUsers.length}', isDark),
                  const SizedBox(width: 12),
                  _infoChip(Icons.verified_outlined, 'Permissions: ${_selectedPermissions.length} Granted', isDark),
                  const SizedBox(width: 12),
                  _infoChip(Icons.calendar_today_outlined, 'Created: $formattedDate', isDark),
                ],
              ),
              if (assignedUsers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Assigned Employees: ${assignedUsers.map((u) => u.name).join(', ')}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : const Color(0xFF475569), fontFamily: 'Outfit'),
                ),
              ],
            ],
          ),
        ),

        // Settings Body List (Permission Configuration Matrix)
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: _permissionModules.keys.map((moduleName) {
              final modulePerms = _permissionModules[moduleName]!;
              final moduleIds = modulePerms.map((p) => p['id']!).toList();
              final allModuleSelected = moduleIds.every((id) => _selectedPermissions.contains(id));

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Material(
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: borderCol),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 12, top: 12, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              moduleName.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5B4CF0), letterSpacing: 1.1, fontFamily: 'Outfit'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (allModuleSelected) {
                                    _selectedPermissions.removeWhere((id) => moduleIds.contains(id));
                                  } else {
                                    for (final id in moduleIds) {
                                      if (!_selectedPermissions.contains(id)) {
                                        _selectedPermissions.add(id);
                                      }
                                    }
                                  }
                                });
                              },
                              child: Text(
                                allModuleSelected ? 'Clear Module' : 'Select All',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: dividerCol),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: modulePerms.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: dividerCol),
                        itemBuilder: (context, idx) {
                          final perm = modulePerms[idx];
                          final permId = perm['id']!;
                          final isChecked = _selectedPermissions.contains(permId);

                          return SwitchListTile(
                            activeColor: const Color(0xFF5B4CF0),
                            activeTrackColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                            inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : Colors.white,
                            inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Row(
                              children: [
                                Text(
                                  isChecked ? '✓ ' : '✗ ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isChecked ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  perm['name']!,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit'),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2.0, left: 18),
                              child: Text(
                                perm['desc']!,
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
                              ),
                            ),
                            value: isChecked,
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  if (!_selectedPermissions.contains(permId)) {
                                    _selectedPermissions.add(permId);
                                  }
                                } else {
                                  _selectedPermissions.remove(permId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Action Buttons Bottom Bar
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: borderCol)),
          ),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _savePermissions,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Role Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF5B4CF0)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}
