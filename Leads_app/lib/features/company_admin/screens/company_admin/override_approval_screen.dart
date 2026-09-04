import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:worktrack/shared/models/leave_type_model.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/providers/export_queue_provider.dart';
import 'package:worktrack/shared/widgets/export_queue_sheet.dart';

class OverrideApprovalScreen extends ConsumerStatefulWidget {
  const OverrideApprovalScreen({super.key});

  @override
  ConsumerState<OverrideApprovalScreen> createState() => _OverrideApprovalScreenState();
}

class _OverrideApprovalScreenState extends ConsumerState<OverrideApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController.length != 5) {
      _tabController = TabController(length: 5, vsync: this);
    }
    final state = ref.watch(overrideRequestsProvider);
    final totalPendingCount = state.pendingLeaves.length + state.pendingExpenses.length + state.pendingCorrections.length + state.pendingEmployeeRequests.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;

    // Show error or success messages
    ref.listen<OverrideRequestsState>(overrideRequestsProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(next.errorMessage!, style: const TextStyle(color: Colors.white))),
            ]),
            backgroundColor: const Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(overrideRequestsProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        foregroundColor: isDark ? Colors.white : const Color(0xFF191C1E),
        elevation: 0,
        title: const Text('Override Approvals Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF422CD8))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E3E5), height: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header with Export & Filter Actions
                if (isCompact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Override Approvals',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF191C1E), fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage and review manual attendance correction requests, expenses, leaves & HR overrides.',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.filter_list_rounded, size: 16),
                              label: const Text('Filter'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF474555),
                                side: const BorderSide(color: Color(0xFFC8C4D8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => const ExportQueueSheet(),
                                );
                              },
                              icon: const Icon(Icons.file_upload_outlined, size: 16),
                              label: const Text('Export Queue'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF422CD8),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Override Approvals',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF191C1E), fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage and review manual attendance correction requests, expenses, leaves & HR overrides.',
                              style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(exportQueueProvider.notifier).createExportJob(
                                reportName: 'Override Approvals Report',
                                fileType: 'Excel (.xlsx)',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Export Started\nYour report is being generated. You can continue working while it is processed.'),
                                  backgroundColor: const Color(0xFF5B4CF0),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: 'View Queue',
                                    textColor: Colors.amberAccent,
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (ctx) => const ExportQueueSheet(),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Export Report'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF474555),
                              side: const BorderSide(color: Color(0xFFC8C4D8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => const ExportQueueSheet(),
                              );
                            },
                            icon: const Icon(Icons.file_upload_outlined, size: 18),
                            label: const Text('Export Queue'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF422CD8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Top Stats Row
                if (isCompact)
                  Column(
                    children: [
                      _buildStatCard(
                        title: 'TOTAL PENDING',
                        value: '$totalPendingCount',
                        icon: Icons.pending_actions_rounded,
                        iconColor: const Color(0xFF422CD8),
                        bgColor: const Color(0xFF422CD8).withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        title: 'APPROVED TODAY',
                        value: '0',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF007834),
                        bgColor: const Color(0xFF007834).withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 12),
                      _buildStatCard(
                        title: 'REJECTED TODAY',
                        value: '0',
                        icon: Icons.cancel_outlined,
                        iconColor: const Color(0xFFBA1A1A),
                        bgColor: const Color(0xFFBA1A1A).withValues(alpha: 0.08),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'TOTAL PENDING',
                          value: '$totalPendingCount',
                          icon: Icons.pending_actions_rounded,
                          iconColor: const Color(0xFF422CD8),
                          bgColor: const Color(0xFF422CD8).withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildStatCard(
                          title: 'APPROVED TODAY',
                          value: '0',
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF007834),
                          bgColor: const Color(0xFF007834).withValues(alpha: 0.08),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildStatCard(
                          title: 'REJECTED TODAY',
                          value: '0',
                          icon: Icons.cancel_outlined,
                          iconColor: const Color(0xFFBA1A1A),
                          bgColor: const Color(0xFFBA1A1A).withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),

                // Main Queue Container
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Tab Navigation & Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                        child: isCompact
                            ? Column(
                                children: [
                                  TabBar(
                                    controller: _tabController,
                                    labelColor: const Color(0xFF422CD8),
                                    unselectedLabelColor: const Color(0xFF474555),
                                    indicatorColor: const Color(0xFF422CD8),
                                    indicatorWeight: 3,
                                    isScrollable: true,
                                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    tabs: [
                                      Tab(text: 'Corrections (${state.pendingCorrections.length})'),
                                      Tab(text: 'Auto Absent Review'),
                                      Tab(text: 'Leaves (${state.pendingLeaves.length})'),
                                      Tab(text: 'Expenses (${state.pendingExpenses.length})'),
                                      Tab(text: 'HR Requests (${state.pendingEmployeeRequests.length})'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _searchCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Search approvals...',
                                        prefixIcon: const Icon(Icons.search, size: 18),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: TabBar(
                                      controller: _tabController,
                                      labelColor: const Color(0xFF422CD8),
                                      unselectedLabelColor: const Color(0xFF474555),
                                      indicatorColor: const Color(0xFF422CD8),
                                      indicatorWeight: 3,
                                      isScrollable: true,
                                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      tabs: [
                                        Tab(text: 'Corrections (${state.pendingCorrections.length})'),
                                        Tab(text: 'Auto Absent Review'),
                                        Tab(text: 'Leaves (${state.pendingLeaves.length})'),
                                        Tab(text: 'Expenses (${state.pendingExpenses.length})'),
                                        Tab(text: 'HR Requests (${state.pendingEmployeeRequests.length})'),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 240,
                                    height: 38,
                                    child: TextField(
                                      controller: _searchCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Search approvals...',
                                        prefixIcon: const Icon(Icons.search, size: 18),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      // Tab Contents
                      SizedBox(
                        height: 480,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCorrectionsTab(state),
                            _buildAutoAbsentTab(state),
                            _buildLeavesTab(state),
                            _buildExpensesTab(state),
                            _buildHRRequestsTab(state),
                          ],
                        ),
                      ),

                      // Footer Pagination Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Showing $totalPendingCount pending requests',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left), iconSize: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFF422CD8), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 4),
                                IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right), iconSize: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF191C1E), fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeavesTab(OverrideRequestsState state) {
    if (state.pendingLeaves.isEmpty) {
      return _buildEmptyState('No pending leave requests in queue.');
    }

    final employees = ref.watch(companyEmployeesProvider).value ?? [];
    final leaveTypes = ref.watch(leaveTypesProvider).value ?? [];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.pendingLeaves.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final leave = state.pendingLeaves[index];
        final emp = employees.firstWhere(
          (e) => e.uid == leave.employeeId,
          orElse: () => UserModel(uid: '', email: '', name: 'Employee', role: '', companyId: '', companyName: '', createdAt: DateTime.now()),
        );
        final leaveType = leaveTypes.firstWhere(
          (t) => t.leaveTypeId == leave.leaveTypeId,
          orElse: () => LeaveTypeModel(leaveTypeId: '', companyId: '', leaveName: 'Leave Request', annualQuota: 0, carryForwardAllowed: false, requiresApproval: false, createdAt: DateTime.now()),
        );
        final start = DateFormat('MMM dd, yyyy').format(leave.fromDate);

        return _buildRequestRow(
          name: emp.name.isNotEmpty ? emp.name : 'Employee',
          department: emp.department ?? 'General',
          badgeText: leaveType.leaveName.toUpperCase(),
          badgeColor: const Color(0xFF422CD8),
          timestamp: '$start • ${leave.totalDays} Days',
          reason: leave.reason,
          onReject: () => ref.read(overrideRequestsProvider.notifier).rejectLeave(leave.leaveRequestId),
          onApprove: () => ref.read(overrideRequestsProvider.notifier).approveLeave(leave.leaveRequestId),
        );
      },
    );
  }

  Widget _buildExpensesTab(OverrideRequestsState state) {
    if (state.pendingExpenses.isEmpty) {
      return _buildEmptyState('No pending expense claims in queue.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.pendingExpenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final exp = state.pendingExpenses[index];
        final date = DateFormat('MMM dd, yyyy').format(exp.createdAt);

        return _buildRequestRow(
          name: exp.employeeName,
          department: 'Expenses',
          badgeText: 'EXPENSE CLAIM: ₹${exp.amount}',
          badgeColor: const Color(0xFF007834),
          timestamp: date,
          reason: '${exp.category}: "${exp.description}"',
          onReject: () async {
              await ref.read(overrideRequestsProvider.notifier).rejectExpense(exp.expenseId);
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Expense rejected.'),
                  backgroundColor: const Color(0xFFBA1A1A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
          onApprove: () async {
              await ref.read(overrideRequestsProvider.notifier).approveExpense(exp.expenseId);
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Expense approved.'),
                  backgroundColor: const Color(0xFF007834),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ));
              }
            },
        );
      },
    );
  }

  Widget _buildCorrectionsTab(OverrideRequestsState state) {
    if (state.pendingCorrections.isEmpty) {
      return _buildEmptyState('No pending attendance correction requests.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.pendingCorrections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final att = state.pendingCorrections[index];
        final date = DateFormat('MMM dd, yyyy • hh:mm a').format(att.checkInTime);

        return _buildRequestRow(
          name: att.employeeName,
          department: 'Attendance',
          badgeText: 'MISSED CHECK-IN CORRECTION',
          badgeColor: const Color(0xFFD97706),
          timestamp: date,
          reason: 'Manual override for attendance correction.',
          onReject: () => ref.read(overrideRequestsProvider.notifier).resolveAttendanceCorrection(att.attendanceId, 'Absent'),
          onApprove: () => ref.read(overrideRequestsProvider.notifier).resolveAttendanceCorrection(att.attendanceId, 'Present'),
        );
      },
    );
  }

  Widget _buildAutoAbsentTab(OverrideRequestsState state) {
    final autoAbsentList = state.pendingCorrections.where((att) => att.isAutoAbsent || att.correctionReason?.contains('Auto Absent') == true).toList();
    if (autoAbsentList.isEmpty) {
      return _buildEmptyState('No pending auto absent review records.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: autoAbsentList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final att = autoAbsentList[index];
        final date = DateFormat('MMM dd, yyyy • hh:mm a').format(att.checkInTime);

        return _buildRequestRow(
          name: att.employeeName,
          department: 'Auto Absent Review',
          badgeText: 'SYSTEM AUTO ABSENT',
          badgeColor: const Color(0xFFEF4444),
          timestamp: date,
          reason: att.correctionReason ?? 'System auto absent triggered due to missed check-in threshold.',
          onReject: () => ref.read(overrideRequestsProvider.notifier).resolveAttendanceCorrection(att.attendanceId, 'Absent'),
          onApprove: () => ref.read(overrideRequestsProvider.notifier).resolveAttendanceCorrection(att.attendanceId, 'Present'),
        );
      },
    );
  }

  Widget _buildHRRequestsTab(OverrideRequestsState state) {
    if (state.pendingEmployeeRequests.isEmpty) {
      return _buildEmptyState('No pending HR employee approval requests.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: state.pendingEmployeeRequests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = state.pendingEmployeeRequests[index];
        final isAdd = req.requestType == 'ADD_EMPLOYEE';
        final targetName = isAdd ? (req.employeeData?['name'] ?? 'New Employee') : (req.employeeName ?? 'Employee');

        return _buildRequestRow(
          name: targetName,
          department: 'HR Management',
          badgeText: req.requestType.toUpperCase(),
          badgeColor: const Color(0xFF422CD8),
          timestamp: 'Requested by ${req.requestedBy}',
          reason: 'Employee onboard / role modification approval request.',
          onReject: () => ref.read(overrideRequestsProvider.notifier).resolveEmployeeRequest(req, false),
          onApprove: () => ref.read(overrideRequestsProvider.notifier).resolveEmployeeRequest(req, true),
        );
      },
    );
  }

  Widget _buildRequestRow({
    required String name,
    required String department,
    required String badgeText,
    required Color badgeColor,
    required String timestamp,
    required String reason,
    required VoidCallback onReject,
    required VoidCallback onApprove,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Header Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: badgeColor.withValues(alpha: 0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'E',
                        style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF191C1E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            department,
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Reason & Timestamp
                if (reason.isNotEmpty) ...[
                  Text(
                    '"$reason"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF474555)),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(timestamp, style: const TextStyle(fontSize: 11, color: Color(0xFF777587))),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFBA1A1A),
                          side: const BorderSide(color: Color(0xFFFFDAD6)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007834),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: badgeColor.withValues(alpha: 0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(department, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(badgeText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(timestamp, style: const TextStyle(fontSize: 11, color: Color(0xFF777587)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('"$reason"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF474555))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFBA1A1A),
                      side: const BorderSide(color: Color(0xFFFFDAD6)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007834),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: const Color(0xFF422CD8).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.assignment_turned_in_outlined, size: 32, color: Color(0xFF422CD8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Override Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: Color(0xFF191C1E)),
            ),
            const SizedBox(height: 6),
            Text(
              msg.isNotEmpty ? msg : 'There are currently no override approval requests.\nNew requests will appear here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter', height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
