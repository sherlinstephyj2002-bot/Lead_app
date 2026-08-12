import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/constants/feature_flags.dart';
import 'package:worktrack/shared/services/subscription_service.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/utils/employee_id_generator.dart';
import 'package:worktrack/shared/utils/app_validators.dart';
import 'package:worktrack/shared/widgets/company_logo_avatar.dart';
import 'package:worktrack/shared/widgets/app_user_avatar.dart';
import 'package:worktrack/shared/widgets/subscription_upgrade_dialog.dart';
import 'package:worktrack/shared/models/department_model.dart';
import 'package:worktrack/features/company_admin/models/designation_model.dart';
import 'package:worktrack/features/company_admin/models/shift_model.dart';
import 'package:worktrack/features/company_admin/models/branch_model.dart';
import 'package:worktrack/features/company_admin/models/salary_structure_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/company_admin/widgets/company_admin/searchable_paginated_table.dart';
import 'employee_profile_screen.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _HRAdminMapping {
  static final List<String> employmentTypes = ['Full-time', 'Part-time', 'Contract', 'Internship'];
}

class _EmployeeManagementScreenState extends ConsumerState<EmployeeManagementScreen> {
  InputDecoration _inputStyle(String label, IconData icon, {String? hint, String? helperText, int? helperMaxLines, BuildContext? context}) {
    final isDark = context != null ? Theme.of(context).brightness == Brightness.dark : false;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperMaxLines: helperMaxLines,
      hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'),
      labelStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      prefixIcon: Icon(icon, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF5B4CF0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
      ),
    );
  }

  String _selectedDeptFilter = 'All';
  String _selectedDesigFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    if (currentUser == null ||
        (currentUser.role != UserRoles.superAdmin &&
         currentUser.role != UserRoles.companyAdmin &&
         currentUser.role != UserRoles.hrAdmin &&
         currentUser.role != UserRoles.hrExecutive)) {
      return const Scaffold(
        body: Center(child: Text('Access Denied. Only Company Admins and HR Users can view this page.')),
      );
    }

    final employeesAsync = ref.watch(adminEmployeesProvider);
    final deptsAsync = ref.watch(adminDepartmentsProvider);
    final desigsAsync = ref.watch(adminDesignationsProvider);
    final shiftsAsync = ref.watch(adminShiftsProvider);
    final branchesAsync = ref.watch(adminBranchesProvider);
    final structuresAsync = ref.watch(adminSalaryStructuresProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Employee Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF5B4CF0), fontFamily: 'Inter')),
            Text('Manage staff details, shifts, and active directory', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter')),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5B4CF0)),
        backgroundColor: cardBg,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: borderCol,
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B4CF0)),
            onPressed: () {
              ref.read(adminEmployeesProvider.notifier).loadEmployees();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF111827).withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                  });
                },
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1F)),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, department...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Inter'),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filters scroll list
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Department Dropdown Filter
                  deptsAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (deptsList) {
                      final deptNames = ['All', ...deptsList.map((d) => d.name)];
                      final validDeptFilter = deptNames.contains(_selectedDeptFilter) ? _selectedDeptFilter : 'All';
                      return PopupMenuButton<String>(
                        onSelected: (val) {
                          setState(() {
                            _selectedDeptFilter = val;
                          });
                        },
                        itemBuilder: (ctx) => deptNames.map((d) => PopupMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Dept: $validDeptFilter',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.expand_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Designation Dropdown Filter
                  desigsAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (desigsList) {
                      final desigNames = ['All', ...desigsList.map((d) => d.designationName)];
                      final validDesigFilter = desigNames.contains(_selectedDesigFilter) ? _selectedDesigFilter : 'All';
                      return PopupMenuButton<String>(
                        onSelected: (val) {
                          setState(() {
                            _selectedDesigFilter = val;
                          });
                        },
                        itemBuilder: (ctx) => desigNames.map((d) => PopupMenuItem(value: d, child: Text(d, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Desig: $validDesigFilter',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.expand_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Status Dropdown Filter
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        _selectedStatusFilter = val;
                      });
                    },
                    itemBuilder: (ctx) => ['All', 'Active', 'Suspended'].map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Status: $_selectedStatusFilter',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title & Add Employee Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Staff List',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF191C1F),
                  ),
                ),
                deptsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (depts) => desigsAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (desigs) => shiftsAsync.when(
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                      data: (shifts) => branchesAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                        data: (branches) => structuresAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (structures) => employeesAsync.when(
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                            data: (employees) => ElevatedButton.icon(
                              onPressed: () => _showEmployeeForm(
                                context,
                                depts: depts,
                                desigs: desigs,
                                employees: employees,
                                shifts: shifts,
                                branches: branches,
                                structures: structures,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                              label: const Text('Add Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B4CF0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Employee Cards List
            Expanded(
              child: employeesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading employees: $err', style: const TextStyle(color: Colors.red, fontFamily: 'Inter')),
                ),
                data: (employees) {
                  final filteredEmployees = employees.where((emp) {
                    if (emp.role == UserRoles.companyAdmin || emp.role == UserRoles.superAdmin) return false;
                    if (_selectedDeptFilter != 'All' && emp.department != _selectedDeptFilter) return false;
                    if (_selectedDesigFilter != 'All' && emp.designation != _selectedDesigFilter) return false;
                    if (_selectedStatusFilter != 'All' && emp.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) return false;
                    return true;
                  }).toList();

                  final query = _searchQuery.trim().toLowerCase();
                  final displayEmployees = filteredEmployees.where((emp) {
                    if (query.isEmpty) return true;
                    return emp.name.toLowerCase().contains(query) ||
                        emp.email.toLowerCase().contains(query) ||
                        (emp.employeeId?.toLowerCase().contains(query) ?? false) ||
                        (emp.department?.toLowerCase().contains(query) ?? false) ||
                        (emp.designation?.toLowerCase().contains(query) ?? false);
                  }).toList();

                  final depts = deptsAsync.value ?? [];
                  final desigs = desigsAsync.value ?? [];
                  final shifts = shiftsAsync.value ?? [];
                  final branches = branchesAsync.value ?? [];
                  final structures = structuresAsync.value ?? [];

                  if (displayEmployees.isEmpty) {
                    return const Center(
                      child: Text(
                        'No employees found matching criteria.',
                        style: TextStyle(fontFamily: 'Inter', color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayEmployees.length,
                    itemBuilder: (ctx, idx) => _buildEmployeeCard(
                      emp: displayEmployees[idx],
                      employees: employees,
                      depts: depts,
                      desigs: desigs,
                      shifts: shifts,
                      branches: branches,
                      structures: structures,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCard({
    required UserModel emp,
    required List<UserModel> employees,
    required List<DepartmentModel> depts,
    required List<DesignationModel> desigs,
    required List<ShiftModel> shifts,
    required List<BranchModel> branches,
    required List<SalaryStructureModel> structures,
  }) {
    final isFirstLoginPending = (emp.tempPassword != null && emp.tempPassword!.isNotEmpty) || emp.firstLogin;
    final statusLabel = isFirstLoginPending ? 'FIRST LOGIN PENDING' : emp.status.toUpperCase();
    final statusColor = isFirstLoginPending
        ? const Color(0xFF1D4ED8)
        : (emp.status.toLowerCase() == 'active' ? const Color(0xFF007834) : const Color(0xFFBA1A1A));
    final statusBg = isFirstLoginPending
        ? const Color(0xFFDBEAFE)
        : (emp.status.toLowerCase() == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2));
    final joinedStr = emp.joiningDate != null
        ? DateFormat('dd MMM yyyy').format(emp.joiningDate!)
        : 'N/A';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _viewEmployeeProfile(context, emp, employees),
          borderRadius: BorderRadius.circular(16),
          hoverColor: const Color(0xFF5B4CF0).withValues(alpha: 0.04),
          splashColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF5B4CF0).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Top Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppUserAvatar(
                  radius: 20,
                  user: emp,
                  companyId: emp.companyId,
                  backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.08),
                  iconColor: const Color(0xFF5B4CF0),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF191C1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        emp.employeeId ?? 'No ID',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            // Details Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEPT / ROLE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${emp.department ?? "No Dept"} / ${emp.designation ?? "No Designation"}' +
                        (emp.role != UserRoles.employee ? ' • ${UserModel.denormalizeRole(emp.role)}' : ''),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF191C1F),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMPLOYMENT',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        emp.employmentType ?? 'N/A',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF191C1F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOINED DATE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        joinedStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF191C1F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (FeatureFlags.enableBranchManagement)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BRANCH',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emp.branchName ?? 'Unassigned',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF191C1F),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Divider(height: 24, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            // Bottom Action Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF5B4CF0), size: 20),
                  tooltip: 'Edit Profile',
                  onPressed: () => _showEmployeeForm(context, existingEmp: emp, depts: depts, desigs: desigs, employees: employees, shifts: shifts, branches: branches, structures: structures),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 20),
                  tooltip: 'More Actions',
                  onSelected: (val) {
                    if (val == 'shift') {
                      _showShiftDialog(context, emp, shifts);
                    } else if (val == 'dept_transfer') {
                      _showTransferDialog(context, emp, depts);
                    } else if (val == 'manager_transfer') {
                      _showManagerTransferDialog(context, emp, employees);
                    } else if (val == 'toggle_status') {
                      _confirmToggleStatus(context, emp);
                    } else if (val == 'delete') {
                      _confirmDelete(context, emp.uid, emp.name);
                    } else if (val == 'reset_password') {
                      _handleResetPassword(context, emp.uid, emp.name);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'shift',
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('Assign Shift', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'dept_transfer',
                      child: Row(
                        children: [
                          Icon(Icons.compare_arrows_rounded, color: Colors.teal, size: 18),
                          SizedBox(width: 8),
                          Text('Transfer Department', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'manager_transfer',
                      child: Row(
                        children: [
                          Icon(Icons.supervised_user_circle_outlined, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('Transfer Manager', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            emp.status.toLowerCase() == 'active' ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            color: emp.status.toLowerCase() == 'active' ? Colors.orange : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(emp.status.toLowerCase() == 'active' ? 'Deactivate Account' : 'Activate Account', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text('Reset Password', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text('Delete Account', style: TextStyle(color: Colors.red, fontFamily: 'Inter', fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  String _normalizeRole(String firestoreValue) {
    final val = firestoreValue.trim().toLowerCase().replaceAll(' ', '_');
    switch (val) {
      case 'company_admin':
      case 'company admin':
        return UserRoles.companyAdmin;
      case 'hr_admin':
      case 'hr admin':
        return UserRoles.hrAdmin;
      case 'hr_executive':
      case 'hr executive':
        return UserRoles.hrExecutive;
      case 'hr':
        return UserRoles.hr;
      case 'manager':
        return UserRoles.manager;
      case 'team_leader':
      case 'team leader':
        return UserRoles.teamLeader;
      case 'employee':
        return UserRoles.employee;
      case 'super_admin':
      case 'super admin':
        return UserRoles.superAdmin;
      default:
        return val;
    }
  }

  String _displayRole(String value) {
    switch (value) {
      case UserRoles.companyAdmin:
        return 'Company Admin';
      case UserRoles.hrAdmin:
        return 'HR Admin';
      case UserRoles.hrExecutive:
        return 'HR Executive';
      case UserRoles.hr:
        return 'HR';
      case UserRoles.manager:
        return 'Manager';
      case UserRoles.teamLeader:
        return 'Team Leader';
      case UserRoles.employee:
        return 'Employee';
      case UserRoles.superAdmin:
        return 'Super Admin';
      default:
        if (value.isEmpty) return '';
        return value.split('_').map((word) {
          if (word.toLowerCase() == 'hr') return 'HR';
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
    }
  }

  void _showEmployeeForm(
    BuildContext context, {
    UserModel? existingEmp,
    required List<DepartmentModel> depts,
    required List<DesignationModel> desigs,
    required List<UserModel> employees,
    required List<ShiftModel> shifts,
    required List<BranchModel> branches,
    List<SalaryStructureModel> structures = const [],
  }) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingEmp?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingEmp?.phoneNumber ?? '');
    final personalEmailCtrl = TextEditingController(text: existingEmp?.employeeEmail ?? '');

    String? selectedDeptId = existingEmp?.departmentId;
    String? selectedDesigId = existingEmp?.designationId;
    String? selectedManagerId = existingEmp?.managerId;
    String? selectedShiftId = existingEmp?.shiftId;
    String? selectedBranchId = existingEmp?.branchId;
    String? selectedSalaryStructureId = existingEmp?.salaryStructureId;
    String selectedEmpType = existingEmp?.employmentType ?? _HRAdminMapping.employmentTypes.first;
    DateTime selectedJoinDate = existingEmp?.joiningDate ?? DateTime.now();

    String selectedRole = _normalizeRole(existingEmp?.role ?? UserRoles.employee);
    String selectedStatus = (existingEmp?.status ?? 'active').toLowerCase().trim();

    String? _uploadedImageUrl = existingEmp?.profileImageUrl;

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            Widget _buildReadOnlyFormWidget(String label, String value) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            }

            // Uniqueness and fallback validations for every dropdown to prevent crashes
            final activeDepts = depts.where((d) {
              if (d.status.toLowerCase() == 'active') return true;
              if (existingEmp != null && d.departmentId == selectedDeptId) return true;
              return false;
            }).toList();
            final seenDepts = <String>{};
            final uniqueDepts = activeDepts.where((d) => seenDepts.add(d.departmentId)).toList();
            final validDeptId = (selectedDeptId != null && uniqueDepts.any((d) => d.departmentId == selectedDeptId))
                ? selectedDeptId
                : null;

            final activeDesigs = desigs.where((d) {
              if (d.status.toLowerCase() == 'active') return true;
              if (existingEmp != null && d.designationId == selectedDesigId) return true;
              return false;
            }).toList();
            final seenDesigs = <String>{};
            final uniqueDesigs = activeDesigs.where((d) => seenDesigs.add(d.designationId)).toList();
            final validDesigId = (selectedDesigId != null && uniqueDesigs.any((d) => d.designationId == selectedDesigId))
                ? selectedDesigId
                : null;

            final managerList = employees.where((u) => u.uid != existingEmp?.uid).toList();
            final seenManagers = <String>{};
            final uniqueManagers = managerList.where((e) => seenManagers.add(e.uid)).toList();
            final validManagerId = (selectedManagerId != null && uniqueManagers.any((e) => e.uid == selectedManagerId))
                ? selectedManagerId
                : null;

            final seenEmploymentTypes = <String>{};
            final uniqueEmploymentTypes = _HRAdminMapping.employmentTypes.where((type) => seenEmploymentTypes.add(type)).toList();
            final validEmpType = uniqueEmploymentTypes.contains(selectedEmpType)
                ? selectedEmpType
                : uniqueEmploymentTypes.firstWhere(
                    (type) => type.toLowerCase() == selectedEmpType.toLowerCase().trim(),
                    orElse: () => uniqueEmploymentTypes.isNotEmpty ? uniqueEmploymentTypes.first : 'Full-time',
                  );

            final activeShifts = shifts.where((s) {
              if (s.status.toLowerCase() == 'active') return true;
              if (existingEmp != null && s.shiftId == selectedShiftId) return true;
              return false;
            }).toList();
            final seenShifts = <String>{};
            final uniqueShifts = activeShifts.where((s) => seenShifts.add(s.shiftId)).toList();
            final validShiftId = (selectedShiftId != null && uniqueShifts.any((s) => s.shiftId == selectedShiftId))
                ? selectedShiftId
                : null;

            final activeBranches = branches.where((b) {
              if (b.status.toLowerCase() == 'active') return true;
              if (existingEmp != null && b.branchId == selectedBranchId) return true;
              return false;
            }).toList();
            final seenBranches = <String>{};
            final uniqueBranches = activeBranches.where((b) => seenBranches.add(b.branchId)).toList();
            final validBranchId = (selectedBranchId != null && uniqueBranches.any((b) => b.branchId == selectedBranchId))
                ? selectedBranchId
                : (uniqueBranches.isNotEmpty ? uniqueBranches.first.branchId : null);

            final activeStructures = structures.where((s) => s.status == 'active').toList();
            final seenStructures = <String>{};
            final uniqueStructures = activeStructures.where((s) => seenStructures.add(s.structureId)).toList();
            final validSalaryStructureId = (selectedSalaryStructureId != null && uniqueStructures.any((s) => s.structureId == selectedSalaryStructureId))
                ? selectedSalaryStructureId
                : null;

            final roleItems = [
              UserRoles.superAdmin,
              UserRoles.companyAdmin,
              UserRoles.hrAdmin,
              UserRoles.hrExecutive,
              UserRoles.hr,
              UserRoles.manager,
              UserRoles.teamLeader,
              UserRoles.employee,
            ];
            final validRole = roleItems.contains(selectedRole)
                ? selectedRole
                : UserRoles.employee;

            final statusItems = ['active', 'suspended', 'deleted'];
            final validStatus = statusItems.contains(selectedStatus.toLowerCase().trim())
                ? selectedStatus.toLowerCase().trim()
                : 'active';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
              title: Text(existingEmp == null ? 'Add Employee' : 'Edit Employee Details', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B1B24))),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Full Name *', Icons.person_outline_rounded, context: context),
                        onChanged: (val) => setModalState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      if (existingEmp == null) ...[
                        Builder(
                          builder: (context) {
                            final companyObj = ref.watch(companyProvider).value;
                            final adminUser = ref.watch(authProvider).user;
                            final activeCompanyName = companyObj?.name ?? adminUser?.companyName;

                            final generatedCreds = EmployeeIdGenerator.generateCredentials(
                              employeeName: nameCtrl.text.trim(),
                              existingEmployees: employees,
                              companyName: activeCompanyName,
                              company: companyObj,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Auto-Generated Employee Credentials',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Employee ID', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                            const SizedBox(height: 2),
                                            Text(
                                              generatedCreds.employeeId,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Company Login Email', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                            const SizedBox(height: 2),
                                            Text(
                                              generatedCreds.companyEmail,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        TextFormField(
                          controller: personalEmailCtrl,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                          decoration: _inputStyle('Personal Email *', Icons.email_outlined, hint: 'e.g. employee@gmail.com', helperText: 'Note: Personal email used for correspondence. Employee ID and internal login email are automatically assigned.', helperMaxLines: 2, context: context),
                          validator: (v) {
                            final err = AppValidators.validatePersonalEmail(v, isRequired: true);
                            if (err != null) return err;
                            return AppValidators.validatePersonalEmailUniqueness(v, employees);
                          },
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _buildReadOnlyFormWidget('Employee ID', existingEmp.employeeId ?? 'N/A'),
                        _buildReadOnlyFormWidget('Company Code', existingEmp.companyCode ?? 'N/A'),
                        _buildReadOnlyFormWidget('Company Name', existingEmp.companyName),
                        TextFormField(
                          controller: personalEmailCtrl,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                          decoration: _inputStyle('Personal Email *', Icons.email_outlined, context: context),
                          validator: (v) {
                            final err = AppValidators.validatePersonalEmail(v, isRequired: true);
                            if (err != null) return err;
                            return AppValidators.validatePersonalEmailUniqueness(v, employees, currentUid: existingEmp.uid);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyFormWidget('Internal Company Email', existingEmp.companyEmail ?? existingEmp.hiddenEmail ?? existingEmp.email),
                        _buildReadOnlyFormWidget('Created Date', DateFormat('dd MMM yyyy, hh:mm a').format(existingEmp.createdAt)),
                      ],
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Phone Number', Icons.phone_iphone_rounded, context: context),
                        validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validDeptId,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Department', Icons.business_rounded, context: context),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('-- None / Unassigned --')),
                          ...uniqueDepts.map((d) {
                            return DropdownMenuItem(value: d.departmentId, child: Text(d.name));
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedDeptId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validDesigId,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Designation', Icons.badge_outlined, context: context),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('-- None / Unassigned --')),
                          ...uniqueDesigs.map((d) {
                            return DropdownMenuItem(value: d.designationId, child: Text(d.designationName));
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedDesigId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validRole,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Role *', Icons.admin_panel_settings_rounded, context: context),
                        items: roleItems.map((r) {
                          return DropdownMenuItem(value: r, child: Text(_displayRole(r)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validStatus,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Status *', Icons.info_outline_rounded, context: context),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                          DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validManagerId,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Reporting Manager (Optional)', Icons.supervised_user_circle_outlined, context: context),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('None')),
                          ...uniqueManagers.map((e) {
                            return DropdownMenuItem(value: e.uid, child: Text(e.name));
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedManagerId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validEmpType,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Employment Type', Icons.work_outline_rounded, context: context),
                        items: uniqueEmploymentTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedEmpType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validShiftId,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1B1B24)),
                        decoration: _inputStyle('Work Shift', Icons.schedule_rounded, context: context),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('-- None / Unassigned --')),
                          ...uniqueShifts.map((s) {
                            return DropdownMenuItem(value: s.shiftId, child: Text('${s.shiftName} (${s.startTime} - ${s.endTime})'));
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedShiftId = val;
                          });
                        },
                      ),
                      if (FeatureFlags.enableBranchManagement) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: validBranchId,
                          decoration: _inputStyle('Assign Branch *', Icons.location_city_rounded),
                          items: [
                            if (validBranchId == null)
                              const DropdownMenuItem<String>(value: null, child: Text('-- Select Branch --')),
                            ...uniqueBranches.map((b) {
                              return DropdownMenuItem(value: b.branchId, child: Text(b.branchName));
                            }),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              selectedBranchId = val;
                            });
                          },
                          validator: (v) => (v == null && FeatureFlags.enableBranchManagement) ? 'Branch assignment is required' : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: validSalaryStructureId,
                        decoration: _inputStyle('Salary Structure', Icons.account_balance_wallet_rounded),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('-- None --')),
                          ...uniqueStructures.map((s) {
                            return DropdownMenuItem(value: s.structureId, child: Text(s.name));
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedSalaryStructureId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Date Picker Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Joining Date: ${DateFormat('dd/MM/yyyy').format(selectedJoinDate)}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1B1B24))),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedJoinDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  selectedJoinDate = picked;
                                });
                              }
                            },
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {

                      final deptName = depts.firstWhere((d) => d.departmentId == validDeptId, orElse: () => DepartmentModel(departmentId: '', companyId: '', departmentName: '', departmentCode: '', createdAt: DateTime.now(), updatedAt: DateTime.now(), createdBy: '')).name;
                      final desigName = desigs.firstWhere((d) => d.designationId == validDesigId, orElse: () => DesignationModel(designationId: '', designationName: '', departmentId: '', designationLevel: 1, companyId: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).designationName;
                      final branchName = branches.firstWhere((b) => b.branchId == validBranchId, orElse: () => BranchModel(branchId: '', companyId: '', branchName: '', branchCode: '', email: '', phone: '', address: '', city: '', state: '', country: '', postalCode: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).branchName;

                      Future<void> executeCreate() async {
                        setModalState(() { isSubmitting = true; });
                        try {
                          final credentials = await ref.read(adminEmployeesProvider.notifier).createEmployee(
                            name: nameCtrl.text.trim(),
                            personalEmail: personalEmailCtrl.text.trim(),
                            phoneNumber: phoneCtrl.text.trim(),
                            departmentId: validDeptId,
                            department: deptName.isNotEmpty ? deptName : null,
                            designationId: validDesigId,
                            designation: desigName.isNotEmpty ? desigName : null,
                            managerId: validManagerId,
                            joiningDate: selectedJoinDate,
                            employmentType: validEmpType,
                            profileImageUrl: _uploadedImageUrl,
                            shiftId: validShiftId,
                            branchId: validBranchId,
                            branchName: branchName.isNotEmpty ? branchName : null,
                            salaryStructureId: validSalaryStructureId,
                            salaryStructureName: structures.where((s) => s.structureId == validSalaryStructureId).isNotEmpty ? structures.firstWhere((s) => s.structureId == validSalaryStructureId).name : null,
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            _showEmployeeCredentialsDialog(
                              context,
                              credentials['employeeId']!,
                              credentials['companyCode']!,
                              credentials['companyEmail']!,
                              credentials['tempPassword']!,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setModalState(() { isSubmitting = false; });
                            final msg = e.toString().replaceAll('Exception: ', '');
                            if (msg.contains('Free Plan employee limit reached')) {
                              Navigator.pop(ctx);
                              SubscriptionUpgradeDialog.show(
                                context,
                                title: 'Free Plan employee limit reached.',
                                message: 'You currently have 5 active employees. Upgrade your subscription to add more employees.',
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg), backgroundColor: msg.contains('already exists') ? Colors.orange : Colors.red),
                              );
                            }
                          }
                        }
                      }

                      Future<void> executeEdit() async {
                        setModalState(() { isSubmitting = true; });
                        try {
                          final updated = existingEmp!.copyWith(
                            name: nameCtrl.text.trim(),
                            phoneNumber: phoneCtrl.text.trim(),
                            employeeEmail: personalEmailCtrl.text.trim(),
                            departmentId: validDeptId,
                            department: deptName.isNotEmpty ? deptName : null,
                            designationId: validDesigId,
                            designation: desigName.isNotEmpty ? desigName : null,
                            managerId: validManagerId,
                            joiningDate: selectedJoinDate,
                            employmentType: validEmpType,
                            profileImageUrl: _uploadedImageUrl,
                            shiftId: validShiftId,
                            branchId: validBranchId,
                            branchName: branchName.isNotEmpty ? branchName : null,
                            salaryStructureId: validSalaryStructureId,
                            salaryStructureName: structures.where((s) => s.structureId == validSalaryStructureId).isNotEmpty ? structures.firstWhere((s) => s.structureId == validSalaryStructureId).name : null,
                            role: selectedRole,
                            status: selectedStatus,
                          );

                          await ref.read(adminEmployeesProvider.notifier).editEmployee(updated);

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Employee profile updated successfully.'), backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setModalState(() { isSubmitting = false; });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update employee: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      }

                      if (existingEmp == null) {
                        final company = ref.read(companyProvider).value;
                        final isFreePlan = company?.isFreePlan ?? true;
                        final activeCount = company?.activeEmployees ?? 0;

                        if (isFreePlan && activeCount >= 5) {
                          // Block creation & show professional Upgrade Subscription dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 28),
                                  SizedBox(width: 10),
                                  Text('Upgrade Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Free Plan Limit Reached ($activeCount / 5 active employees)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Your company is currently on the Free Plan, which supports a maximum of 5 active employees.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Paid Plan Benefits:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                        SizedBox(height: 6),
                                        Text('• Unlimited active employees', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                        Text('• USD 0.50 per active employee / month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                        Text('• Google Ads removed completely', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Please upgrade your subscription plan to add additional employees.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.bolt_rounded, size: 18),
                                  label: const Text('Upgrade Plan Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    if (company != null) {
                                      try {
                                        await SubscriptionService.updatePlan(company.companyId, 'Paid');
                                        await ref.read(companyProvider.notifier).loadCompany();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(r'Subscription successfully upgraded to Paid Plan ($0.50/employee).'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          // Now allow creation
                                          executeCreate();
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to upgrade subscription: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        } else {
                          executeCreate();
                        }
                      } else {
                        executeEdit();
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existingEmp == null ? 'Create Employee' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportCredentialsToPdf(String employeeId, String companyCode, String companyEmail, String password) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('WorkTrack Enterprise SaaS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('Employee Account Credentials Generated Successfully', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Text('Company Code: $companyCode', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Employee ID: $employeeId', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Internal Company Email: $companyEmail', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text('Temporary Password: $password', style: pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 30),
                pw.Text('Please change your password upon first login.', style: pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
    try {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Credentials_${employeeId}.pdf');
    } catch (e) {
      debugPrint('Error sharing/printing PDF: $e');
    }
  }

  void _showEmployeeCredentialsDialog(BuildContext context, String employeeId, String companyCode, String companyEmail, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Employee Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A Firebase Authentication account has been created for this employee. They will log in using their Employee ID and Password.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Text('Company Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              SelectableText(
                companyCode,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              const Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              SelectableText(
                employeeId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 12),
              const Text('Internal Company Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              SelectableText(
                companyEmail,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              const Text('Temporary Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              SelectableText(
                password,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please share these credentials with the Employee.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
              onPressed: () {
                final text = 'Company Code: $companyCode\nEmployee ID: $employeeId\nInternal Company Email: $companyEmail\nTemporary Password: $password';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied to clipboard.')),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Print PDF'),
              onPressed: () => _exportCredentialsToPdf(employeeId, companyCode, companyEmail, password),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _viewEmployeeProfile(BuildContext context, UserModel emp, List<UserModel> employees) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeProfileScreen(employee: emp),
      ),
    );
  }

  void _showTransferDialog(BuildContext context, UserModel emp, List<DepartmentModel> depts) {
    String? selectedDeptId = emp.departmentId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transfer Department: ${emp.name}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButtonFormField<String>(
              value: selectedDeptId,
              decoration: _inputStyle('Target Department', Icons.business_rounded),
              items: depts.map((d) {
                return DropdownMenuItem(value: d.departmentId, child: Text(d.name));
              }).toList(),
              onChanged: (val) {
                setModalState(() {
                  selectedDeptId = val;
                });
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (selectedDeptId != null) {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loaderCtx) => const Center(child: CircularProgressIndicator()),
                );
                try {
                  final deptName = depts.firstWhere((d) => d.departmentId == selectedDeptId).name;
                  await ref.read(adminEmployeesProvider.notifier).transferEmployee(emp.uid, selectedDeptId!, deptName);
                  if (context.mounted) Navigator.pop(context); // Dismiss loader
                } catch (e) {
                  if (context.mounted) Navigator.pop(context); // Dismiss loader
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _showManagerTransferDialog(BuildContext context, UserModel emp, List<UserModel> employees) {
    String? selectedManagerId = emp.managerId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transfer Manager: ${emp.name}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButtonFormField<String>(
              value: selectedManagerId,
              decoration: _inputStyle('Target Reporting Manager', Icons.supervised_user_circle_outlined),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('None (Clear Manager)')),
                ...employees.where((u) => u.uid != emp.uid).map((e) {
                  return DropdownMenuItem(value: e.uid, child: Text(e.name));
                }),
              ],
              onChanged: (val) {
                setModalState(() {
                  selectedManagerId = val;
                });
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loaderCtx) => const Center(child: CircularProgressIndicator()),
              );
              try {
                await ref.read(adminEmployeesProvider.notifier).transferManager(emp.uid, selectedManagerId);
                if (context.mounted) Navigator.pop(context); // Dismiss loader
              } catch (e) {
                if (context.mounted) Navigator.pop(context); // Dismiss loader
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _showShiftDialog(BuildContext context, UserModel emp, List<ShiftModel> shifts) {
    String? selectedShiftId = emp.shiftId;

    final eligibleShifts = shifts.where((s) {
      if (s.status.toLowerCase() == 'active') return true;
      if (s.shiftId == emp.shiftId) return true;
      return false;
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Assign Shift: ${emp.name}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            return DropdownButtonFormField<String>(
              value: selectedShiftId,
              decoration: _inputStyle('Select Shift', Icons.schedule_rounded),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('No Shift / Unassigned')),
                ...eligibleShifts.map((s) {
                  return DropdownMenuItem(value: s.shiftId, child: Text('${s.shiftName} (${s.startTime} - ${s.endTime})'));
                }),
              ],
              onChanged: (val) {
                setModalState(() {
                  selectedShiftId = val;
                });
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loaderCtx) => const Center(child: CircularProgressIndicator()),
              );
              try {
                await ref.read(adminEmployeesProvider.notifier).assignShift(emp.uid, selectedShiftId);
                if (context.mounted) Navigator.pop(context); // Dismiss loader
              } catch (e) {
                if (context.mounted) Navigator.pop(context); // Dismiss loader
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign shift: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _confirmToggleStatus(BuildContext context, UserModel emp) {
    final isSuspending = emp.status.toLowerCase() == 'active';
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(isSuspending ? Icons.block_rounded : Icons.check_circle_outline_rounded, color: isSuspending ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(isSuspending ? 'Deactivate Employee?' : 'Activate Employee?'),
            ],
          ),
          content: Text(isSuspending
              ? "Are you sure you want to deactivate this employee's account?"
              : "Are you sure you want to activate this employee's account?"),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isSuspending ? Colors.orange : Colors.green, foregroundColor: Colors.white),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminEmployeesProvider.notifier).toggleEmployeeStatus(emp.uid, emp.status);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isSuspending ? 'Employee account deactivated successfully.' : 'Employee account activated successfully.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          final msg = e.toString().replaceAll('Exception: ', '');
                          if (msg.contains('Free Plan employee limit reached')) {
                            Navigator.pop(ctx);
                            SubscriptionUpgradeDialog.show(
                              context,
                              title: 'Free Plan employee limit reached.',
                              message: 'You currently have 5 active employees. Upgrade your subscription to activate another employee.',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $msg'), backgroundColor: Colors.red));
                          }
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isSuspending ? 'Deactivate' : 'Activate'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String uid, String name) {
    bool isProcessing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Employee'),
            ],
          ),
          content: Text('Are you sure you want to delete employee "$name"? This will permanently remove their Firestore record and delete their Firebase Authentication account.'),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminEmployeesProvider.notifier).deleteEmployee(uid);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted successfully.'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete employee: $e'), backgroundColor: Colors.red));
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleResetPassword(BuildContext context, String uid, String name) {
    final formKey = GlobalKey<FormState>();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              Expanded(child: Text('Reset Password for $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter a new password for this employee account.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                const SizedBox(height: 16),

                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(errorText!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                ],

                const Text('New Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter new password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 14),

                const Text('Confirm Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Re-enter new password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v != newPassCtrl.text) ? 'Password mismatch' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() {
                          isSaving = true;
                          errorText = null;
                        });
                        try {
                          await ref.read(adminEmployeesProvider.notifier).updateEmployeePassword(uid, newPassCtrl.text.trim());
                          if (context.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Password for $name updated successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorText = 'Failed to update password: $e';
                          });
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Password'),
            ),
          ],
        ),
      ),
    );
  }
}
