import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/department_model.dart';
import 'package:worktrack/features/company_admin/models/designation_model.dart';
import 'package:worktrack/features/company_admin/models/role_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class CompanyConfigImporter {
  /// Open dialog to create a custom Designation for the current company
  static void showCustomDesignationDialog(
    BuildContext context,
    WidgetRef ref,
    List<DepartmentModel> activeDepts, {
    void Function(DesignationModel)? onCreated,
  }) {
    final nameCtrl = TextEditingController();
    final Set<String> selectedDeptIds = {};
    DepartmentModel? primaryDept = activeDepts.isNotEmpty ? activeDepts.first : null;
    if (primaryDept != null) selectedDeptIds.add(primaryDept.departmentId);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.badge_outlined, color: Color(0xFF5B4CF0), size: 22),
                  SizedBox(width: 8),
                  Text('Add Custom Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: math.min(480, MediaQuery.of(context).size.width * 0.9),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Designation Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g., Senior Operations Manager',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (activeDepts.isNotEmpty) ...[
                        const Text('Primary Department', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<DepartmentModel>(
                          value: primaryDept,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: activeDepts.map((d) => DropdownMenuItem(value: d, child: Text(d.departmentName, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              primaryDept = val;
                              if (val != null) selectedDeptIds.add(val.departmentId);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Department Responsibilities', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Text('Select departments this designation manages:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: activeDepts.map((dept) {
                              final isPrimary = primaryDept?.departmentId == dept.departmentId;
                              final isChecked = selectedDeptIds.contains(dept.departmentId) || isPrimary;

                              return CheckboxListTile(
                                value: isChecked,
                                dense: true,
                                activeColor: const Color(0xFF5B4CF0),
                                title: Text(dept.departmentName + (isPrimary ? ' (Primary)' : ''), style: TextStyle(fontSize: 13, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
                                onChanged: isPrimary ? null : (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedDeptIds.add(dept.departmentId);
                                    } else {
                                      selectedDeptIds.remove(dept.departmentId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final desigName = nameCtrl.text.trim();
                    if (desigName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a designation name.')),
                      );
                      return;
                    }
                    setDialogState(() => isSaving = true);
                    try {
                      final user = ref.read(authProvider).user;
                      final companyId = user?.companyId ?? '';
                      final desigId = 'desig_${DateTime.now().millisecondsSinceEpoch}';
                      final managed = selectedDeptIds.toList();
                      if (primaryDept != null && !managed.contains(primaryDept!.departmentId)) {
                        managed.add(primaryDept!.departmentId);
                      }

                      final newDesig = DesignationModel(
                        designationId: desigId,
                        companyId: companyId,
                        designationName: desigName,
                        designationLevel: 1,
                        departmentId: primaryDept?.departmentId ?? '',
                        managedDepartmentIds: managed,
                        canManageDepartments: managed.length > 1,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      final success = await ref.read(adminDesignationsProvider.notifier).saveDesignation(newDesig);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Custom Designation "$desigName" created successfully.')),
                          );
                          if (onCreated != null) onCreated(newDesig);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Designation already exists.')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Use Designation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Open dialog to create a custom Role for the current company
  static void showCustomRoleDialog(
    BuildContext context,
    WidgetRef ref,
    List<DepartmentModel> activeDepts, {
    void Function(RoleModel)? onCreated,
  }) {
    final nameCtrl = TextEditingController();
    final Set<String> selectedDeptIds = {};
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Color(0xFF5B4CF0), size: 22),
                  SizedBox(width: 8),
                  Text('Add Custom Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: math.min(480, MediaQuery.of(context).size.width * 0.9),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Role Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g., Operations Supervisor',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (activeDepts.isNotEmpty) ...[
                        const Text('Role Department Oversight', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Text('Select departments overseen by this role:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: activeDepts.map((dept) {
                              final isChecked = selectedDeptIds.contains(dept.departmentId);

                              return CheckboxListTile(
                                value: isChecked,
                                dense: true,
                                activeColor: const Color(0xFF5B4CF0),
                                title: Text(dept.departmentName, style: const TextStyle(fontSize: 13)),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedDeptIds.add(dept.departmentId);
                                    } else {
                                      selectedDeptIds.remove(dept.departmentId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final roleName = nameCtrl.text.trim();
                    if (roleName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a role name.')),
                      );
                      return;
                    }
                    setDialogState(() => isSaving = true);
                    try {
                      final user = ref.read(authProvider).user;
                      final companyId = user?.companyId ?? '';
                      final roleId = 'role_${DateTime.now().millisecondsSinceEpoch}';

                      final newRole = RoleModel(
                        roleId: roleId,
                        companyId: companyId,
                        roleName: roleName,
                        departmentIds: selectedDeptIds.toList(),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      final success = await ref.read(adminRolesProvider.notifier).saveRole(newRole);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Custom Role "$roleName" created successfully.')),
                          );
                          if (onCreated != null) onCreated(newRole);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Role already exists.')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Use Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Open text file import dialog
  static void showTextImportDialog(BuildContext context, WidgetRef ref) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: Color(0xFF059669), size: 22),
              SizedBox(width: 8),
              Text('Import Company Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: math.min(520, MediaQuery.of(context).size.width * 0.9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste or enter your company configuration text below:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: textCtrl,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '''DEPARTMENTS
Finance
Marketing
Sales
Engineering

DESIGNATIONS
Manager
HR Executive
Operations Manager

ROLES
Manager
HR Executive
Operations Supervisor

DESIGNATION RESPONSIBILITIES
Manager: Finance, Marketing, Sales
HR Executive: Human Resources, Finance

ROLE RESPONSIBILITIES
Manager: Finance, Marketing, Sales''',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final raw = textCtrl.text.trim();
                if (raw.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter configuration text to import.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _processAndPreviewImport(context, ref, raw);
              },
              child: const Text('Preview Import'),
            ),
          ],
        );
      },
    );
  }

  static void _processAndPreviewImport(BuildContext context, WidgetRef ref, String rawText) {
    final lines = rawText.split('\n');
    String currentSection = '';

    final List<String> parsedDepts = [];
    final List<String> parsedDesigs = [];
    final List<String> parsedRoles = [];
    final Map<String, List<String>> parsedDesigResps = {};
    final Map<String, List<String>> parsedRoleResps = {};

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final upper = trimmed.toUpperCase();
      if (upper == 'DEPARTMENTS' || upper == 'DEPARTMENTS:') {
        currentSection = 'DEPARTMENTS';
        continue;
      } else if (upper == 'DESIGNATIONS' || upper == 'DESIGNATIONS:') {
        currentSection = 'DESIGNATIONS';
        continue;
      } else if (upper == 'ROLES' || upper == 'ROLES:') {
        currentSection = 'ROLES';
        continue;
      } else if (upper.contains('DESIGNATION RESPONSIBILIT')) {
        currentSection = 'DESIGNATION_RESPONSIBILITIES';
        continue;
      } else if (upper.contains('ROLE RESPONSIBILIT')) {
        currentSection = 'ROLE_RESPONSIBILITIES';
        continue;
      }

      if (currentSection == 'DEPARTMENTS') {
        if (!parsedDepts.contains(trimmed)) parsedDepts.add(trimmed);
      } else if (currentSection == 'DESIGNATIONS') {
        if (!parsedDesigs.contains(trimmed)) parsedDesigs.add(trimmed);
      } else if (currentSection == 'ROLES') {
        if (!parsedRoles.contains(trimmed)) parsedRoles.add(trimmed);
      } else if (currentSection == 'DESIGNATION_RESPONSIBILITIES' || currentSection == 'ROLE_RESPONSIBILITIES') {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final depts = parts[1].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (currentSection == 'DESIGNATION_RESPONSIBILITIES') {
            parsedDesigResps[key] = depts;
          } else {
            parsedRoleResps[key] = depts;
          }
        }
      }
    }

    if (parsedDepts.isEmpty && parsedDesigs.isEmpty && parsedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse any valid configuration sections from text.')),
      );
      return;
    }

    // Show Preview Modal
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.rate_review_outlined, color: Color(0xFF5B4CF0), size: 22),
              SizedBox(width: 8),
              Text('Import Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: math.min(480, MediaQuery.of(context).size.width * 0.9),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (parsedDepts.isNotEmpty) ...[
                    const Text('Departments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ...parsedDepts.map((d) => Text('  ✓ $d', style: const TextStyle(fontSize: 12, color: Colors.green))),
                    const SizedBox(height: 10),
                  ],
                  if (parsedDesigs.isNotEmpty) ...[
                    const Text('Designations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ...parsedDesigs.map((d) => Text('  ✓ $d', style: const TextStyle(fontSize: 12, color: Colors.green))),
                    const SizedBox(height: 10),
                  ],
                  if (parsedRoles.isNotEmpty) ...[
                    const Text('Roles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ...parsedRoles.map((r) => Text('  ✓ $r', style: const TextStyle(fontSize: 12, color: Colors.green))),
                    const SizedBox(height: 10),
                  ],
                  if (parsedDesigResps.isNotEmpty) ...[
                    const Text('Responsibilities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ...parsedDesigResps.entries.map((e) => Text('  ${e.key} → ${e.value.join(' / ')}', style: const TextStyle(fontSize: 12))),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _commitImportedConfig(context, ref, parsedDepts, parsedDesigs, parsedRoles, parsedDesigResps);
              },
              child: const Text('Import & Save'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _commitImportedConfig(
    BuildContext context,
    WidgetRef ref,
    List<String> depts,
    List<String> desigs,
    List<String> roles,
    Map<String, List<String>> desigResps,
  ) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final companyId = user.companyId;

    final deptMap = <String, String>{}; // Name -> ID

    for (var name in depts) {
      final deptId = 'dept_${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'\s+'), '')}';
      final model = DepartmentModel(
        departmentId: deptId,
        companyId: companyId,
        departmentName: name,
        departmentCode: name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );
      await ref.read(adminDepartmentsProvider.notifier).saveDepartment(model);
      deptMap[name.toLowerCase()] = deptId;
    }

    for (var desigName in desigs) {
      final desigId = 'desig_${DateTime.now().millisecondsSinceEpoch}_${desigName.replaceAll(RegExp(r'\s+'), '')}';
      final respDeptNames = desigResps[desigName] ?? [];
      final respDeptIds = respDeptNames.map((n) => deptMap[n.toLowerCase()]).whereType<String>().toList();

      final desigModel = DesignationModel(
        designationId: desigId,
        companyId: companyId,
        designationName: desigName,
        designationLevel: 1,
        managedDepartmentIds: respDeptIds,
        canManageDepartments: respDeptIds.length > 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(adminDesignationsProvider.notifier).saveDesignation(desigModel);
    }

    for (var roleName in roles) {
      final roleId = 'role_${DateTime.now().millisecondsSinceEpoch}_${roleName.replaceAll(RegExp(r'\s+'), '')}';
      final roleModel = RoleModel(
        roleId: roleId,
        companyId: companyId,
        roleName: roleName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ref.read(adminRolesProvider.notifier).saveRole(roleModel);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration imported and saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
