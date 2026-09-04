import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/department_model.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/company_admin/models/branch_model.dart';
import 'package:worktrack/constants/feature_flags.dart';
import 'package:worktrack/shared/services/app_error_handler.dart';
import 'package:worktrack/shared/utils/app_notification.dart';

class DepartmentManagementScreen extends ConsumerStatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  ConsumerState<DepartmentManagementScreen> createState() => _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends ConsumerState<DepartmentManagementScreen> {
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 8;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(adminDepartmentsProvider);
    final employeesAsync = ref.watch(adminEmployeesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Department Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0))),
        backgroundColor: cardBg,
        foregroundColor: titleColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B4CF0)),
            onPressed: () {
              ref.read(adminDepartmentsProvider.notifier).loadDepartments();
              ref.read(adminEmployeesProvider.notifier).loadEmployees();
            },
          ),
        ],
      ),
      body: deptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading departments: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (depts) {
          final employees = employeesAsync.value ?? [];

          // Compute Stats
          final totalCount = depts.length;
          final activeCount = depts.where((d) => d.status.toLowerCase() == 'active').length;
          final suspendedCount = depts.where((d) => d.status.toLowerCase() == 'suspended').length;
          final archivedCount = depts.where((d) => d.status.toLowerCase() == 'archived').length;

          // Local Filter & Search
          final filteredDepts = depts.where((dept) {
            // Status Filter
            if (_selectedStatusFilter != 'All') {
              if (_selectedStatusFilter == 'Active' && dept.status.toLowerCase() != 'active') return false;
              if (_selectedStatusFilter == 'Suspended' && dept.status.toLowerCase() != 'suspended') return false;
              if (_selectedStatusFilter == 'Archived' && dept.status.toLowerCase() != 'archived') return false;
            }
            // Search Query
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final managerName = dept.managerId != null
                  ? employees.firstWhere((e) => e.uid == dept.managerId, orElse: () => UserModel(uid: '', email: '', name: 'N/A', role: '', companyId: '', companyName: '', createdAt: DateTime.now())).name.toLowerCase()
                  : 'none';
              return dept.departmentName.toLowerCase().contains(q) ||
                  dept.departmentCode.toLowerCase().contains(q) ||
                  dept.description.toLowerCase().contains(q) ||
                  managerName.contains(q);
            }
            return true;
          }).toList();

          // Pagination calculations
          final totalItems = filteredDepts.length;
          final totalPages = (totalItems / _itemsPerPage).ceil();
          if (_currentPage >= totalPages && totalPages > 0) {
            _currentPage = totalPages - 1;
          }
          final startIndex = _currentPage * _itemsPerPage;
          final endIndex = startIndex + _itemsPerPage > totalItems ? totalItems : startIndex + _itemsPerPage;
          final paginatedDepts = totalItems > 0 ? filteredDepts.sublist(startIndex, endIndex) : <DepartmentModel>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header & Action Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 550;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department List',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure company departments and business units',
                            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeptForm(context, employees),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B4CF0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department List',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure company departments and business units',
                              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showDeptForm(context, employees),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Department', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4CF0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Stats Dashboard Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: cols,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: cols == 1 ? 2.6 : 2.5,
                      children: [
                        _buildStatCard('Total Departments', '$totalCount', Icons.account_balance_rounded, const Color(0xFF5B4CF0)),
                        _buildStatCard('Active Units', '$activeCount', Icons.check_circle_rounded, const Color(0xFF007834)),
                        _buildStatCard('Suspended Units', '$suspendedCount', Icons.pause_circle_rounded, const Color(0xFFF59E0B)),
                        _buildStatCard('Archived Units', '$archivedCount', Icons.archive_rounded, const Color(0xFF64748B)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Search & Filter Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            });
                          },
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: 'Search by name, code or manager...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 0;
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderCol),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderCol),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderCol),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStatusFilter,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? Theme.of(context).cardColor : Colors.white,
                          icon: Icon(Icons.arrow_drop_down_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                          items: ['All', 'Active', 'Suspended', 'Archived'].map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text('Status: $val'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatusFilter = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Department Cards Grid
                if (totalItems == 0)
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.business_rounded, size: 48, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ? 'No departments found matching your search.' : 'No departments found.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showDeptForm(context, employees),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Create Department'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B4CF0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: paginatedDepts.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        ),
                        itemBuilder: (context, idx) {
                          final dept = paginatedDepts[idx];
                          final managerName = dept.managerId != null
                              ? employees.firstWhere((e) => e.uid == dept.managerId, orElse: () => UserModel(uid: '', email: '', name: 'N/A', role: '', companyId: '', companyName: '', createdAt: DateTime.now())).name
                              : 'None Assigned';

                          Color statusBg;
                          Color statusText;
                          switch (dept.status.toLowerCase()) {
                            case 'active':
                              statusBg = const Color(0xFFDCFCE7);
                              statusText = const Color(0xFF007834);
                              break;
                            case 'suspended':
                              statusBg = const Color(0xFFFEF3C7);
                              statusText = const Color(0xFFD97706);
                              break;
                            default:
                              statusBg = const Color(0xFFF1F5F9);
                              statusText = const Color(0xFF64748B);
                          }

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderCol),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5B4CF0).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.corporate_fare_rounded, color: Color(0xFF5B4CF0), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dept.departmentName,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dept.departmentCode,
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        dept.status.toUpperCase(),
                                        style: TextStyle(color: statusText, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Mgr: $managerName',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Builder(builder: (context) {
                                      final assignedCount = employees.where((e) => e.departmentId == dept.departmentId || e.department == dept.departmentName).length;
                                      return Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF5B4CF0), size: 18),
                                            onPressed: () => _showDeptForm(context, employees, existingDept: dept),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Edit Department',
                                          ),
                                          const SizedBox(width: 8),
                                          if (dept.status.toLowerCase() == 'archived')
                                            IconButton(
                                              icon: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF007834), size: 18),
                                              onPressed: () => _confirmRestore(context, dept.departmentId, dept.departmentName),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Restore Department',
                                            )
                                          else
                                            IconButton(
                                              icon: const Icon(Icons.archive_outlined, color: Color(0xFFF59E0B), size: 18),
                                              onPressed: () => _confirmArchive(context, dept.departmentId, dept.departmentName),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Archive Department',
                                            ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A), size: 18),
                                            onPressed: () => _handleDeleteDepartment(context, dept, assignedCount),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Delete Department',
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Pagination controls
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Showing ${startIndex + 1} to $endIndex of $totalItems departments',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B4CF0).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_currentPage + 1}',
                              style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _currentPage < totalPages - 1
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeptForm(BuildContext context, List<UserModel> employees, {DepartmentModel? existingDept}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existingDept?.departmentName ?? '');
    final codeCtrl = TextEditingController(text: existingDept?.departmentCode ?? '');
    final descCtrl = TextEditingController(text: existingDept?.description ?? '');
    final branches = ref.read(adminBranchesProvider).value ?? [];

    String? selectedManagerId = existingDept?.managerId;
    String? selectedBranchId = existingDept?.branchId;
    String selectedStatus = existingDept?.status ?? 'active';

    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(existingDept == null ? 'Add Department' : 'Edit Department', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Department Name *',
                          prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF5B4CF0)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: codeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Department Code *',
                          prefixIcon: const Icon(Icons.code_rounded, color: Color(0xFF5B4CF0)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedManagerId,
                        decoration: InputDecoration(
                          labelText: 'Department Manager (Optional)',
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF5B4CF0)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('None')),
                          ...employees.map((e) => DropdownMenuItem(value: e.uid, child: Text(e.name))),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedManagerId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          prefixIcon: const Icon(Icons.info_outline_rounded, color: Color(0xFF5B4CF0)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                          DropdownMenuItem(value: 'archived', child: Text('Archived')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                      if (FeatureFlags.enableBranchManagement) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedBranchId,
                          decoration: InputDecoration(
                            labelText: 'Assign Branch (Optional)',
                            prefixIcon: const Icon(Icons.location_city_rounded, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('None (Global)')),
                            ...branches.where((b) {
                              if (b.status.toLowerCase() == 'active') return true;
                              if (existingDept != null && b.branchId == selectedBranchId) return true;
                              return false;
                            }).map((b) => DropdownMenuItem(value: b.branchId, child: Text(b.branchName))),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              selectedBranchId = val;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final user = ref.read(authProvider).user;
                            if (user == null) return;

                            setModalState(() { isSubmitting = true; });

                            final branch = branches.firstWhere((b) => b.branchId == selectedBranchId, orElse: () => BranchModel(branchId: '', companyId: '', branchName: '', branchCode: '', email: '', phone: '', address: '', city: '', state: '', country: '', postalCode: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).branchName;

                            final newDept = DepartmentModel(
                              departmentId: existingDept?.departmentId ?? const Uuid().v4(),
                              companyId: user.companyId,
                              departmentName: nameCtrl.text.trim(),
                              departmentCode: codeCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              managerId: selectedManagerId,
                              status: selectedStatus,
                              createdAt: existingDept?.createdAt ?? DateTime.now(),
                              updatedAt: DateTime.now(),
                              createdBy: existingDept?.createdBy ?? user.email,
                              branchId: selectedBranchId,
                              branchName: branch.isNotEmpty ? branch : null,
                            );

                            try {
                              final result = await ref.read(adminDepartmentsProvider.notifier).saveDepartment(newDept);
                              if (context.mounted) {
                                if (result == 'success') {
                                  Navigator.pop(ctx);
                                  AppNotification.showSuccess(context, 'Department saved successfully.');
                                } else {
                                  setModalState(() { isSubmitting = false; });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            } catch (e, stack) {
                              if (context.mounted) {
                                setModalState(() { isSubmitting = false; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFBA1A1A)),
              SizedBox(width: 8),
              Text('Disable Department?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to disable the "$name" department? Disabled departments cannot be assigned to new employees.'),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminDepartmentsProvider.notifier).deleteDepartment(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          AppNotification.showSuccess(context, 'Department disabled successfully.');
                        }
                      } catch (e, stack) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF007834)),
              SizedBox(width: 8),
              Text('Restore Department', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to restore department "$name" back to active status?'),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007834),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isProcessing
                  ? null
                  : () async {
                      setConfirmState(() { isProcessing = true; });
                      try {
                        await ref.read(adminDepartmentsProvider.notifier).restoreDepartment(id);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          AppNotification.showSuccess(context, 'Department restored successfully.');
                        }
                      } catch (e, stack) {
                        if (context.mounted) {
                          setConfirmState(() { isProcessing = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeleteDepartment(BuildContext context, DepartmentModel dept, int assignedEmpCount) {
    if (assignedEmpCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEAB308)),
              SizedBox(width: 8),
              Text('Cannot Delete Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'Department "${dept.departmentName}" cannot be deleted because $assignedEmpCount employee(s) are currently assigned to it.\n\nPlease reassign these employees to another department before deleting.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: Color(0xFFBA1A1A)),
                SizedBox(width: 8),
                Text('Delete Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Text('Are you sure you want to permanently delete department "${dept.departmentName}"? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setConfirmState(() { isProcessing = true; });
                        try {
                          await ref.read(adminDepartmentsProvider.notifier).permanentlyDeleteDepartment(dept.departmentId);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppNotification.showSuccess(context, 'Department deleted successfully.');
                          }
                        } catch (e, stack) {
                          if (context.mounted) {
                            setConfirmState(() { isProcessing = false; });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
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
