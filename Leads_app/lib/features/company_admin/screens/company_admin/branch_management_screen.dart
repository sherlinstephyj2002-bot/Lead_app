import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/branch_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/company_admin/widgets/company_admin/searchable_paginated_table.dart';
import 'package:worktrack/shared/utils/app_validators.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  ConsumerState<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends ConsumerState<BranchManagementScreen> {
  String _selectedStatusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(adminBranchesProvider);
    final employees = ref.watch(adminEmployeesProvider).value ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branch Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Manage company office branches and retail outlets', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(adminBranchesProvider.notifier).loadBranches(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                child: Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, color: Color(0xFF64748B), size: 20),
                    const SizedBox(width: 8),
                    const Text('Status Filter:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _selectedStatusFilter,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'active', child: Text('Active Only')),
                        DropdownMenuItem(value: 'archived', child: Text('Archived Only')),
                      ],
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
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: branchesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading branches: $err', style: const TextStyle(color: Colors.red))),
                data: (branches) {
                  final filtered = branches.where((b) {
                    if (_selectedStatusFilter == 'All') return b.status != 'deleted';
                    return b.status.toLowerCase() == _selectedStatusFilter.toLowerCase();
                  }).toList();

                  return SearchablePaginatedTable<BranchModel>(
                    items: filtered,
                    searchPlaceholder: 'Search branches by name or code...',
                    searchMatcher: (branch, query) {
                      final q = query.toLowerCase();
                      return branch.branchName.toLowerCase().contains(q) ||
                          branch.branchCode.toLowerCase().contains(q);
                    },
                    headerAction: ElevatedButton.icon(
                      onPressed: () => _showBranchForm(context, employees: employees),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Branch', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                    columns: const [
                      DataColumn(label: Text('Branch Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rowBuilder: (branch) {
                      final manager = branch.branchManagerId != null
                          ? employees.cast<dynamic>().firstWhere((e) => e.uid == branch.branchManagerId, orElse: () => null)
                          : null;
                      final managerName = manager != null ? manager.name : 'Not Assigned';
                      final statusColor = branch.status.toLowerCase() == 'active' ? Colors.green : Colors.grey;

                      return [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(branch.branchName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Mgr: $managerName', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(Text(branch.branchCode)),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(branch.email, style: const TextStyle(fontSize: 12)),
                              Text(branch.phone, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        DataCell(Text('${branch.city}, ${branch.state}')),
                        DataCell(
                          Chip(
                            label: Text(branch.status.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: statusColor,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_rounded, color: Colors.green, size: 20),
                                tooltip: 'View Details',
                                onPressed: () => _viewBranchDetails(context, branch, managerName),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                tooltip: 'Edit',
                                onPressed: () => _showBranchForm(context, existingBranch: branch, employees: employees),
                              ),
                              if (branch.status.toLowerCase() == 'archived')
                                IconButton(
                                  icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.green, size: 20),
                                  tooltip: 'Restore',
                                  onPressed: () => _confirmRestore(context, branch.branchId, branch.branchName),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.archive_outlined, color: Colors.orange, size: 20),
                                  tooltip: 'Archive',
                                  onPressed: () => _confirmArchive(context, branch.branchId, branch.branchName),
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

  void _showBranchForm(BuildContext context, {BranchModel? existingBranch, required List<dynamic> employees}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingBranch?.branchName ?? '');
    final codeCtrl = TextEditingController(text: existingBranch?.branchCode ?? '');
    final emailCtrl = TextEditingController(text: existingBranch?.email ?? '');
    final phoneCtrl = TextEditingController(text: existingBranch?.phone ?? '');
    final addrCtrl = TextEditingController(text: existingBranch?.address ?? '');
    final cityCtrl = TextEditingController(text: existingBranch?.city ?? '');
    final stateCtrl = TextEditingController(text: existingBranch?.state ?? '');
    final countryCtrl = TextEditingController(text: existingBranch?.country ?? '');
    final postalCtrl = TextEditingController(text: existingBranch?.postalCode ?? '');
    
    String? selectedManagerId = existingBranch?.branchManagerId;

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(existingBranch == null ? 'Add Branch' : 'Edit Branch'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Branch Name *', prefixIcon: Icon(Icons.business_outlined)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Branch Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Branch Code *', prefixIcon: Icon(Icons.qr_code_rounded)),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Branch Code is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final seenEmp = <String>{};
                          final uniqueEmployees = employees.where((e) => e != null && seenEmp.add(e.uid as String)).toList();
                          final validManagerId = uniqueEmployees.any((e) => e.uid == selectedManagerId)
                              ? selectedManagerId
                              : null;
                          return DropdownButtonFormField<String>(
                            value: validManagerId,
                            decoration: const InputDecoration(labelText: 'Branch Manager (Optional)', prefixIcon: Icon(Icons.person_outline_rounded)),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('None')),
                              ...uniqueEmployees.map((e) => DropdownMenuItem<String>(value: e.uid, child: Text(e.name))),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedManagerId = val;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => AppValidators.validateCompanyEmail(v, isRequired: false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                        keyboardType: TextInputType.phone,
                        validator: (v) => AppValidators.validateCompanyPhone(v, isRequired: false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addrCtrl,
                        decoration: const InputDecoration(labelText: 'Street Address', prefixIcon: Icon(Icons.location_on_outlined)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              decoration: const InputDecoration(labelText: 'City / Town'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stateCtrl,
                              decoration: const InputDecoration(labelText: 'State / Province / Region'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: countryCtrl,
                              decoration: const InputDecoration(labelText: 'Country / Region'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: postalCtrl,
                              decoration: const InputDecoration(labelText: 'Postal Code'),
                            ),
                          ),
                        ],
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

                            final branch = BranchModel(
                              branchId: existingBranch?.branchId ?? const Uuid().v4(),
                              companyId: user.companyId,
                              branchName: nameCtrl.text.trim(),
                              branchCode: codeCtrl.text.trim(),
                              branchManagerId: selectedManagerId,
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              address: addrCtrl.text.trim(),
                              city: cityCtrl.text.trim(),
                              state: stateCtrl.text.trim(),
                              country: countryCtrl.text.trim(),
                              postalCode: postalCtrl.text.trim(),
                              status: existingBranch?.status ?? 'active',
                              createdAt: existingBranch?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                            );

                            try {
                              final error = await ref.read(adminBranchesProvider.notifier).saveBranch(branch);
                              if (context.mounted) {
                                if (error != null) {
                                  setModalState(() { isSubmitting = false; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error), backgroundColor: Colors.red),
                                  );
                                } else {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Branch saved successfully.'), backgroundColor: Colors.green),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() { isSubmitting = false; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save branch: $e'), backgroundColor: Colors.red),
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

  void _viewBranchDetails(BuildContext context, BranchModel branch, String managerName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(branch.branchName, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem('Branch Code', branch.branchCode),
            _buildDetailItem('Status', branch.status.toUpperCase()),
            _buildDetailItem('Branch Manager', managerName),
            _buildDetailItem('Email', branch.email.isNotEmpty ? branch.email : 'N/A'),
            _buildDetailItem('Phone', branch.phone.isNotEmpty ? branch.phone : 'N/A'),
            _buildDetailItem('Address', branch.address.isNotEmpty ? branch.address : 'N/A'),
            _buildDetailItem('City/State/Postal', '${branch.city} / ${branch.state} / ${branch.postalCode}'),
            _buildDetailItem('Country / Region', branch.country.isNotEmpty ? branch.country : 'N/A'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _confirmArchive(BuildContext context, String id, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          title: const Text('Archive Branch'),
          content: Text('Are you sure you want to archive branch "$name"?'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminBranchesProvider.notifier).archiveBranch(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Branch archived successfully.'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to archive: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Archive', style: TextStyle(color: Colors.white)),
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
          title: const Text('Restore Branch'),
          content: Text('Are you sure you want to restore branch "$name" back to active status?'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminBranchesProvider.notifier).restoreBranch(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Branch restored successfully.'), backgroundColor: Colors.green),
                          );
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
}
