import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/providers/permissions_provider.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/constants/firestore_collections.dart';

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
  bool _selectedIsSystem = true;
  String _roleSearchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _roles = [];
  List<String> _selectedPermissions = [];

  // Static list of all available permissions grouped by module
  final Map<String, List<Map<String, String>>> _permissionModules = {
    'Employee': [
      {'id': 'employee_view', 'name': 'View Employees', 'desc': 'Access the directory and basic details of employees.'},
      {'id': 'employee_create', 'name': 'Create Employees', 'desc': 'Create credentials and onboard new employee logins.'},
      {'id': 'employee_edit', 'name': 'Edit Employees', 'desc': 'Modify employee profiles, departments, and designations.'},
      {'id': 'employee_delete', 'name': 'Delete Employees', 'desc': 'Soft-delete or disable employee accounts.'},
    ],
    'Department': [
      {'id': 'department_create', 'name': 'Create Departments', 'desc': 'Create new departments.'},
      {'id': 'department_edit', 'name': 'Edit Departments', 'desc': 'Update managers and department settings.'},
      {'id': 'department_delete', 'name': 'Delete Departments', 'desc': 'Remove business departments.'},
    ],
    'Attendance': [
      {'id': 'attendance_view', 'name': 'View Attendance', 'desc': 'View daily attendance check-ins and hours logs.'},
      {'id': 'attendance_approve', 'name': 'Approve Attendance', 'desc': 'Approve regularizations or manager overrides.'},
      {'id': 'attendance_correct', 'name': 'Correct Logs', 'desc': 'Manually alter work shifts or check-in logs.'},
    ],
    'Leave': [
      {'id': 'leave_apply', 'name': 'Apply Leaves', 'desc': 'Submit personal leave requests.'},
      {'id': 'leave_approve', 'name': 'Approve Leaves', 'desc': 'Approve team leave requests.'},
      {'id': 'leave_reject', 'name': 'Reject Leaves', 'desc': 'Reject team leave requests.'},
    ],
    'Payroll': [
      {'id': 'payroll_view', 'name': 'View Payroll', 'desc': 'Access payroll details and payslips.'},
      {'id': 'payroll_generate', 'name': 'Generate Payroll', 'desc': 'Configure and process payroll cycles.'},
      {'id': 'payroll_approve', 'name': 'Approve Payroll', 'desc': 'Authorize payroll releases.'},
      {'id': 'payroll_manage', 'name': 'Manage Payroll', 'desc': 'Configure salary components, structures, cycles, statutory rates, and process payroll.'},
    ],
    'Lead': [
      {'id': 'lead_view', 'name': 'View Leads', 'desc': 'Access lead lists, pipeline views, and lead details.'},
      {'id': 'lead_create', 'name': 'Create Leads', 'desc': 'Add new sales leads into the system.'},
      {'id': 'lead_edit', 'name': 'Edit Leads', 'desc': 'Update lead info, status, values, and assignees.'},
      {'id': 'lead_delete', 'name': 'Delete Leads', 'desc': 'Remove or archive lead records.'},
      {'id': 'lead_convert_order', 'name': 'Convert to Order', 'desc': 'Convert won sales leads into trackable client orders.'},
    ],
    'Follow-up': [
      {'id': 'followup_view', 'name': 'View Follow-ups', 'desc': 'View scheduled client call and meeting follow-ups.'},
      {'id': 'followup_create', 'name': 'Create Follow-ups', 'desc': 'Schedule new follow-ups for leads and clients.'},
      {'id': 'followup_edit', 'name': 'Edit Follow-ups', 'desc': 'Modify follow-up schedules, dates, and notes.'},
      {'id': 'followup_complete', 'name': 'Complete Follow-ups', 'desc': 'Mark follow-up activities as completed.'},
      {'id': 'followup_delete', 'name': 'Delete Follow-ups', 'desc': 'Cancel or delete follow-up reminders.'},
    ],
    'Orders': [
      {'id': 'order_view', 'name': 'View Orders', 'desc': 'Access orders dashboard, order lists, and project details.'},
      {'id': 'order_create', 'name': 'Create Orders', 'desc': 'Create new client orders into the system.'},
      {'id': 'order_edit', 'name': 'Edit Orders', 'desc': 'Modify order details, item entries, and assignees.'},
      {'id': 'order_delete', 'name': 'Delete Orders', 'desc': 'Delete or archive order records.'},
      {'id': 'order_close', 'name': 'Close Orders', 'desc': 'Mark active orders as completed/closed.'},
      {'id': 'order_cancel', 'name': 'Cancel Orders', 'desc': 'Cancel active or pending client orders.'},
    ],
    'Tasks': [
      {'id': 'task_view', 'name': 'View Tasks', 'desc': 'Access task dashboard and personal/team task lists.'},
      {'id': 'task_create', 'name': 'Create Tasks', 'desc': 'Create new tasks for self or team members.'},
      {'id': 'task_edit', 'name': 'Edit Tasks', 'desc': 'Modify task details, priority, and due dates.'},
      {'id': 'task_delete', 'name': 'Delete Tasks', 'desc': 'Delete task entries.'},
      {'id': 'task_assign', 'name': 'Assign Tasks', 'desc': 'Assign tasks to other team members.'},
      {'id': 'task_complete', 'name': 'Complete Tasks', 'desc': 'Mark assigned tasks as done/completed.'},
      {'id': 'task_reassign', 'name': 'Reassign Tasks', 'desc': 'Transfer task ownership to another employee.'},
    ],
    'Reports': [
      {'id': 'reports_view', 'name': 'View Reports', 'desc': 'Access high-level dashboards and charts.'},
      {'id': 'reports_export', 'name': 'Export Data', 'desc': 'Download and export spreadsheets or PDFs.'},
    ],
    'Settings': [
      {'id': 'settings_manage', 'name': 'Settings Administration', 'desc': 'Alter geo-fencing borders, late grace times, office shifts, and feature modules.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      // 1. Ensure defaults are seeded
      await seedDefaultRolesAndPermissions(user.companyId);

      // 2. Fetch all roles for this company
      final snapshot = await FirebaseFirestore.instance
          .collection('roles')
          .where('companyId', isEqualTo: user.companyId)
          .get();

      final rolesList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'roleId': doc.id,
          'roleName': data['roleName'] ?? '',
          'description': data['description'] ?? '',
          'isSystemRole': data['isSystemRole'] ?? false,
        };
      }).toList();

      // Sort system roles first, then alphabetically
      rolesList.sort((a, b) {
        final aSys = a['isSystemRole'] as bool;
        final bSys = b['isSystemRole'] as bool;
        if (aSys != bSys) {
          return aSys ? -1 : 1;
        }
        return (a['roleName'] as String).compareTo(b['roleName'] as String);
      });

      setState(() {
        _roles = rolesList;
        _isLoading = false;
        // Default select first role if none selected
        if (_selectedRoleId == null && rolesList.isNotEmpty) {
          _selectRole(rolesList.first);
        } else if (_selectedRoleId != null) {
          // Keep selection if it still exists
          final current = rolesList.where((r) => r['roleId'] == _selectedRoleId);
          if (current.isNotEmpty) {
            _selectRole(current.first);
          } else {
            _selectRole(rolesList.first);
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load roles: $e', Colors.red);
    }
  }

  Future<void> _selectRole(Map<String, dynamic> role) async {
    setState(() {
      _selectedRoleId = role['roleId'];
      _selectedRoleName = role['roleName'];
      _selectedRoleDescription = role['description'];
      _selectedIsSystem = role['isSystemRole'] ?? false;
      _isLoading = true;
    });

    try {
      // Fetch permissions for the selected role
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
      _showSnackBar('Failed to load role permissions: $e', Colors.red);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedRoleId == null) return;
    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Delete all current role_permissions mappings for this roleId
      final existing = await db
          .collection('role_permissions')
          .where('roleId', isEqualTo: _selectedRoleId)
          .get();

      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // 2. Insert new mappings
      for (final permId in _selectedPermissions) {
        final docId = '${_selectedRoleId}_$permId';
        batch.set(db.collection('role_permissions').doc(docId), {
          'roleId': _selectedRoleId,
          'permissionId': permId,
        });
      }

      // 3. Update roles timestamp
      batch.update(db.collection('roles').doc(_selectedRoleId), {
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      setState(() => _isLoading = false);
      _showSnackBar('Permissions updated successfully.', Colors.green);
      
      // Reload current permissions
      ref.invalidate(userPermissionsProvider);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to save permissions: $e', Colors.red);
    }
  }

  void _showCreateRoleDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? cloneFromRoleId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Create Custom Role', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Role Name *', hintText: 'e.g. Leave Manager'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          // Prevent system names or duplicate local names
                          final exists = _roles.any((r) => r['roleName'].toString().toLowerCase() == v.trim().toLowerCase());
                          if (exists) return 'Role already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe role duties'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: cloneFromRoleId,
                        decoration: const InputDecoration(
                          labelText: 'Inherit Permissions From (Optional)',
                          prefixIcon: Icon(Icons.copy_rounded, size: 20),
                        ),
                        items: _roles.map((r) {
                          return DropdownMenuItem(
                            value: r['roleId'] as String,
                            child: Text(r['roleName'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            cloneFromRoleId = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    await _createRole(nameCtrl.text.trim(), descCtrl.text.trim(), cloneFromRoleId);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createRole(String name, String description, String? cloneFromRoleId) async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final roleId = const Uuid().v4();
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Create role document
      batch.set(db.collection('roles').doc(roleId), {
        'roleId': roleId,
        'companyId': user.companyId,
        'roleName': name,
        'description': description,
        'isSystemRole': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Clone permissions if chosen
      if (cloneFromRoleId != null) {
        final query = await db
            .collection('role_permissions')
            .where('roleId', isEqualTo: cloneFromRoleId)
            .get();

        for (final doc in query.docs) {
          final permId = doc.data()['permissionId'] as String;
          final mappingId = '${roleId}_$permId';
          batch.set(db.collection('role_permissions').doc(mappingId), {
            'roleId': roleId,
            'permissionId': permId,
          });
        }
      }

      await batch.commit();
      _selectedRoleId = roleId;
      await _loadRoles();
      _showSnackBar('Custom role created successfully.', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to create role: $e', Colors.red);
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
        title: const Text('Edit Role Details', style: TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                await _updateRole(role['roleId'], nameCtrl.text.trim(), descCtrl.text.trim());
              }
            },
            child: const Text('Save'),
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
      await _loadRoles();
      _showSnackBar('Role details updated successfully.', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update role: $e', Colors.red);
    }
  }

  void _confirmDeleteRole(Map<String, dynamic> role) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Role'),
        content: Text('Are you sure you want to delete "${role['roleName']}"? This will clean up its custom access permissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteRole(role['roleId'], role['roleName']);
            },
            child: const Text('Delete'),
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

      // Check if employees are assigned to this role
      final assignedUsersSnap = await db
          .collection(FirestoreCollections.users)
          .where('companyId', isEqualTo: user.companyId)
          .where('role', isEqualTo: roleName)
          .get();

      if (assignedUsersSnap.docs.isNotEmpty) {
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
                'This role cannot be deleted because ${assignedUsersSnap.docs.length} employee(s) are currently assigned to it. Please reassign the employees to another role first.',
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

      // 1. Delete role doc
      batch.delete(db.collection('roles').doc(roleId));

      // 2. Delete mappings
      final mappings = await db
          .collection('role_permissions')
          .where('roleId', isEqualTo: roleId)
          .get();

      for (final doc in mappings.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _selectedRoleId = null;
      await _loadRoles();
      _showSnackBar('Role deleted successfully.', Colors.green);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to delete role: $e', Colors.red);
    }
  }

  void _showAssignRoleDialog() {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final employeesAsync = ref.read(adminEmployeesProvider);
    final employees = employeesAsync.value ?? [];

    if (employees.isEmpty) {
      _showSnackBar('No employees available in your company.', Colors.orange);
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
                          Text('Department: ${selectedEmployee!.department ?? "Unassigned"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Designation: ${selectedEmployee!.designation ?? "Unassigned"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Current System Role: ${UserModel.denormalizeRole(selectedEmployee!.role)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5B4CF0))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text('Select System / Custom Role *', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRoleName,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: _roles.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['roleName'] as String,
                        child: Text('${r['roleName']} ${r['isSystemRole'] ? "(System)" : "(Custom)"}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
                onPressed: isSaving || selectedEmployee == null
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final targetRoleObj = _roles.firstWhere((r) => r['roleName'] == selectedRoleName, orElse: () => {'roleId': '', 'roleName': selectedRoleName});
                          final customRoleId = targetRoleObj['roleId'] as String;

                          await FirebaseFirestore.instance
                              .collection(FirestoreCollections.users)
                              .doc(selectedEmployee!.uid)
                              .update({
                            'role': selectedRoleName,
                            if (customRoleId.isNotEmpty) 'customRoleId': customRoleId,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          await ref.read(companyAdminRepositoryProvider).logEmployeeActivity(
                            companyId: user.companyId,
                            employeeId: selectedEmployee!.uid,
                            action: 'Role updated to $selectedRoleName',
                            performedBy: user.name,
                          );

                          await ref.read(adminEmployeesProvider.notifier).loadEmployees();

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _showSnackBar('Role assigned to ${selectedEmployee!.name} successfully!', Colors.green);
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          _showSnackBar('Failed to assign role: $e', Colors.red);
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

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
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
        title: const Text('Roles & Permissions Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
        backgroundColor: cardBg,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showAssignRoleDialog,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(isDesktop ? 'Assign Role to Employee' : 'Assign Role', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Desktop Left Panel: Roles list
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: _buildRolesList(),
                    ),
                    // Desktop Right Panel: Permission settings
                    Expanded(
                      child: _buildPermissionSettingsPanel(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // Mobile Top bar Selector
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
                                label: const Text('Add Role', style: TextStyle(fontSize: 12, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B4CF0).withOpacity(0.08),
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
                              selectedColor: const Color(0xFF5B4CF0).withOpacity(0.12),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF5B4CF0) : const Color(0xFF475569),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Defined Roles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF5B4CF0), size: 22),
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
              hintStyle: const TextStyle(fontSize: 12),
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
                      _roleSearchQuery.isEmpty ? 'No custom roles created.' : 'No roles found.',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRoles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final r = filteredRoles[index];
                    final isSelected = r['roleId'] == _selectedRoleId;
                    final isSystem = r['isSystemRole'] as bool;

              return InkWell(
                onTap: () => _selectRole(r),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF5B4CF0).withOpacity(0.10) : (isDark ? const Color(0xFF0F172A) : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF5B4CF0) : borderCol,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['roleName'],
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected ? const Color(0xFF5B4CF0) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSystem ? 'System Defined Role' : 'Custom Company Role',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      if (isSystem)
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF94A3B8))
                      else
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
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFBA1A1A)),
                              onPressed: () => _confirmDeleteRole(r),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              tooltip: 'Delete Role',
                            ),
                          ],
                        ),
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
      return const Center(child: Text('No role selected.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panel Header Card
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(bottom: BorderSide(color: borderCol)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedRoleName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_selectedIsSystem)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                          child: Text('System Role', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF312E81).withOpacity(0.4) : const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Custom Role', style: TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          final allIds = _permissionModules.values.expand((list) => list.map((p) => p['id']!)).toList();
                          setState(() => _selectedPermissions = allIds);
                        },
                        child: const Text('Select All Global', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedPermissions.clear());
                        },
                        child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ],
                  ),
                ],
              ),
              if (_selectedRoleDescription.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_selectedRoleDescription, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ],
          ),
        ),

        // Settings Body List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: _permissionModules.keys.map((moduleName) {
              final modulePerms = _permissionModules[moduleName]!;
              final moduleIds = modulePerms.map((p) => p['id']!).toList();
              final allModuleSelected = moduleIds.every((id) => _selectedPermissions.contains(id));

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 12, top: 12, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            moduleName.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5B4CF0), letterSpacing: 1.1),
                          ),
                          Row(
                            children: [
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
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                                ),
                              ),
                            ],
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
                          activeTrackColor: const Color(0xFF5B4CF0).withOpacity(0.3),
                          inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : Colors.white,
                          inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(
                            perm['name']!,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              perm['desc']!,
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.3),
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
              );
            }).toList(),
          ),
        ),

        // Action Buttons Bottom Bar
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: borderCol)),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _savePermissions,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Role Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
