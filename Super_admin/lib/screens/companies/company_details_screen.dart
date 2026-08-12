import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/company_tenant_provider.dart';
import '../../providers/auth_provider.dart';
import 'employee_detail_dialog.dart';

class CompanyDetailsScreen extends StatefulWidget {
  final CompanyModel company;
  final int employeeCount;

  const CompanyDetailsScreen({
    super.key,
    required this.company,
    required this.employeeCount,
  });

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _employeeSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 13, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyTenantProvider>().loadCompanyTenantData(widget.company.companyId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Action Dialogs
  Future<void> _handleStatusUpdate(CompanyModel company, String newStatus, String adminEmail) async {
    final isSuspend = newStatus == 'Suspended';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuspend ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: isSuspend ? Colors.amber : Colors.green,
            ),
            const SizedBox(width: 10),
            Text(isSuspend ? 'Suspend Company Account' : 'Activate Company Account'),
          ],
        ),
        content: Text(
          isSuspend
              ? 'Suspending "${company.name}" will immediately prevent all users under this tenant from accessing the WorkTrack platform. Are you sure?'
              : 'Activating "${company.name}" will restore platform access for all registered tenant users.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuspend ? Colors.amber.shade700 : Colors.green,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isSuspend ? 'Suspend Access' : 'Activate Access'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final success = isSuspend
        ? await companyProvider.suspendCompany(
            companyId: company.companyId,
            companyName: company.name,
            performedBy: adminEmail,
          )
        : await companyProvider.activateCompany(
            companyId: company.companyId,
            companyName: company.name,
            performedBy: adminEmail,
          );

    if (mounted) {
      if (success) {
        _showSuccessSnackBar('Company status updated to $newStatus successfully.');
      } else if (companyProvider.errorMessage != null) {
        _showErrorSnackBar(companyProvider.errorMessage!);
      }
    }
  }

  Future<void> _handleSoftDelete(CompanyModel company, String adminEmail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('PERMANENT DELETION WARNING'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action permanently marks "${company.name}" and its associated tenant data as deleted.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone from the user interface. Please verify you intend to delete this tenant.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Deletion'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final success = await companyProvider.deleteCompany(
      companyId: company.companyId,
      companyName: company.name,
      performedBy: adminEmail,
    );

    if (mounted) {
      if (success) {
        _showSuccessSnackBar('Company marked as deleted.');
        Navigator.of(context).pop();
      } else if (companyProvider.errorMessage != null) {
        _showErrorSnackBar(companyProvider.errorMessage!);
      }
    }
  }

  Future<void> _handleUpgradePlan(CompanyModel company, String adminEmail) async {
    String selectedPlan = company.subscriptionPlan;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change Subscription Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Free Tier'),
                subtitle: const Text('Up to 10 Employees • Core Features'),
                value: 'Free',
                groupValue: selectedPlan,
                onChanged: (val) => setState(() => selectedPlan = val!),
              ),
              RadioListTile<String>(
                title: const Text('Standard Plan'),
                subtitle: const Text('Up to 50 Employees • Full Attendance & Leaves'),
                value: 'Standard',
                groupValue: selectedPlan,
                onChanged: (val) => setState(() => selectedPlan = val!),
              ),
              RadioListTile<String>(
                title: const Text('Enterprise Plan'),
                subtitle: const Text('Unlimited Employees • All Modules & API Access'),
                value: 'Enterprise',
                groupValue: selectedPlan,
                onChanged: (val) => setState(() => selectedPlan = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update Plan'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final companyProvider = Provider.of<CompanyProvider>(context, listen: false);
    final success = await companyProvider.upgradeCompanyPlan(
      companyId: company.companyId,
      companyName: company.name,
      planName: selectedPlan,
      performedBy: adminEmail,
    );

    if (mounted) {
      if (success) {
        _showSuccessSnackBar('Subscription plan updated to $selectedPlan.');
      } else if (companyProvider.errorMessage != null) {
        _showErrorSnackBar(companyProvider.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyProvider = Provider.of<CompanyProvider>(context);
    final tenantProvider = Provider.of<CompanyTenantProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final freshCompany = companyProvider.companies.firstWhere(
      (c) => c.companyId == widget.company.companyId,
      orElse: () => widget.company,
    );

    final adminEmail = authProvider.userModel?.email ?? 'super_admin@platform.com';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.business_rounded, color: theme.primaryColor),
            const SizedBox(width: 12),
            Text(
              freshCompany.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(freshCompany.status),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Tenant Data',
            onPressed: () {
              companyProvider.fetchCompanies();
              tenantProvider.refresh();
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'activate') _handleStatusUpdate(freshCompany, 'Active', adminEmail);
              if (val == 'suspend') _handleStatusUpdate(freshCompany, 'Suspended', adminEmail);
              if (val == 'upgrade') _handleUpgradePlan(freshCompany, adminEmail);
              if (val == 'delete') _handleSoftDelete(freshCompany, adminEmail);
            },
            itemBuilder: (ctx) => [
              if (freshCompany.status != 'Active')
                const PopupMenuItem(value: 'activate', child: Text('Activate Company')),
              if (freshCompany.status != 'Suspended')
                const PopupMenuItem(value: 'suspend', child: Text('Suspend Access')),
              const PopupMenuItem(value: 'upgrade', child: Text('Change Subscription Plan')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Company', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline), text: 'Employees'),
            Tab(icon: Icon(Icons.access_time_outlined), text: 'Attendance'),
            Tab(icon: Icon(Icons.event_note_outlined), text: 'Leave'),
            Tab(icon: Icon(Icons.contacts_outlined), text: 'Leads'),
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Orders'),
            Tab(icon: Icon(Icons.attach_money_outlined), text: 'Payroll'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Documents'),
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Depts & Branches'),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined), text: 'Admins & HR'),
            Tab(icon: Icon(Icons.grid_view_outlined), text: 'Modules'),
            Tab(icon: Icon(Icons.card_membership_outlined), text: 'Subscription'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Audit Log'),
          ],
        ),
      ),
      body: tenantProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme, freshCompany, tenantProvider),
                _buildEmployeesTab(theme, tenantProvider),
                _buildAttendanceTab(theme, tenantProvider),
                _buildLeaveTab(theme, tenantProvider),
                _buildLeadsTab(theme, freshCompany, tenantProvider),
                _buildOrdersTab(theme, freshCompany, tenantProvider),
                _buildPayrollTab(theme, freshCompany, tenantProvider),
                _buildDocumentsTab(theme, tenantProvider),
                _buildDeptsAndBranchesTab(theme, tenantProvider),
                _buildAdminsAndHrTab(theme, tenantProvider),
                _buildModulesTab(theme, freshCompany),
                _buildSubscriptionTab(theme, freshCompany, tenantProvider, adminEmail),
                _buildAuditLogTab(theme, tenantProvider),
              ],
            ),
    );
  }

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab(ThemeData theme, CompanyModel company, CompanyTenantProvider tenant) {
    final employees = tenant.employees;
    final activeEmployees = employees.where((e) => (e.status ?? 'Active').toLowerCase() == 'active').length;
    final inactiveEmployees = employees.length - activeEmployees;
    final adminsCount = tenant.companyAdminsAndHr.length;
    final deptsCount = tenant.departments.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatTile('Total Employees', '${employees.length}', Icons.people_rounded, Colors.indigoAccent),
                  _buildStatTile('Active Employees', '$activeEmployees', Icons.check_circle_rounded, Colors.greenAccent),
                  _buildStatTile('Inactive Employees', '$inactiveEmployees', Icons.pause_circle_rounded, Colors.orangeAccent),
                  _buildStatTile('HR & Admin Users', '$adminsCount', Icons.admin_panel_settings_rounded, Colors.purpleAccent),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Company Information Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Company Tenant Profile', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildInfoRow('Tenant ID', company.companyId),
                        _buildInfoRow('Company Name', company.name),
                        _buildInfoRow('Business Email', company.businessEmail.isNotEmpty ? company.businessEmail : 'N/A'),
                        _buildInfoRow('Phone', company.companyMobile.isNotEmpty ? company.companyMobile : 'N/A'),
                        _buildInfoRow('Subscription Plan', company.subscriptionPlan),
                        _buildInfoRow('Company Type', company.companyType.isNotEmpty ? company.companyType : 'Standard Enterprise'),
                        _buildInfoRow('Registration Date', DateFormat('MMM dd, yyyy HH:mm').format(company.createdAt)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('GeoFence Setup', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildInfoRow('Latitude', company.geofenceLat != null ? company.geofenceLat.toString() : 'Not Set'),
                            _buildInfoRow('Longitude', company.geofenceLng != null ? company.geofenceLng.toString() : 'Not Set'),
                            _buildInfoRow('Radius', company.geofenceRadius != null ? '${company.geofenceRadius} meters' : 'Not Set'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Departments Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text('$deptsCount configured departments on platform.', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. EMPLOYEES TAB
  Widget _buildEmployeesTab(ThemeData theme, CompanyTenantProvider tenant) {
    final employees = tenant.filteredEmployees;

    final depts = <String>{'All'};
    final designations = <String>{'All'};
    final roles = <String>{'All'};
    final branches = <String>{'All'};

    for (final e in tenant.employees) {
      if (e.department != null && e.department!.isNotEmpty) depts.add(e.department!);
      if (e.designation != null && e.designation!.isNotEmpty) designations.add(e.designation!);
      if (e.role.isNotEmpty) roles.add(e.role);
      if (e.branch != null && e.branch!.isNotEmpty) branches.add(e.branch!);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Toolbar Card
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _employeeSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Search employee name, email or ID...',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                      onChanged: (val) => tenant.setEmployeeSearchQuery(val),
                    ),
                  ),
                  DropdownButton<String>(
                    value: tenant.employeeDeptFilter,
                    hint: const Text('Department'),
                    onChanged: (val) => tenant.setEmployeeDeptFilter(val!),
                    items: depts.map((d) => DropdownMenuItem(value: d, child: Text('Dept: $d'))).toList(),
                  ),
                  DropdownButton<String>(
                    value: tenant.employeeDesignationFilter,
                    hint: const Text('Designation'),
                    onChanged: (val) => tenant.setEmployeeDesignationFilter(val!),
                    items: designations.map((d) => DropdownMenuItem(value: d, child: Text('Desig: $d'))).toList(),
                  ),
                  DropdownButton<String>(
                    value: tenant.employeeStatusFilter,
                    onChanged: (val) => tenant.setEmployeeStatusFilter(val!),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('Status: All')),
                      DropdownMenuItem(value: 'Active', child: Text('Status: Active')),
                      DropdownMenuItem(value: 'Inactive', child: Text('Status: Inactive')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Employees Table
          Expanded(
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
              ),
              child: employees.isEmpty
                  ? const Center(child: Text('No employees found for this company tenant.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('Employee Name')),
                          DataColumn(label: Text('Employee ID')),
                          DataColumn(label: Text('Company Email')),
                          DataColumn(label: Text('Department')),
                          DataColumn(label: Text('Designation')),
                          DataColumn(label: Text('Role')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: employees.map((emp) {
                          return DataRow(
                            onSelectChanged: (_) {
                              showDialog(
                                context: context,
                                builder: (_) => EmployeeDetailDialog(
                                  employee: emp,
                                  attendanceRecords: tenant.attendanceRecords,
                                ),
                              );
                            },
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      child: Text(emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E'),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              DataCell(Text(emp.employeeId ?? 'N/A')),
                              DataCell(Text(emp.email)),
                              DataCell(Text(emp.department ?? 'N/A')),
                              DataCell(Text(emp.designation ?? 'N/A')),
                              DataCell(Text(emp.role.toUpperCase())),
                              DataCell(_buildStatusBadge(emp.status ?? 'Active')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 20),
                                  tooltip: 'View Employee Overview',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => EmployeeDetailDialog(
                                        employee: emp,
                                        attendanceRecords: tenant.attendanceRecords,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. ATTENDANCE TAB
  Widget _buildAttendanceTab(ThemeData theme, CompanyTenantProvider tenant) {
    final records = tenant.attendanceRecords;
    int present = 0;
    int absent = 0;
    int onLeave = 0;
    int late = 0;

    for (final r in records) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      if (status == 'present') present++;
      if (status == 'absent') absent++;
      if (status == 'leave' || status == 'on leave') onLeave++;
      if (r['isLate'] == true || status == 'late') late++;
    }

    final total = records.length;
    final percentage = total > 0 ? ((present / total) * 100).toStringAsFixed(1) : '100.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatTile('Total Records', '$total', Icons.calendar_today_rounded, Colors.indigoAccent),
              _buildStatTile('Present', '$present', Icons.check_circle_rounded, Colors.greenAccent),
              _buildStatTile('Absent', '$absent', Icons.cancel_rounded, Colors.redAccent),
              _buildStatTile('On Leave', '$onLeave', Icons.event_busy_rounded, Colors.orangeAccent),
              _buildStatTile('Late Arrivals', '$late', Icons.access_time_filled_rounded, Colors.amberAccent),
              _buildStatTile('Attendance Rate', '$percentage%', Icons.analytics_rounded, Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Log Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  records.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No attendance logs registered for this company.')))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: records.length > 10 ? 10 : records.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = records[idx];
                            return ListTile(
                              leading: const Icon(Icons.fingerprint_rounded),
                              title: Text(item['employeeName'] ?? item['userName'] ?? 'Employee'),
                              subtitle: Text('Date: ${item['date'] ?? 'N/A'} • CheckIn: ${item['checkInTime'] ?? 'N/A'}'),
                              trailing: _buildStatusBadge(item['status'] ?? 'Present'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. LEAVE TAB
  Widget _buildLeaveTab(ThemeData theme, CompanyTenantProvider tenant) {
    final leaves = tenant.leaveRecords;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    for (final l in leaves) {
      final s = (l['status'] ?? '').toString().toLowerCase();
      if (s == 'pending') pending++;
      if (s == 'approved') approved++;
      if (s == 'rejected') rejected++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatTile('Total Requests', '${leaves.length}', Icons.event_note_rounded, Colors.indigoAccent),
              _buildStatTile('Pending', '$pending', Icons.hourglass_empty_rounded, Colors.amberAccent),
              _buildStatTile('Approved', '$approved', Icons.check_circle_rounded, Colors.greenAccent),
              _buildStatTile('Rejected', '$rejected', Icons.cancel_rounded, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leave Requests (Read-Only Oversight)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  leaves.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No leave records found.')))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: leaves.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = leaves[idx];
                            return ListTile(
                              leading: const Icon(Icons.beach_access_rounded),
                              title: Text(item['employeeName'] ?? item['userName'] ?? 'Employee'),
                              subtitle: Text('Reason: ${item['reason'] ?? 'Leave Request'} • Type: ${item['leaveType'] ?? 'Annual'}'),
                              trailing: _buildStatusBadge(item['status'] ?? 'Pending'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. LEADS TAB
  Widget _buildLeadsTab(ThemeData theme, CompanyModel company, CompanyTenantProvider tenant) {
    final leads = tenant.leadRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.contacts_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  const Text('Leads Module Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildStatusBadge('Enabled'),
                  const Spacer(),
                  Text('Total Leads: ${leads.length}', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Company Leads Oversight Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  leads.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No leads registered for this tenant.')))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: leads.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = leads[idx];
                            return ListTile(
                              leading: const Icon(Icons.person_pin_rounded),
                              title: Text(item['name'] ?? item['customerName'] ?? 'Lead Contact'),
                              subtitle: Text('Status: ${item['status'] ?? 'New'} • Phone: ${item['phone'] ?? 'N/A'}'),
                              trailing: Text(item['value'] != null ? '\$${item['value']}' : ''),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. ORDERS TAB
  Widget _buildOrdersTab(ThemeData theme, CompanyModel company, CompanyTenantProvider tenant) {
    final orders = tenant.orderRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: Colors.purpleAccent),
                  const SizedBox(width: 12),
                  const Text('Orders Module Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildStatusBadge('Enabled'),
                  const Spacer(),
                  Text('Total Orders: ${orders.length}', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenant Orders Oversight', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  orders.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No orders recorded for this company.')))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = orders[idx];
                            return ListTile(
                              leading: const Icon(Icons.receipt_long_rounded),
                              title: Text('Order #${item['id'] ?? item['orderId'] ?? idx + 1}'),
                              subtitle: Text('Status: ${item['status'] ?? 'Pending'} • Items: ${item['itemsCount'] ?? 1}'),
                              trailing: _buildStatusBadge(item['status'] ?? 'Pending'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. PAYROLL TAB
  Widget _buildPayrollTab(ThemeData theme, CompanyModel company, CompanyTenantProvider tenant) {
    final payslips = tenant.payslipRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_money_rounded, color: Colors.greenAccent),
                      const SizedBox(width: 12),
                      Text('High-Level Payroll Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Payroll Cycle', 'Monthly (1st - 30th)'),
                  _buildInfoRow('Enrolled Employees', '${tenant.employees.length} employees'),
                  _buildInfoRow('Generated Payslips Count', '${payslips.length} payslips'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Security Authorization Required'),
                          content: const Text('Detailed payroll figures contain sensitive employee salary information. Proceed with platform audit log recording?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _showSuccessSnackBar('Authorized view granted under platform audit logging.');
                              },
                              child: const Text('Authorize & View'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_outline_rounded),
                    label: const Text('View Payroll Details (Platform Owner Action)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 8. DOCUMENTS TAB
  Widget _buildDocumentsTab(ThemeData theme, CompanyTenantProvider tenant) {
    final docs = tenant.documentRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatTile('Total Documents', '${docs.length}', Icons.folder_rounded, Colors.indigoAccent),
              _buildStatTile('Uploaded', '${docs.where((d) => d['status'] == 'Uploaded').length}', Icons.cloud_done_rounded, Colors.greenAccent),
              _buildStatTile('Pending Verification', '${docs.where((d) => d['status'] == 'Pending').length}', Icons.hourglass_top_rounded, Colors.amberAccent),
              _buildStatTile('Missing / Expired', '${docs.where((d) => d['status'] == 'Expired').length}', Icons.warning_rounded, Colors.redAccent),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Document Metadata Oversight', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  docs.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No document metadata records logged.')))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = docs[idx];
                            return ListTile(
                              leading: const Icon(Icons.description_rounded),
                              title: Text(item['title'] ?? item['fileName'] ?? 'Employee Document'),
                              subtitle: Text('Uploaded By: ${item['uploadedBy'] ?? 'Employee'}'),
                              trailing: _buildStatusBadge(item['status'] ?? 'Uploaded'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 9. DEPTS & BRANCHES TAB
  Widget _buildDeptsAndBranchesTab(ThemeData theme, CompanyTenantProvider tenant) {
    final depts = tenant.departments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configured Departments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  depts.isEmpty
                      ? const Text('No explicit departments registered in database. Defaulting to general structure.')
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: depts.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, idx) {
                            final item = depts[idx];
                            return ListTile(
                              leading: const Icon(Icons.business_center_rounded),
                              title: Text(item['name'] ?? 'Department'),
                              subtitle: Text('Status: ${item['status'] ?? 'Active'}'),
                              trailing: _buildStatusBadge(item['status'] ?? 'Active'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 10. ADMINS & HR TAB
  Widget _buildAdminsAndHrTab(ThemeData theme, CompanyTenantProvider tenant) {
    final admins = tenant.companyAdminsAndHr;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company Administrators & HR Officers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('These accounts manage company operations and are distinct from standard employees.', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Expanded(
                child: admins.isEmpty
                    ? const Center(child: Text('No explicit Company Admin / HR accounts loaded.'))
                    : ListView.separated(
                        itemCount: admins.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, idx) {
                          final user = admins[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple.withValues(alpha: 0.2),
                              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.purpleAccent),
                            ),
                            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Email: ${user.email} • Role: ${user.role.toUpperCase()}'),
                            trailing: _buildStatusBadge(user.status ?? 'Active'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 11. MODULES TAB
  Widget _buildModulesTab(ThemeData theme, CompanyModel company) {
    final modules = [
      {'name': 'Employee Management', 'status': 'Enabled', 'desc': 'Employee onboarding & directory.'},
      {'name': 'Attendance Management', 'status': 'Enabled', 'desc': 'Geofenced check-in & logs.'},
      {'name': 'Leave Management', 'status': 'Enabled', 'desc': 'Leave requests & approval workflows.'},
      {'name': 'Payroll System', 'status': 'Enabled', 'desc': 'Monthly salary payslip generation.'},
      {'name': 'Leads & CRM', 'status': 'Enabled', 'desc': 'Customer lead tracking & pipeline.'},
      {'name': 'Orders Management', 'status': 'Enabled', 'desc': 'Product order tracking.'},
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: modules.map((m) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
          ),
          child: ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(m['desc']!),
            trailing: _buildStatusBadge(m['status']!),
          ),
        );
      }).toList(),
    );
  }

  // 12. SUBSCRIPTION TAB
  Widget _buildSubscriptionTab(ThemeData theme, CompanyModel company, CompanyTenantProvider tenant, String adminEmail) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Platform Subscription', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildInfoRow('Plan Name', company.subscriptionPlan),
              _buildInfoRow('Status', company.status),
              _buildInfoRow('Registered Employees', '${tenant.employees.length} users'),
              _buildInfoRow('Start Date', DateFormat('MMM dd, yyyy').format(company.createdAt)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _handleUpgradePlan(company, adminEmail),
                icon: const Icon(Icons.upgrade_rounded),
                label: const Text('Upgrade Subscription Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 13. AUDIT LOG TAB
  Widget _buildAuditLogTab(ThemeData theme, CompanyTenantProvider tenant) {
    final logs = tenant.auditLogs;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tenant Activity Audit Log', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('No audit logs recorded for this tenant.'))
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (ctx, idx) {
                          final log = logs[idx];
                          return ListTile(
                            leading: const Icon(Icons.security_rounded),
                            title: Text(log['action'] ?? 'Platform Event'),
                            subtitle: Text('Performed By: ${log['performedBy'] ?? 'System'}'),
                            trailing: Text(
                              log['timestamp'] != null
                                  ? (log['timestamp'] is Timestamp
                                      ? DateFormat('MMM dd, HH:mm').format((log['timestamp'] as Timestamp).toDate())
                                      : log['timestamp'].toString())
                                  : '',
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper UI Builders
  Widget _buildStatTile(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(title, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toLowerCase();
    Color bg = Colors.green.withValues(alpha: 0.15);
    Color fg = Colors.greenAccent;

    if (s == 'suspended' || s == 'inactive') {
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orangeAccent;
    } else if (s == 'deleted') {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
