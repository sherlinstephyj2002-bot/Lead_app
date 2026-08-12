import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import '../../../shared/widgets/app_user_avatar.dart';

import '../../../shared/providers/permissions_provider.dart';

class HRExecutiveDashboard extends ConsumerWidget {
  const HRExecutiveDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final employeesAsync = ref.watch(companyEmployeesProvider);
    final attendanceTodayAsync = ref.watch(companyAttendanceTodayProvider);
    final overrideState = ref.watch(overrideRequestsProvider);
    final leavesState = ref.watch(leavesProvider);

    final totalEmployees = employeesAsync.value?.length ?? 0;
    final attendanceToday = attendanceTodayAsync.value ?? [];
    final today = DateTime.now();
    final presentToday = attendanceToday.where((log) =>
        log.checkInTime.year == today.year &&
        log.checkInTime.month == today.month &&
        log.checkInTime.day == today.day
    ).map((log) => log.employeeId).toSet().length;

    final pendingMissedPunches = overrideState.pendingCorrections.length;
    final pendingOvertime = overrideState.pendingEmployeeRequests.length;
    final pendingLeaves = (leavesState.value ?? []).where((l) => l.status == 'Pending').length;
    final pendingPayrollSubmission = 0; // Driven by live payroll state

    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // Header App Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF422CD8), Color(0xFF5B4CF0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AppUserAvatar(user: user, radius: 22),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter'),
                              ),
                              Text(
                                'HR Executive Portal',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontFamily: 'Inter'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                            onPressed: () {
                              ref.read(companyEmployeesProvider);
                              ref.read(companyAttendanceTodayProvider);
                              ref.read(overrideRequestsProvider.notifier).loadAllRequests();
                            },
                          ),
                          const NotificationBellWidget(iconColor: Colors.white, iconSize: 24),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Operational HR & Attendance Overview',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
          ),

          // Main Operational Dashboard Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Summary Cards Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.8,
                      children: [
                        _buildMetricCard(
                          context: context,
                          title: "Today's Attendance",
                          value: '$presentToday / $totalEmployees',
                          subtitle: totalEmployees > 0 ? '${((presentToday / totalEmployees) * 100).toStringAsFixed(0)}% present today' : 'No staff registered',
                          icon: Icons.fingerprint_rounded,
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        _buildMetricCard(
                          context: context,
                          title: 'Pending Missed Punches',
                          value: '$pendingMissedPunches',
                          subtitle: pendingMissedPunches == 0 ? 'No pending missed punch requests.' : 'Action required',
                          icon: Icons.access_time_filled_rounded,
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                        _buildMetricCard(
                          context: context,
                          title: 'Pending Overtime',
                          value: '$pendingOvertime',
                          subtitle: pendingOvertime == 0 ? 'No overtime requests pending verification.' : 'Requires verification',
                          icon: Icons.more_time_rounded,
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                        _buildMetricCard(
                          context: context,
                          title: 'Pending Leaves',
                          value: '$pendingLeaves',
                          subtitle: pendingLeaves == 0 ? 'No pending leave requests.' : 'Awaiting HR review',
                          icon: Icons.event_note_rounded,
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                        _buildMetricCard(
                          context: context,
                          title: 'Payroll Status',
                          value: 'Draft',
                          subtitle: 'Current period open',
                          icon: Icons.payments_rounded,
                          color: const Color(0xFF6366F1),
                          isDark: isDark,
                        ),
                        _buildMetricCard(
                          context: context,
                          title: 'Pending Submission',
                          value: '$pendingPayrollSubmission',
                          subtitle: 'Ready for HR Admin review',
                          icon: Icons.send_rounded,
                          color: const Color(0xFFEC4899),
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // HR Operational Actions Section
                Text(
                  'Operational Workflows',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Inter'),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Builder(
                    builder: (context) {
                      final permService = ref.watch(permissionServiceProvider);
                      final canAttendance = permService.hasPermission('attendance_view') || permService.hasPermission('attendance_approve');
                      final canPayroll = permService.hasPermission('payroll_view') || permService.hasPermission('payroll_manage');
                      final canReports = permService.hasPermission('reports_view');

                      return Column(
                        children: [
                          if (canAttendance)
                            _buildActionRow(
                              context,
                              icon: Icons.fact_check_rounded,
                              color: const Color(0xFF5B4CF0),
                              title: 'Attendance Review & Corrections',
                              subtitle: 'Review daily check-ins, approve missed punches & correct logs',
                              onTap: () => context.push('/company-admin/override-approval'),
                            ),
                          if (canAttendance && (canPayroll || canReports)) const Divider(height: 20),
                          if (canPayroll)
                            _buildActionRow(
                              context,
                              icon: Icons.payments_rounded,
                              color: const Color(0xFF10B981),
                              title: 'Monthly Payroll Preparation',
                              subtitle: 'Verify working days, overtime, LOP & submit payroll to HR Admin',
                              onTap: () => context.push('/company-admin/payroll-processing'),
                            ),
                          if (canPayroll && canReports) const Divider(height: 20),
                          if (canReports)
                            _buildActionRow(
                              context,
                              icon: Icons.analytics_rounded,
                              color: const Color(0xFFF59E0B),
                              title: 'HR Reports & Insights',
                              subtitle: 'Export daily attendance, monthly logs, overtime & leave reports',
                              onTap: () => context.push('/reports'),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter'),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Inter'),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Inter'),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
