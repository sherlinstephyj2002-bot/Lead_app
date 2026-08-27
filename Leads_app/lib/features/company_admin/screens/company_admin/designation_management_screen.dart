import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/department_model.dart';
import 'package:worktrack/features/company_admin/models/designation_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/constants/feature_flags.dart';
import 'package:worktrack/features/company_admin/widgets/company_admin/searchable_paginated_table.dart';
import 'package:worktrack/shared/utils/app_notification.dart';

class DesignationManagementScreen extends ConsumerStatefulWidget {
  const DesignationManagementScreen({super.key});

  @override
  ConsumerState<DesignationManagementScreen> createState() => _DesignationManagementScreenState();
}

class _DesignationManagementScreenState extends ConsumerState<DesignationManagementScreen> {
  String _selectedStatusFilter = 'All';
  String _selectedDeptFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final desigsAsync = ref.watch(adminDesignationsProvider);
    final deptsAsync = ref.watch(adminDepartmentsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Designation Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Configure job roles, hierarchy levels and department links', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(adminDesignationsProvider.notifier).loadDesignations();
              ref.read(adminDepartmentsProvider.notifier).loadDepartments();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Bar
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 8),
                      const Text('Department Filter:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      deptsAsync.when(
                        loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const Text('Error'),
                        data: (depts) {
                          return DropdownButton<String>(
                            value: _selectedDeptFilter,
                            elevation: 2,
                            underline: const SizedBox(),
                            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                            items: ['All', ...depts.map((d) => d.name)].map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedDeptFilter = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 8),
                      const Text('Status Filter:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedStatusFilter,
                        elevation: 2,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                        items: ['All', 'Active', 'Suspended', 'Archived'].map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatusFilter = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: desigsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading designations: $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (desigs) {
                  final depts = deptsAsync.value ?? [];

                  final filteredDesigs = desigs.where((desig) {
                    if (_selectedStatusFilter != 'All') {
                      if (_selectedStatusFilter == 'Active' && desig.status.toLowerCase() != 'active') return false;
                      if (_selectedStatusFilter == 'Suspended' && desig.status.toLowerCase() != 'suspended') return false;
                      if (_selectedStatusFilter == 'Archived' && desig.status.toLowerCase() != 'archived') return false;
                    }
                    if (_selectedDeptFilter != 'All') {
                      final targetDept = depts.firstWhere((d) => d.name == _selectedDeptFilter, orElse: () => DepartmentModel(departmentId: '', companyId: '', departmentName: '', departmentCode: '', createdAt: DateTime.now(), updatedAt: DateTime.now(), createdBy: ''));
                      if (desig.departmentId != targetDept.departmentId) return false;
                    }
                    return true;
                  }).toList();

                  return SearchablePaginatedTable<DesignationModel>(
                    items: filteredDesigs,
                    searchPlaceholder: 'Search designations by name...',
                    searchMatcher: (desig, query) {
                      return desig.designationName.toLowerCase().contains(query.toLowerCase());
                    },
                    headerAction: ElevatedButton.icon(
                      onPressed: () => _showDesigForm(context, depts: depts),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Designation', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    columns: [
                      const DataColumn(label: Text('Designation Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                      if (FeatureFlags.enableDesignationLevels)
                        const DataColumn(label: Text('Hierarchy Level', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rowBuilder: (desig) {
                      final deptName = depts
                          .firstWhere((d) => d.departmentId == desig.departmentId,
                              orElse: () => DepartmentModel(departmentId: '', companyId: '', departmentName: 'N/A', departmentCode: 'N/A', createdAt: DateTime.now(), updatedAt: DateTime.now(), createdBy: ''))
                          .name;
                      
                      Color statusColor;
                      switch (desig.status.toLowerCase()) {
                        case 'active':
                          statusColor = Colors.green;
                          break;
                        case 'archived':
                          statusColor = Colors.grey;
                          break;
                        default:
                          statusColor = Colors.orange;
                      }

                      return [
                        DataCell(Text(desig.designationName, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(deptName)),
                        if (FeatureFlags.enableDesignationLevels)
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Level ${desig.designationLevel}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ),
                        DataCell(Text(desig.description.isNotEmpty ? desig.description : 'No description')),
                        DataCell(
                          Chip(
                            label: Text(desig.status.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: statusColor,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                onPressed: () => _showDesigForm(context, existingDesig: desig, depts: depts),
                              ),
                              if (desig.status.toLowerCase() == 'archived')
                                IconButton(
                                  icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.green, size: 20),
                                  tooltip: 'Restore Designation',
                                  onPressed: () => _confirmRestore(context, desig.designationId, desig.designationName),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.archive_outlined, color: Colors.orange, size: 20),
                                  tooltip: 'Archive Designation',
                                  onPressed: () => _confirmArchive(context, desig.designationId, desig.designationName),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Delete Designation',
                                onPressed: () {
                                  final employees = ref.read(adminEmployeesProvider).value ?? [];
                                  final count = employees.where((e) => e.designationId == desig.designationId || e.designation == desig.designationName).length;
                                  _handleDeleteDesignation(context, desig, count);
                                },
                              ),
                            ],
                          ),
                        ),
                      ];
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

  void _showDesigForm(
    BuildContext context, {
    DesignationModel? existingDesig,
    required List<DepartmentModel> depts,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingDesig?.designationName ?? '');
    final descCtrl = TextEditingController(text: existingDesig?.description ?? '');
    final levelCtrl = TextEditingController(text: existingDesig?.designationLevel.toString() ?? '1');
    
    // Only display active departments in form dropdown selection, but preserve existing one if editing
    final eligibleDepts = depts.where((d) {
      if (d.status == 'active') return true;
      if (existingDesig != null && d.departmentId == existingDesig.departmentId) return true;
      return false;
    }).toList();

    String? selectedDeptId = existingDesig?.departmentId ?? (eligibleDepts.isNotEmpty ? eligibleDepts.first.departmentId : null);
    String selectedStatus = existingDesig?.status ?? 'active';

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existingDesig == null ? 'Add Designation' : 'Edit Designation'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Designation Name *', prefixIcon: Icon(Icons.badge_outlined)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedDeptId,
                        decoration: const InputDecoration(labelText: 'Department Link', prefixIcon: Icon(Icons.business_rounded)),
                        items: eligibleDepts.map((d) {
                          return DropdownMenuItem(value: d.departmentId, child: Text(d.name));
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            selectedDeptId = val;
                          });
                        },
                        validator: (v) => v == null ? 'Department is required' : null,
                      ),
                      if (FeatureFlags.enableDesignationLevels) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: levelCtrl,
                          decoration: const InputDecoration(labelText: 'Hierarchy Level (e.g. 1 for Executive, 5 for VP) *', prefixIcon: Icon(Icons.leaderboard_outlined)),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!FeatureFlags.enableDesignationLevels) return null;
                            if (v == null || v.isEmpty) return 'Level is required';
                            if (int.tryParse(v) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline_rounded)),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                          DropdownMenuItem(value: 'archived', child: Text('Archived (Soft Delete)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final user = ref.read(authProvider).user;
                            if (user == null) return;

                            setModalState(() { isSubmitting = true; });

                            final newDesig = DesignationModel(
                              designationId: existingDesig?.designationId ?? const Uuid().v4(),
                              designationName: nameCtrl.text.trim(),
                              designationLevel: int.parse(levelCtrl.text.trim()),
                              departmentId: selectedDeptId!,
                              description: descCtrl.text.trim(),
                              companyId: user.companyId,
                              status: selectedStatus,
                              createdAt: existingDesig?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            try {
                              final success = await ref.read(adminDesignationsProvider.notifier).saveDesignation(newDesig);
                              if (context.mounted) {
                                if (success) {
                                  Navigator.pop(ctx);
                                  AppNotification.showSuccess(context, 'Designation saved successfully.');
                                } else {
                                  setModalState(() { isSubmitting = false; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('A designation with this name already exists in this company.'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() { isSubmitting = false; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save designation: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmArchive(BuildContext context, String id, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Disable Designation?'),
            ],
          ),
          content: Text('Are you sure you want to disable this designation? New employee assignments will be prevented.'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminDesignationsProvider.notifier).deleteDesignation(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          AppNotification.showSuccess(context, 'Designation disabled successfully.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to disable: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Disable'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(BuildContext context, String id, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Restore Designation'),
            ],
          ),
          content: Text('Are you sure you want to restore designation "$name" back to active status?'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminDesignationsProvider.notifier).restoreDesignation(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          AppNotification.showSuccess(context, 'Designation restored successfully.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to restore: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeleteDesignation(BuildContext context, DesignationModel desig, int assignedEmpCount) {
    if (assignedEmpCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Cannot Delete Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'Designation "${desig.designationName}" cannot be deleted because $assignedEmpCount employee(s) are assigned to it.\n\nPlease reassign these employees before deleting.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      bool isProcessing = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setConfirmState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text('Are you sure you want to permanently delete designation "${desig.designationName}"? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setConfirmState(() { isProcessing = true; });
                        try {
                          await ref.read(adminDesignationsProvider.notifier).permanentlyDeleteDesignation(desig.designationId);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppNotification.showSuccess(context, 'Designation deleted successfully.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setConfirmState(() { isProcessing = false; });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Delete'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
