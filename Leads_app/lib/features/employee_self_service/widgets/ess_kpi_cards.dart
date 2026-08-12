import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/ess_provider.dart';

class ESSKpiCards extends ConsumerWidget {
  const ESSKpiCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(essProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600;
        final crossCount = isDesktop ? 5 : (isTablet ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.6 : 1.5,
          children: [
            _buildCard(
              context,
              title: 'Present Days',
              value: '${state.presentDays} Days',
              subtitle: 'This Month',
              icon: Icons.fingerprint_rounded,
              color: const Color(0xFF0284C7),
              isDark: isDark,
              onTap: () => context.push('/ess/attendance'),
            ),
            _buildCard(
              context,
              title: 'Leave Balance',
              value: '${state.leaveBalance} Days',
              subtitle: 'Casual + Sick + Earned',
              icon: Icons.event_available_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () => context.push('/ess/leave'),
            ),
            _buildCard(
              context,
              title: 'Pending Requests',
              value: '${state.pendingLeaveRequests} Request',
              subtitle: 'Awaiting HR approval',
              icon: Icons.hourglass_top_rounded,
              color: const Color(0xFFF59E0B),
              isDark: isDark,
              onTap: () => context.push('/ess/leave'),
            ),
            _buildCard(
              context,
              title: 'Tasks Assigned',
              value: '${state.tasksAssigned} Tasks',
              subtitle: 'Due this week',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF5B4CF0),
              isDark: isDark,
              onTap: () => context.push('/ess/tasks'),
            ),
            _buildCard(
              context,
              title: 'Completed Tasks',
              value: '${state.completedTasks} Done',
              subtitle: 'This Quarter',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF059669),
              isDark: isDark,
              onTap: () => context.push('/ess/tasks'),
            ),
            _buildCard(
              context,
              title: 'Pending Expenses',
              value: '₹${state.pendingExpensesAmount.toStringAsFixed(0)}',
              subtitle: 'Reimbursement claim',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFD97706),
              isDark: isDark,
              onTap: () => context.push('/ess/expenses'),
            ),
            _buildCard(
              context,
              title: 'Attendance %',
              value: '${state.monthlyAttendancePercent}%',
              subtitle: 'Monthly Roster Score',
              icon: Icons.insights_rounded,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
              onTap: () => context.push('/ess/attendance'),
            ),
            _buildCard(
              context,
              title: 'Latest Payslip',
              value: state.latestPayslipAmount,
              subtitle: 'June 2026 Net Salary',
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () => context.push('/ess/payslips'),
            ),
            _buildCard(
              context,
              title: 'Upcoming Birthday',
              value: state.upcomingBirthday != '-' ? state.upcomingBirthday : 'None',
              subtitle: state.upcomingBirthday != '-' ? 'Upcoming Event' : 'No upcoming birthdays',
              icon: Icons.cake_rounded,
              color: const Color(0xFFEC4899),
              isDark: isDark,
              onTap: () => context.push('/calendar'),
            ),
            _buildCard(
              context,
              title: 'Next Payroll Date',
              value: state.nextPayrollDate,
              subtitle: 'Scheduled Disbursement',
              icon: Icons.event_rounded,
              color: const Color(0xFF6366F1),
              isDark: isDark,
              onTap: () => context.push('/ess/payslips'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
