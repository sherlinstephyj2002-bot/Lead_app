import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/services/app_error_handler.dart';
import '../../../shared/widgets/app_notification.dart';
import '../models/designation_model.dart';
import '../models/role_model.dart';
import '../providers/company_admin_providers.dart';
import '../../../shared/widgets/searchable_dropdown.dart';

class RoleManagementScreen extends ConsumerStatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  ConsumerState<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends ConsumerState<RoleManagementScreen> {
  String? _selectedFilterDepartmentId;
  String? _searchQuery;

  void _showRoleDialog({RoleModel? existingRole}) {
    final isEdit = existingRole != null;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final deptsAsync = ref.read(adminDepartmentsProvider);
    final desigsAsync = ref.read(adminDesignationsProvider);

    final depts = (deptsAsync.value ?? []).where((d) => d.status == 'active').toList();
    final allDesigs = (desigsAsync.value ?? []).where((d) => d.status == 'active').toList();

    List<DepartmentModel> selectedDepts = depts.where((d) =>
        existingRole != null && existingRole.applicableDepartmentIds.contains(d.departmentId)).toList();
    
    List<DesignationModel> selectedDesigs = allDesigs.where((d) =>
        existingRole != null && existingRole.applicableDesignationIds.contains(d.designationId)).toList();

    final nameCtrl = TextEditingController(text: existingRole?.roleName ?? '');
    final formKey = GlobalKey<FormState>();

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Filter designations based on selected departments
            final availableDesigs = selectedDepts.isEmpty
                ? <DesignationModel>[]
                : allDesigs.where((desig) {
                    return selectedDepts.any((dept) =>
                        desig.applicableDepartmentIds.contains(dept.departmentId) ||
                        desig.departmentId == dept.departmentId ||
                        desig.applicableDepartmentIds.isEmpty);
                  }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF5B4CF0), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Role' : 'Create New Role',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Organizational Hierarchy',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B4CF0)),
                        ),
                        const SizedBox(height: 12),

                        // STEP 1: Select Department(s)
                        SearchableMultiSelectDropdown<DepartmentModel>(
                          label: 'Departments *',
                          hint: 'Select Department(s)',
                          icon: Icons.business_center_rounded,
                          items: depts,
                          selectedItems: selectedDepts,
                          itemAsString: (d) => d.departmentName,
                          itemAsSubTitle: (d) => d.departmentCode,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedDepts = val;
                              // Filter out designations no longer valid
                              final validDesigIds = availableDesigs.map((d) => d.designationId).toSet();
                              selectedDesigs.removeWhere((d) => !validDesigIds.contains(d.designationId));
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 2: Select Designation(s)
                        SearchableMultiSelectDropdown<DesignationModel>(
                          label: 'Designations *',
                          hint: selectedDepts.isEmpty ? 'Select Department first' : 'Select Designation(s)',
                          icon: Icons.badge_outlined,
                          enabled: selectedDepts.isNotEmpty,
                          items: availableDesigs,
                          selectedItems: selectedDesigs,
                          itemAsString: (d) => d.designationName,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedDesigs = val;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // STEP 3: Role Name Input
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Role Name *',
                            hintText: 'e.g. Finance Manager Approval Role',
                            prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFF5B4CF0), size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a role name' : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (selectedDepts.isEmpty) {
                            AppNotification.showError(context, 'Please select at least one Department.');
                            return;
                          }
                          if (selectedDesigs.isEmpty) {
                            AppNotification.showError(context, 'Please select at least one Designation.');
                            return;
                          }
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSubmitting = true);

                            final deptIds = selectedDepts.map((d) => d.departmentId).toList();
                            final desigIds = selectedDesigs.map((d) => d.designationId).toList();

                            final orgAssignments = <RoleOrganizationalAssignment>[];
                            for (final deptId in deptIds) {
                              for (final desigId in desigIds) {
                                orgAssignments.add(RoleOrganizationalAssignment(
                                  departmentId: deptId,
                                  designationId: desigId,
                                ));
                              }
                            }

                            final newRole = RoleModel(
                              roleId: existingRole?.roleId ?? const Uuid().v4(),
                              companyId: user.companyId,
                              roleName: nameCtrl.text.trim(),
                              departmentId: deptIds.isNotEmpty ? deptIds.first : '',
                              designationId: desigIds.isNotEmpty ? desigIds.first : '',
                              departmentIds: deptIds,
                              designationIds: desigIds,
                              organizationalAssignments: orgAssignments,
                              description: '',
                              status: existingRole?.status ?? 'active',
                              createdAt: existingRole?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            final success = await ref.read(adminRolesProvider.notifier).saveRole(newRole);
                            if (context.mounted) {
                              if (success) {
                                Navigator.pop(ctx);
                                AppNotification.showSuccess(context, 'Role saved successfully.');
                              } else {
                                setDialogState(() => isSubmitting = false);
                                AppNotification.showError(context, 'A role with this name already exists.');
                              }
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteRoleConfirm(RoleModel role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Are you sure you want to delete "${role.roleName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminRolesProvider.notifier).deleteRole(role.roleId);
      if (mounted) {
        AppNotification.showSuccess(context, 'Role deleted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(adminRolesProvider);
    final deptsAsync = ref.watch(adminDepartmentsProvider);
    final desigsAsync = ref.watch(adminDesignationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final depts = deptsAsync.value ?? [];
    final desigs = desigsAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showRoleDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Role'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Bar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search roles...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedFilterDepartmentId,
                        decoration: InputDecoration(
                          hintText: 'Filter by Department',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Departments')),
                          ...depts.map((d) => DropdownMenuItem(value: d.departmentId, child: Text(d.departmentName))),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedFilterDepartmentId = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Roles List
            Expanded(
              child: rolesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error loading roles: $err', style: const TextStyle(color: Colors.red))),
                data: (roles) {
                  final activeRoles = roles.where((r) {
                    if (r.status == 'deleted' || r.status == 'archived') return false;
                    if (_selectedFilterDepartmentId != null && r.departmentId != _selectedFilterDepartmentId) return false;
                    if (_searchQuery != null && _searchQuery!.trim().isNotEmpty) {
                      final q = _searchQuery!.trim().toLowerCase();
                      if (!r.roleName.toLowerCase().contains(q)) return false;
                    }
                    return true;
                  }).toList();

                  if (activeRoles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No roles found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('Create roles connected to Department + Designation context.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showRoleDialog(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Role'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: activeRoles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final role = activeRoles[index];
                      final dept = depts.firstWhere((d) => d.departmentId == role.departmentId, orElse: () => DepartmentModel(departmentId: '', companyId: '', departmentName: 'Unknown', departmentCode: 'N/A', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                      final desig = desigs.firstWhere((d) => d.designationId == role.designationId, orElse: () => DesignationModel(designationId: '', companyId: '', designationName: 'Unknown', designationLevel: 1, createdAt: DateTime.now(), updatedAt: DateTime.now()));

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                            child: const Icon(Icons.work_outline_rounded, color: Color(0xFF5B4CF0), size: 20),
                          ),
                          title: Text(role.roleName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Dept: ${dept.departmentName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Desig: ${desig.designationName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple)),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 18),
                                onPressed: () => _showRoleDialog(existingRole: role),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: () => _deleteRoleConfirm(role),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
