import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/models/leave_type_model.dart';
import '../../../shared/models/leave_balance_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../constants/user_roles.dart';
import '../../company_admin/providers/company_admin_providers.dart';

class LeaveListScreen extends StatelessWidget {
  const LeaveListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaveListWidget(showAppBar: true);
  }
}

class LeaveListWidget extends ConsumerStatefulWidget {
  final bool showAppBar;
  const LeaveListWidget({super.key, this.showAppBar = true});

  @override
  ConsumerState<LeaveListWidget> createState() => _LeaveListWidgetState();
}

class _LeaveListWidgetState extends ConsumerState<LeaveListWidget> {
  String _requestsFilter = 'All'; // All, Pending, Approved, Rejected, Cancelled

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaveRequestsProvider.notifier).loadRequests();
      ref.read(leaveTypesProvider.notifier).loadLeaveTypes();
    });
  }

  void _showApplyLeaveSheet(
    BuildContext context,
    List<LeaveTypeModel> activeTypes,
    List<LeaveBalanceModel> balances, {
    LeaveRequestModel? existingRequest,
  }) {
    if (activeTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No leave types are currently configured by the administrator.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApplyLeaveSheet(
        activeTypes: activeTypes,
        balances: balances,
        existingRequest: existingRequest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Define tabs based on role
    int tabCount = 1;
    List<Tab> tabs = [];
    List<Widget> tabViews = [];

    final isCompanyAdmin = user.role == UserRoles.companyAdmin;
    final isHR = user.role == UserRoles.hrAdmin || user.role == UserRoles.hrExecutive || user.role == UserRoles.hr;
    final isManager = user.role == UserRoles.manager || user.role == UserRoles.teamLeader;

    if (isCompanyAdmin) {
      tabCount = 2;
      tabs = const [
        Tab(text: "Leave Requests", icon: Icon(Icons.history_toggle_off_rounded)),
        Tab(text: "Leave Types", icon: Icon(Icons.settings_outlined)),
      ];
      tabViews = [
        _buildRequestsTab(user),
        _buildLeaveTypesTab(user),
      ];
    } else if (isHR) {
      tabCount = 2;
      tabs = const [
        Tab(text: "All Company Requests", icon: Icon(Icons.list_alt_rounded)),
        Tab(text: "My Leaves", icon: Icon(Icons.person_outline_rounded)),
      ];
      tabViews = [
        _buildRequestsTab(user),
        _buildEmployeeTab(user),
      ];
    } else if (isManager) {
      tabCount = 2;
      tabs = const [
        Tab(text: "Team Requests", icon: Icon(Icons.people_outline_rounded)),
        Tab(text: "My Leaves", icon: Icon(Icons.person_outline_rounded)),
      ];
      tabViews = [
        _buildRequestsTab(user),
        _buildEmployeeTab(user),
      ];
    } else {
      // Normal employee
      tabCount = 1;
      tabs = const [Tab(text: "My Leaves", icon: Icon(Icons.person_outline_rounded))];
      tabViews = [
        _buildEmployeeTab(user),
      ];
    }

    const primaryColor = Color(0xFF5B4CF0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD);

    Widget content;
    if (tabCount > 1) {
      content = DefaultTabController(
        length: tabCount,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Leave Management', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                  iconTheme: const IconThemeData(color: Colors.white),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, Color(0xFF7C72F4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                  ),
                  bottom: TabBar(
                    tabs: tabs,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                  ),
                )
              : PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Material(
                    color: primaryColor,
                    child: TabBar(
                      tabs: tabs,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
          body: TabBarView(children: tabViews),
        ),
      );
    } else {
      content = Scaffold(
        backgroundColor: scaffoldBg,
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('My Leaves', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                iconTheme: const IconThemeData(color: Colors.white),
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFF7C72F4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                ),
              )
            : null,
        body: _buildEmployeeTab(user),
      );
    }

    return content;
  }

  // ==========================================
  // REQUESTS TAB (ADMIN / HR / MANAGER)
  // ==========================================
  Widget _buildRequestsTab(UserModel currentUser) {
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final employees = ref.watch(companyEmployeesProvider).value ?? [];
    final leaveTypes = ref.watch(leaveTypesProvider).value ?? [];

    return RefreshIndicator(
      onRefresh: () => ref.read(leaveRequestsProvider.notifier).loadRequests(),
      child: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading requests: $err', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter'))),
        data: (requests) {
          // Filter requests based on status filter
          var filtered = requests;
          if (currentUser.role == UserRoles.manager || currentUser.role == UserRoles.teamLeader) {
            // Managers should only see pending requests of their team
            filtered = filtered.where((r) => r.managerId == currentUser.uid || r.employeeId == currentUser.uid).toList();
          }

          if (_requestsFilter != 'All') {
            filtered = filtered.where((r) => r.status.toLowerCase() == _requestsFilter.toLowerCase()).toList();
          }

          return Column(
            children: [
              _buildRequestsFilterHeader(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.list_alt_rounded,
                        title: 'No leave requests found',
                        description: 'There are no leave requests matching the active filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          final emp = employees.firstWhere(
                            (e) => e.uid == r.employeeId,
                            orElse: () => UserModel(uid: '', email: '', name: 'Unknown Employee', role: '', companyId: '', companyName: '', createdAt: DateTime.now()),
                          );
                          final lt = leaveTypes.firstWhere(
                            (t) => t.leaveTypeId == r.leaveTypeId,
                            orElse: () => LeaveTypeModel(leaveTypeId: '', companyId: '', leaveName: 'Leave', annualQuota: 0, carryForwardAllowed: false, requiresApproval: false, createdAt: DateTime.now()),
                          );

                          return _buildRequestAdminCard(currentUser, r, emp, lt);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestsFilterHeader() {
    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: outlineVariantColor.withOpacity(0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Pending', 'Approved', 'Rejected', 'Cancelled'].map((f) {
            final isSelected = _requestsFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(f, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                selectedColor: primaryColor.withOpacity(0.15),
                checkmarkColor: primaryColor,
                labelStyle: TextStyle(color: isSelected ? primaryColor : const Color(0xFF64748B)),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: isSelected ? primaryColor.withOpacity(0.3) : outlineVariantColor.withOpacity(0.3)),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _requestsFilter = f;
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestAdminCard(UserModel currentUser, LeaveRequestModel r, UserModel emp, LeaveTypeModel lt) {
    final startStr = DateFormat('dd MMM').format(r.fromDate);
    final endStr = DateFormat('dd MMM yyyy').format(r.toDate);
    final appliedStr = DateFormat('dd MMM yyyy hh:mm a').format(r.createdAt);

    Color statusColor = const Color(0xFFEAB308);
    Color statusBg = const Color(0xFFFEF9C3);
    switch (r.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF006C49);
        statusBg = const Color(0xFFDCFCE7);
        break;
      case 'rejected':
        statusColor = const Color(0xFFBA1A1A);
        statusBg = const Color(0xFFFEF2F2);
        break;
      case 'cancelled':
        statusColor = Colors.blueGrey;
        statusBg = Colors.blueGrey.shade50;
        break;
    }

    final isPending = r.status == 'Pending';
    final isSelf = r.employeeId == currentUser.uid;
    final isHR = currentUser.role == UserRoles.companyAdmin || currentUser.role == UserRoles.hrAdmin || currentUser.role == UserRoles.hrExecutive || currentUser.role == UserRoles.hr;
    
    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isSelf ? '${emp.name} (Myself)' : emp.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B1B24))),
                    const SizedBox(height: 2),
                    Text('Applied: $appliedStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(lt.leaveName, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text('Dates: $startStr - $endStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1B1B24), fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    r.status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text('Total Duration: ${r.totalDays} Days', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569))),
              ],
            ),
            const SizedBox(height: 6),
            Text('Reason: "${r.reason}"', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
            if (r.approvedBy != null) ...[
              const Divider(height: 20),
              Text(
                'Processed by ID: ${r.approvedBy}',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF006C49), fontWeight: FontWeight.bold),
              ),
            ],
            if (isPending && !isSelf) ...[
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isHR) ...[
                    TextButton(
                      onPressed: () => _showOverrideRequestDialog(r, emp, lt),
                      style: TextButton.styleFrom(foregroundColor: primaryColor),
                      child: const Text('Override', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => _confirmUpdateStatus(r.leaveRequestId, 'Rejected'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFBA1A1A)),
                    child: const Text('Reject', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _confirmUpdateStatus(r.leaveRequestId, 'Approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006C49),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Approve', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EMPLOYEE VIEW (MY LEAVES)
  // ==========================================
  Widget _buildEmployeeTab(UserModel currentUser) {
    final leaveTypes = ref.watch(leaveTypesProvider).value ?? [];
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final balancesAsync = ref.watch(leaveBalancesProvider(currentUser.uid));

    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(leaveRequestsProvider.notifier).loadRequests();
        await ref.read(leaveBalancesProvider(currentUser.uid).notifier).loadBalances();
        await ref.read(leaveTypesProvider.notifier).loadLeaveTypes();
      },
      child: Column(
        children: [
          // 1. Leave Balance Cards (Redesigned horizontally scrollable bento list)
          balancesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error loading balances: $err', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter')),
            ),
            data: (balances) {
              if (leaveTypes.isEmpty) return const SizedBox();

              return Container(
                height: 110,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: leaveTypes.length,
                  itemBuilder: (context, index) {
                    final lt = leaveTypes[index];
                    final match = balances.where((b) => b.leaveTypeId == lt.leaveTypeId);
                    final bal = match.isNotEmpty
                        ? match.first
                        : LeaveBalanceModel(
                            employeeId: currentUser.uid,
                            companyId: currentUser.companyId,
                            leaveTypeId: lt.leaveTypeId,
                            allocated: lt.annualQuota,
                            used: 0,
                            remaining: lt.annualQuota,
                            updatedAt: DateTime.now(),
                          );

                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF111827).withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lt.leaveName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B1B24), fontFamily: 'Inter')),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Allocated', style: TextStyle(fontSize: 8, color: Color(0xFF64748B), fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                  Text('${bal.allocated}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF474555), fontFamily: 'Inter')),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Used', style: TextStyle(fontSize: 8, color: Color(0xFF64748B), fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                  Text('${bal.used}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFEAB308), fontFamily: 'Inter')),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Remaining', style: TextStyle(fontSize: 8, color: Color(0xFF64748B), fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                  Text('${bal.remaining}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF006C49), fontFamily: 'Inter')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // 2. Personal History Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Leave Request History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B24), fontFamily: 'Inter')),
            ),
          ),

          // 3. Request history list
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading history: $err', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter'))),
              data: (requests) {
                // Filter only own requests
                final personal = requests.where((r) => r.employeeId == currentUser.uid).toList();

                if (personal.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    title: 'No leave applications',
                    description: 'You have not submitted any leave applications yet. Tap the button below to apply.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: personal.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final r = personal[index];
                    final lt = leaveTypes.firstWhere(
                      (t) => t.leaveTypeId == r.leaveTypeId,
                      orElse: () => LeaveTypeModel(leaveTypeId: '', companyId: '', leaveName: 'Leave', annualQuota: 0, carryForwardAllowed: false, requiresApproval: false, createdAt: DateTime.now()),
                    );

                    return _buildPersonalHistoryCard(r, lt);
                  },
                );
              },
            ),
          ),

          // 4. Action Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.transparent,
            child: ElevatedButton.icon(
              onPressed: () {
                final balances = balancesAsync.value ?? [];
                _showApplyLeaveSheet(context, leaveTypes, balances);
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Apply Leave Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalHistoryCard(LeaveRequestModel r, LeaveTypeModel lt) {
    final startStr = DateFormat('dd MMM').format(r.fromDate);
    final endStr = DateFormat('dd MMM yyyy').format(r.toDate);
    final appliedStr = DateFormat('dd MMM yyyy hh:mm a').format(r.createdAt);

    Color statusColor = const Color(0xFFEAB308);
    Color statusBg = const Color(0xFFFEF9C3);
    switch (r.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF006C49);
        statusBg = const Color(0xFFDCFCE7);
        break;
      case 'rejected':
        statusColor = const Color(0xFFBA1A1A);
        statusBg = const Color(0xFFFEF2F2);
        break;
      case 'cancelled':
        statusColor = Colors.blueGrey;
        statusBg = Colors.blueGrey.shade50;
        break;
    }

    final isPending = r.status == 'Pending';
    const outlineVariantColor = Color(0xFFC8C4D8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.01),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(lt.leaveName, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    r.status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            Text('Dates: $startStr - $endStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF1B1B24), fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total Duration: ${r.totalDays} Days', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('Reason: "${r.reason}"', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text('Submitted: $appliedStr', style: const TextStyle(fontFamily: 'Inter', fontSize: 9, color: Color(0xFF94A3B8))),
            if (isPending) ...[
              const Divider(height: 18, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final user = ref.read(authProvider).user;
                      final balances = user != null ? (ref.read(leaveBalancesProvider(user.companyId)).value ?? []) : <LeaveBalanceModel>[];
                      final leaveTypes = ref.read(leaveTypesProvider).value ?? [];
                      _showApplyLeaveSheet(context, leaveTypes, balances, existingRequest: r);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Edit Request', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF5B4CF0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmCancelLeave(r.leaveRequestId),
                    icon: const Icon(Icons.cancel, size: 14),
                    label: const Text('Cancel Request', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFBA1A1A),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CONFIGURE LEAVE TYPES TAB (ADMIN)
  // ==========================================
  Widget _buildLeaveTypesTab(UserModel companyAdmin) {
    final leaveTypesAsync = ref.watch(leaveTypesProvider);
    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Leave Types', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B24))),
              ElevatedButton.icon(
                onPressed: () => _showLeaveTypeFormDialog(companyAdmin.companyId),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Type', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: leaveTypesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading leave types: $err', style: const TextStyle(color: Color(0xFFBA1A1A), fontFamily: 'Inter'))),
            data: (types) {
              final activeTypes = types.where((t) => t.status == 'active').toList();
              if (activeTypes.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.settings_outlined,
                  title: 'No leave types configured',
                  description: 'Add leave types (e.g. Sick Leave, Casual Leave) to allow employees to submit requests.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activeTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = activeTypes[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      title: Text(t.leaveName, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF1B1B24))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Annual Quota: ${t.annualQuota} Days', style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'Inter')),
                          const SizedBox(height: 2),
                          Text('Carry Forward: ${t.carryForwardAllowed ? "Yes" : "No"} • Requires Approval: ${t.requiresApproval ? "Yes" : "No"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Inter')),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 18),
                            onPressed: () => _showLeaveTypeFormDialog(companyAdmin.companyId, type: t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.archive_outlined, color: Color(0xFFBA1A1A), size: 18),
                            onPressed: () => _confirmArchiveLeaveType(t),
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
    );
  }

  // ==========================================
  // CONFIRMATION DIALOGS & ACTIONS
  // ==========================================
  void _confirmCancelLeave(String requestId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this leave request? This action cannot be undone.', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(leaveRequestsProvider.notifier).cancelLeave(requestId);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request cancelled.'), behavior: SnackBarBehavior.floating));
            },
            child: const Text('Yes, Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmUpdateStatus(String requestId, String status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$status Request', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to ${status.toLowerCase()} this leave request?', style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'Approved' ? const Color(0xFF006C49) : const Color(0xFFBA1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(authProvider).user;
              if (user == null) return;
              await ref.read(leaveRequestsProvider.notifier).updateRequestStatus(requestId, status, user.uid);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave request status updated to $status.'), behavior: SnackBarBehavior.floating));
            },
            child: Text(status, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmArchiveLeaveType(LeaveTypeModel type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Archive Leave Type', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to archive "${type.leaveName}"? Employees will no longer be able to select this leave type.', style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(leaveTypesProvider.notifier).archiveLeaveType(type.leaveTypeId);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave type archived.'), behavior: SnackBarBehavior.floating));
            },
            child: const Text('Archive', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // OVERRIDE DATES DIALOG (HR ADMIN)
  // ==========================================
  void _showOverrideRequestDialog(LeaveRequestModel r, UserModel emp, LeaveTypeModel lt) {
    DateTime start = r.fromDate;
    DateTime end = r.toDate;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Override Leave Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setModalState) {
            final days = end.difference(start).inDays + 1;
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Employee: ${emp.name}', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Leave Type: ${lt.leaveName}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Start Date: ${DateFormat('dd/MM/yyyy').format(start)}', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                    trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) {
                        setModalState(() {
                          start = picked;
                          if (end.isBefore(start)) end = start;
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('End Date: ${DateFormat('dd/MM/yyyy').format(end)}', style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                    trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: end, firstDate: start, lastDate: DateTime(2100));
                      if (picked != null) {
                        setModalState(() {
                          end = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Recalculated Duration: $days Days', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(authProvider).user;
              if (user == null) return;

              final updated = r.copyWith(
                fromDate: start,
                toDate: end,
                totalDays: end.difference(start).inDays + 1,
                status: 'Approved',
                approvedBy: user.uid,
                approvedAt: DateTime.now(),
              );

              await ref.read(leaveRequestsProvider.notifier).overrideRequest(updated);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave dates overridden and request approved.'), behavior: SnackBarBehavior.floating));
            },
            child: const Text('Override & Approve', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // LEAVE TYPE FORM DIALOG
  // ==========================================
  void _showLeaveTypeFormDialog(String companyId, {LeaveTypeModel? type}) {
    final isEdit = type != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: type?.leaveName);
    final quotaCtrl = TextEditingController(text: type != null ? '${type.annualQuota}' : '12');
    bool carryAllowed = type?.carryForwardAllowed ?? true;
    bool reqApprove = type?.requiresApproval ?? true;

    InputDecoration _inputStyle(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFC8C4D8).withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5B4CF0), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isEdit ? 'Edit Leave Type' : 'Add Leave Type', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
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
                          decoration: _inputStyle('Leave Type Name *', Icons.type_specimen_rounded),
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: quotaCtrl,
                          decoration: _inputStyle('Annual Quota (Days) *', Icons.date_range_rounded),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final parsed = int.tryParse(v);
                            if (parsed == null || parsed < 0) return 'Must be a positive integer';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Carry Forward Allowed', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                          value: carryAllowed,
                          onChanged: (val) {
                            setDialogState(() {
                              carryAllowed = val;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Requires Approval', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500)),
                          value: reqApprove,
                          onChanged: (val) {
                            setDialogState(() {
                              reqApprove = val;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newType = LeaveTypeModel(
                        leaveTypeId: type?.leaveTypeId ?? const Uuid().v4(),
                        companyId: companyId,
                        leaveName: nameCtrl.text.trim(),
                        annualQuota: int.parse(quotaCtrl.text),
                        carryForwardAllowed: carryAllowed,
                        requiresApproval: reqApprove,
                        status: type?.status ?? 'active',
                        createdAt: type?.createdAt ?? DateTime.now(),
                      );

                      await ref.read(leaveTypesProvider.notifier).saveLeaveType(newType);
                      Navigator.pop(ctx);
                      _showSnackBar('Leave type saved successfully.');
                    }
                  },
                  child: const Text('Save', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String description}) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F5F9)),
            child: Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', color: Colors.grey, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}

// ==========================================
// APPLY LEAVE BOTTOM SHEET (EMPLOYEE FORM)
// ==========================================
class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  final List<LeaveTypeModel> activeTypes;
  final List<LeaveBalanceModel> balances;
  final LeaveRequestModel? existingRequest;

  const _ApplyLeaveSheet({
    required this.activeTypes,
    required this.balances,
    this.existingRequest,
  });

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _reasonCtrl;
  String? _selectedTypeId;
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(text: widget.existingRequest?.reason ?? '');
    if (widget.existingRequest != null) {
      _selectedTypeId = widget.existingRequest!.leaveTypeId;
      _fromDate = widget.existingRequest!.fromDate;
      _toDate = widget.existingRequest!.toDate;
    } else {
      if (widget.activeTypes.isNotEmpty) {
        _selectedTypeId = widget.activeTypes.first.leaveTypeId;
      }
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int _calculateTotalDays() {
    return _toDate.difference(_fromDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authProvider).user;
    if (user == null) return const SizedBox();

    final selectedType = widget.activeTypes.firstWhere((t) => t.leaveTypeId == _selectedTypeId, orElse: () => widget.activeTypes.first);
    final matchBal = widget.balances.where((b) => b.leaveTypeId == selectedType.leaveTypeId);
    final remainingDays = matchBal.isNotEmpty ? matchBal.first.remaining : selectedType.annualQuota;
    final totalDays = _calculateTotalDays();

    const primaryColor = Color(0xFF422CD8);
    const outlineVariantColor = Color(0xFFC8C4D8);

    InputDecoration _inputStyle(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outlineVariantColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingRequest != null ? 'Edit Leave Request' : 'Apply For Leave',
                    style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B1B24)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedTypeId,
                decoration: _inputStyle('Leave Type *', Icons.time_to_leave_rounded),
                items: widget.activeTypes.map((t) => DropdownMenuItem(value: t.leaveTypeId, child: Text(t.leaveName, style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTypeId = val;
                  });
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: outlineVariantColor.withOpacity(0.2))),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Text('Available Balance for this type: $remainingDays Days', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _fromDate = picked;
                            if (_toDate.isBefore(_fromDate)) {
                              _toDate = _fromDate;
                            }
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date *', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(_fromDate), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B1B24))),
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _toDate,
                          firstDate: _fromDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _toDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: outlineVariantColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Date *', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(_toDate), style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B1B24))),
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC).withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded, color: Color(0xFF006C49), size: 16),
                    const SizedBox(width: 8),
                    Text('Total Duration: $totalDays Days', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF006C49))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonCtrl,
                decoration: _inputStyle('Reason for Leave *', Icons.edit_note_rounded),
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please describe your reason.' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _submitApplication(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existingRequest != null ? 'Update Application' : 'Submit Application', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitApplication(UserModel currentUser) async {
    if (!_formKey.currentState!.validate()) return;

    final selectedType = widget.activeTypes.firstWhere((t) => t.leaveTypeId == _selectedTypeId, orElse: () => widget.activeTypes.first);
    final matchBal = widget.balances.where((b) => b.leaveTypeId == selectedType.leaveTypeId);
    final remainingDays = matchBal.isNotEmpty ? matchBal.first.remaining : selectedType.annualQuota;
    final totalDays = _calculateTotalDays();

    // 1. Balance validation
    final currentReqDays = widget.existingRequest != null ? widget.existingRequest!.totalDays : 0;
    final adjustedRemaining = remainingDays + currentReqDays;

    if (totalDays > adjustedRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient leave balance. You have $adjustedRemaining days left for "${selectedType.leaveName}" but applied for $totalDays days.', style: const TextStyle(fontFamily: 'Inter')),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Overlapping date checks
    final history = ref.read(leaveRequestsProvider).value ?? [];
    final hasOverlap = history.any((r) =>
        r.leaveRequestId != widget.existingRequest?.leaveRequestId &&
        r.employeeId == currentUser.uid &&
        r.status != 'Cancelled' &&
        r.status != 'Rejected' &&
        ((!_fromDate.isBefore(r.fromDate) && !_fromDate.isAfter(r.toDate)) ||
            (!_toDate.isBefore(r.fromDate) && !_toDate.isAfter(r.toDate)) ||
            (_fromDate.isBefore(r.fromDate) && _toDate.isAfter(r.toDate))));

    if (hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already applied/approved leave requests overlapping with these dates.', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final holidays = ref.read(adminHolidaysProvider).value ?? [];
    final overlappingHolidays = holidays.where((h) {
      if (h.status != 'active') return false;
      if (h.branchId != null && h.branchId!.isNotEmpty && h.branchId != currentUser.branchId) {
        return false;
      }
      return !h.holidayDate.isBefore(_fromDate) && !h.holidayDate.isAfter(_toDate);
    }).toList();

    if (overlappingHolidays.isNotEmpty) {
      final names = overlappingHolidays.map((h) => h.holidayName).join(', ');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Holiday Warning', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text('The selected date range contains the following holiday(s): $names.\n\nDo you still want to proceed with applying for leave?', style: const TextStyle(fontFamily: 'Inter')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed', style: TextStyle(color: Colors.white, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      final req = LeaveRequestModel(
        leaveRequestId: widget.existingRequest?.leaveRequestId ?? const Uuid().v4(),
        companyId: currentUser.companyId,
        employeeId: currentUser.uid,
        leaveTypeId: selectedType.leaveTypeId,
        fromDate: _fromDate,
        toDate: _toDate,
        totalDays: totalDays,
        reason: _reasonCtrl.text.trim(),
        status: selectedType.requiresApproval ? 'Pending' : 'Approved',
        managerId: currentUser.managerId,
        approvedBy: selectedType.requiresApproval ? null : 'System (Auto-Approved)',
        approvedAt: selectedType.requiresApproval ? null : DateTime.now(),
        createdAt: widget.existingRequest?.createdAt ?? DateTime.now(),
      );

      await ref.read(leaveRequestsProvider.notifier).applyLeave(req);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingRequest != null ? 'Leave request updated successfully.' : 'Leave application submitted successfully.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: const Color(0xFFBA1A1A), behavior: SnackBarBehavior.floating),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
