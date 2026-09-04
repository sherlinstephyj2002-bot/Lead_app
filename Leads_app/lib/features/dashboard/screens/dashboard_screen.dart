import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/lead_model.dart';
import 'onboarding_wizard_screen.dart';
import 'hr_executive_dashboard.dart';
import 'company_admin_dashboard.dart';
import '../../../constants/user_roles.dart';
import '../../../shared/models/company_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/order_model.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../company_admin/screens/company_admin/employee_documents_screen.dart';
import '../../company_admin/screens/company_admin/employee_profile_screen.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import '../../../shared/widgets/app_user_avatar.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/followup_model.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/providers/permissions_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final companyAsync = ref.watch(companyProvider);
    final timerState = ref.watch(workTimerProvider);
    final leadsState = ref.watch(leadsProvider);
    final ordersState = ref.watch(ordersProvider);
    final tasksState = ref.watch(tasksProvider);

    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final employeesAsync = ref.watch(companyEmployeesProvider);
    final attendanceTodayAsync = ref.watch(companyAttendanceTodayProvider);

    // Attendance Info
    final isCheckedIn = attendanceState.todayLog != null && attendanceState.todayLog!.checkOutTime == null;
    final isCheckedOut = attendanceState.todayLog != null && attendanceState.todayLog!.checkOutTime != null;
    
    String attendanceStatusText = "Not Checked In";
    if (isCheckedIn) {
      attendanceStatusText = "Checked In at ${DateFormat('hh:mm a').format(attendanceState.todayLog!.checkInTime)}";
    } else if (isCheckedOut) {
      attendanceStatusText = "Checked Out at ${DateFormat('hh:mm a').format(attendanceState.todayLog!.checkOutTime!)}";
    }

    String locationText = attendanceState.todayLog?.address ?? "Location will be captured on check-in";

    // Dashboard Statistics calculation
    final today = DateTime.now();
    
    final employees = employeesAsync.value ?? [];
    final totalEmployees = employees.length;

    final attendanceToday = attendanceTodayAsync.value ?? [];
    final presentToday = <String>{};
    for (final log in attendanceToday) {
      if (log.checkInTime.year == today.year &&
          log.checkInTime.month == today.month &&
          log.checkInTime.day == today.day) {
        presentToday.add(log.employeeId);
        if (log.userEmployeeId != null && log.userEmployeeId!.isNotEmpty) {
          presentToday.add(log.userEmployeeId!);
        }
      }
    }
    final presentCount = attendanceToday.where((log) =>
        log.checkInTime.year == today.year &&
        log.checkInTime.month == today.month &&
        log.checkInTime.day == today.day
    ).map((log) => log.employeeId).toSet().length;

    final leads = leadsState.value ?? [];
    final leadsAddedCount = leads.where((l) => 
      l.createdAt.year == today.year && 
      l.createdAt.month == today.month && 
      l.createdAt.day == today.day
    ).length;

    final orders = ordersState.value ?? [];
    final ordersInProgress = orders.where((o) => 
      o.status != 'Completed' && o.status != 'Closed' && o.status != 'Cancelled'
    ).length;

    final activeLeadsCount = leads.where((l) => l.status != 'Converted' && l.status != 'Closed').length;

    final tasks = tasksState.value ?? [];
    final pendingTasksCount = tasks.where((t) =>
      t.assignedToId == user.uid && t.status != 'Completed'
    ).length;

    final notifications = ref.watch(notificationsProvider).value ?? [];
    final unreadRequestsCount = user.role == UserRoles.companyAdmin
        ? notifications.where((n) => !n.isRead).length
        : 0;

    final notificationCount = pendingTasksCount + unreadRequestsCount;

    final leavesState = ref.watch(leavesProvider);
    final leaves = leavesState.value ?? [];
    final leavesToday = leaves.where((l) =>
      l.status == 'Approved' &&
      !l.startDate.isAfter(today) &&
      !l.endDate.isBefore(DateTime(today.year, today.month, today.day))
    ).length;

    final followupsState = ref.watch(followupsProvider);
    final followups = followupsState.value ?? [];
    final pendingFollowupsCount = followups.where((f) => f.status == 'Upcoming' || f.status == 'Missed').length;

    if (UserRoles.isAdminRole(user.role)) {
      return const CompanyAdminDashboard();
    }

    if (user.role == UserRoles.hrExecutive || user.role == UserRoles.hr) {
      return const HRExecutiveDashboard();
    }

    return _buildEmployeeDashboard(
      context: context,
      ref: ref,
      user: user,
      totalEmployees: totalEmployees,
      presentCount: presentCount,
      leavesToday: leavesToday,
      leadsAddedCount: leadsAddedCount,
      ordersInProgress: ordersInProgress,
      activeLeadsCount: activeLeadsCount,
      pendingFollowupsCount: pendingFollowupsCount,
      pendingTasksCount: pendingTasksCount,
      notificationCount: notificationCount,
      attendanceStatusText: attendanceStatusText,
      locationText: locationText,
      isCheckedIn: isCheckedIn,
      isCheckedOut: isCheckedOut,
      elapsed: timerState.elapsed,
      leadsState: leadsState,
      companyAsync: companyAsync,
      attendanceState: attendanceState,
    );
  }
  Widget _buildSaaSHeader({
    required BuildContext context,
    required UserModel user,
    required int notificationCount,
    required String greeting,
    required WidgetRef ref,
  }) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    // Stitch Colors
    const primaryColor = Color(0xFF422CD8);
    const primaryContainerColor = Color(0xFF5B4CF0);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryContainerColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3D422CD8),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 48, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.companyName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$greeting, ${user.name} 👋',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Employee Self Service (ESS) Portal Button
                  IconButton(
                    tooltip: 'Employee Self Service Portal',
                    icon: const Icon(Icons.badge_rounded, color: Colors.white, size: 24),
                    onPressed: () => context.push('/ess'),
                  ),
                  const SizedBox(width: 4),

                  // Enterprise Notification Center Bell
                  const NotificationBellWidget(iconColor: Colors.white, iconSize: 26),
                  const SizedBox(width: 4),

                  // Enterprise Calendar Button
                  IconButton(
                    tooltip: 'Enterprise Calendar',
                    icon: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22),
                    onPressed: () => context.push('/calendar'),
                  ),
                  const SizedBox(width: 4),

                  // App Settings Button
                  IconButton(
                    tooltip: 'App Settings',
                    icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'My Profile & Account',
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (val) async {
                      if (val == 'profile') {
                        if (user.role == UserRoles.employee) {
                          context.push('/ess/profile');
                        } else {
                          context.push('/profile');
                        }
                      } else if (val == 'settings') {
                        context.push('/settings');
                      } else if (val == 'logout') {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const Divider(height: 16),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF5B4CF0)),
                            SizedBox(width: 10),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 20, color: Color(0xFF64748B)),
                            SizedBox(width: 10),
                            Text(
                              'App Settings',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
                            SizedBox(width: 10),
                            Text(
                              'Logout',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: AppUserAvatar(
                      user: user,
                      radius: 18,
                      showBorder: true,
                      borderColor: Colors.white30,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceWidget({
    required BuildContext context,
    required WidgetRef ref,
    required bool isCheckedIn,
    required bool isCheckedOut,
    required String statusText,
    required String location,
    required Duration elapsed,
    required AttendanceState attendanceState,
  }) {
    final todayLog = attendanceState.todayLog;

    final checkInTimeStr = todayLog != null
        ? DateFormat('hh:mm a').format(todayLog.checkInTime)
        : 'N/A';

    final checkOutTimeStr = todayLog?.checkOutTime != null
        ? DateFormat('hh:mm a').format(todayLog!.checkOutTime!)
        : 'N/A';

    String totalWorkingHoursStr = '0h 0m';
    if (todayLog != null && todayLog.checkOutTime != null) {
      final totalWorkingDuration = todayLog.checkOutTime!.difference(todayLog.checkInTime);
      final hours = totalWorkingDuration.inHours;
      final minutes = totalWorkingDuration.inMinutes % 60;
      totalWorkingHoursStr = "${hours}h ${minutes}m";
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B1B24);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: cardBgColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCheckedIn
                        ? (isDark ? const Color(0x2616803D) : const Color(0xFFDCFCE7))
                        : (isCheckedOut
                            ? (isDark ? const Color(0x262563EB) : const Color(0xFFEFF6FF))
                            : (isDark ? const Color(0x26B91C1C) : const Color(0xFFFEF2F2))),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCheckedIn
                        ? Icons.play_arrow_rounded
                        : (isCheckedOut ? Icons.check_rounded : Icons.pause_rounded),
                    color: isCheckedIn
                        ? const Color(0xFF16803D)
                        : (isCheckedOut ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)) : const Color(0xFFB91C1C)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTENDANCE STATUS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: subtitleColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCheckedIn
                            ? 'Checked In'
                            : (isCheckedOut ? 'Checked Out' : 'Not Checked In'),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCheckedIn
                              ? const Color(0xFF16803D)
                              : (isCheckedOut ? titleColor : const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCheckedOut)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x2610B981) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'COMPLETED',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Content Section
            if (isCheckedIn) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'CHECK-IN TIME',
                      value: checkInTimeStr,
                      icon: Icons.login_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'WORKING TIMER',
                      value: "${elapsed.inHours.toString().padLeft(2, '0')}:" +
                          "${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:" +
                          "${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}",
                      icon: Icons.timer_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLocationRow(context, location),
            ] else if (isCheckedOut) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'CHECK-IN TIME',
                      value: checkInTimeStr,
                      icon: Icons.login_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'CHECK-OUT TIME',
                      value: checkOutTimeStr,
                      icon: Icons.logout_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'TOTAL WORKING HOURS',
                      value: totalWorkingHoursStr,
                      icon: Icons.work_history_outlined,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Expanded(
                    child: _buildAttendanceInfoField(
                      context: context,
                      label: 'GPS AT CHECK-OUT',
                      value: todayLog?.checkoutAddress ?? todayLog?.address ?? 'N/A',
                      icon: Icons.location_on_outlined,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildLocationRow(context, "Location will be captured on check-in"),
            ],

            // Action Buttons
            if (!isCheckedOut) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!isCheckedIn)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleDashboardCheckIn(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text('CHECK IN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', letterSpacing: 0.5)),
                      ),
                    ),
                  if (isCheckedIn)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ref.read(attendanceProvider.notifier).checkOutUser();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBA1A1A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text('CHECK OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', letterSpacing: 0.5)),
                      ),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16803D), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Shift completed. Have a great day!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF16803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceInfoField({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, String address) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT GPS LOCATION',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMonthSummary({
    required BuildContext context,
    required List<AttendanceModel> logs,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final thisMonthLogs = logs.where((l) =>
        l.checkInTime.year == now.year && l.checkInTime.month == now.month).toList();

    final presentDays = thisMonthLogs.where((l) => l.status.toLowerCase() == 'present').length;
    final lateDays = thisMonthLogs.where((l) => l.status.toLowerCase() == 'late').length;
    final absentDays = thisMonthLogs.where((l) => l.status.toLowerCase() == 'absent' || l.status.toLowerCase() == 'half day').length;

    double totalMinutes = 0;
    for (final l in thisMonthLogs) {
      if (l.checkOutTime != null) {
        totalMinutes += l.checkOutTime!.difference(l.checkInTime).inMinutes;
      }
    }
    final totalHours = (totalMinutes / 60).round();

    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final List<Map<String, dynamic>> items = [
      {'title': 'Present Days', 'value': '$presentDays', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Late Days', 'value': '$lateDays', 'icon': Icons.access_time_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Absent Days', 'value': '$absentDays', 'icon': Icons.cancel_rounded, 'color': const Color(0xFFEF4444)},
      {'title': 'Hours Worked', 'value': '${totalHours}h', 'icon': Icons.work_history_rounded, 'color': const Color(0xFF5B4CF0)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance This Month',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final item = items[idx];
                final color = item['color'] as Color;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: color, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item['value'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceHistorySection({
    required BuildContext context,
    required List<AttendanceModel> logs,
    required PermissionService permService,
    required bool isDark,
  }) {
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final displayLogs = logs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Attendance History',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            if (permService.hasPermission('attendance_view'))
              TextButton(
                onPressed: () => context.push('/attendance'),
                child: const Text('View Attendance', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (displayLogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 10),
                Text(
                  'No attendance records available yet.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final log = displayLogs[idx];

              final checkInStr = DateFormat('hh:mm a').format(log.checkInTime);
              final checkOutStr = log.checkOutTime != null
                  ? DateFormat('hh:mm a').format(log.checkOutTime!)
                  : 'Active';

              String durationStr = 'In Progress';
              if (log.checkOutTime != null) {
                final diff = log.checkOutTime!.difference(log.checkInTime);
                final hours = diff.inHours;
                final mins = diff.inMinutes % 60;
                durationStr = '${hours}h ${mins}m';
              }

              Color statusColor;
              switch (log.status.toLowerCase()) {
                case 'present':
                  statusColor = const Color(0xFF10B981);
                  break;
                case 'late':
                  statusColor = const Color(0xFFF59E0B);
                  break;
                case 'absent':
                case 'half day':
                  statusColor = const Color(0xFFEF4444);
                  break;
                default:
                  statusColor = const Color(0xFF5B4CF0);
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.fingerprint_rounded, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(log.checkInTime),
                            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'In: $checkInStr  •  Out: $checkOutStr',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          if (log.address != null && log.address!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '📍 ${log.address}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.status.toUpperCase(),
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          durationStr,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSaaSTodaySummary({
    required BuildContext context,
    required int presentEmployees,
    required int employeesOnLeave,
    required int activeLeads,
    required int pendingOrders,
    required int pendingFollowups,
    bool showLeads = true,
  }) {
    final List<Map<String, dynamic>> items = [
      {'title': 'Present Today', 'value': '$presentEmployees', 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'On Leave', 'value': '$employeesOnLeave', 'icon': Icons.time_to_leave_rounded, 'color': const Color(0xFFEF4444)},
      if (showLeads)
        {'title': 'Active Leads', 'value': '$activeLeads', 'icon': Icons.person_search_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': 'Pending Orders', 'value': '$pendingOrders', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFFF59E0B)},
      if (showLeads)
        {'title': 'Pending Follow Ups', 'value': '$pendingFollowups', 'icon': Icons.phone_callback_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B1B24);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Summary",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final item = items[idx];
              final color = item['color'] as Color;

              return Container(
                width: 105,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData, color: color, size: 16),
                    ),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductivityInsightCard() {
    const primaryContainerColor = Color(0xFF5B4CF0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryContainerColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryContainerColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.trending_up_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Productivity Insight',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your team has reached 94% of their target this week. Keep up the momentum!',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaaSQuickActions(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'title': 'Add Employee', 'icon': Icons.person_add_rounded, 'color': const Color(0xFF6366F1), 'route': '/company-admin/employees'},
      {'title': 'Company Profile', 'icon': Icons.business_rounded, 'color': const Color(0xFF10B981), 'route': '/company-profile'},
      {'title': 'Attendance Rules', 'icon': Icons.settings_rounded, 'color': const Color(0xFF3B82F6), 'route': '/company-admin/attendance-rules'},
      {'title': 'Leave Policy', 'icon': Icons.time_to_leave_rounded, 'color': const Color(0xFFF59E0B), 'route': '/company-admin/leave-policy'},
      {'title': 'Payroll', 'icon': Icons.payments_rounded, 'color': const Color(0xFFEC4899), 'route': '/company-admin/payroll'},
      {'title': 'HR', 'icon': Icons.badge_rounded, 'color': const Color(0xFF06B6D4), 'route': '/company-admin/hr'},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF334155);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: isMobile ? 0.95 : 1.1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, idx) {
            final item = items[idx];
            final color = item['color'] as Color;

            return Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(item['route'] as String),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, String userRole) {
    final List<Map<String, dynamic>> actions;
    if (userRole == 'Super Admin') {
      actions = [
        {'title': 'Companies', 'icon': Icons.business_rounded, 'color': const Color(0xFF818CF8), 'route': '/company-profile'},
        {'title': 'Plans & Pricing', 'icon': Icons.credit_card_rounded, 'color': const Color(0xFF10B981), 'route': '/subscription'},
        {'title': 'Employees', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFFEC4899), 'route': '/employees'},
        {'title': 'Customers', 'icon': Icons.emoji_people_rounded, 'color': const Color(0xFF14B8A6), 'route': '/customers'},
        {'title': 'Settings', 'icon': Icons.settings_rounded, 'color': const Color(0xFF6366F1), 'route': '/settings'},
        {'title': 'More', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFF64748B), 'route': '/main?tab=4'},
      ];
    } else if (userRole == UserRoles.employee) {
      actions = [
        {'title': 'Attendance', 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFF3B82F6), 'route': '/ess/attendance'},
        {'title': 'My Payslips', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF10B981), 'route': '/ess/payslips'},
        {'title': 'Notifications', 'icon': Icons.notifications_active_rounded, 'color': const Color(0xFFF59E0B), 'route': '/notifications'},
        {'title': 'My Profile', 'icon': Icons.person_rounded, 'color': const Color(0xFF818CF8), 'route': '/ess/profile'},
      ];
    } else {
      final canRecordAttendance = UserRoles.allowsPersonalAttendance(userRole);
      actions = [
        {'title': 'Add Lead', 'icon': Icons.person_add_alt_1_rounded, 'color': const Color(0xFF818CF8), 'route': '/lead-form'},
        {'title': 'Employees', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF10B981), 'route': '/employees'},
        if (canRecordAttendance)
          {'title': 'Attendance', 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFF3B82F6), 'route': '/attendance'}
        else
          {'title': 'Calendar', 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFF3B82F6), 'route': '/calendar'},
        {'title': 'Expenses', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF14B8A6), 'route': '/expenses'},
        {'title': 'Tasks', 'icon': Icons.playlist_add_check_rounded, 'color': const Color(0xFF6366F1), 'route': '/tasks'},
        {'title': 'More', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFF64748B), 'route': '/main?tab=4'},
      ];
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF475569);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: isMobile ? 0.95 : 1.1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: actions.length,
          itemBuilder: (context, idx) {
            final act = actions[idx];
            final color = act['color'] as Color;

            return Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final route = act['route'] as String;
                    if (route.isNotEmpty) {
                      if (route.contains('?tab=')) {
                        context.go(route);
                      } else {
                        context.push(route);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${act['title']} is available in the bottom center "+" action menu.')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(act['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(
                              act['title'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeadItemCard(BuildContext context, LeadModel lead) {
    Color badgeColor;
    Color textColor;
    switch (lead.status) {
      case 'New':
        badgeColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        break;
      case 'Follow Up':
        badgeColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF1D4ED8);
        break;
      case 'Quotation Sent':
        badgeColor = const Color(0xFFFAF5FF);
        textColor = const Color(0xFF7E22CE);
        break;
      case 'Converted':
        badgeColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF047857);
        break;
      case 'Closed':
        badgeColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFB91C1C);
        break;
      default:
        badgeColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cardBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () => context.push('/lead-detail/${lead.leadId}', extra: lead),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Text(
                  lead.customerName.substring(0, lead.customerName.contains(' ') ? 2 : 1).toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13, fontFamily: 'Inter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.customerName,
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.requirement,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lead.assignedTo} • ${DateFormat('hh:mm a').format(lead.createdAt)}',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      lead.status,
                      style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionDashboardWidget(BuildContext context, CompanyModel company) {
    final isPending = company.billingStatus.toLowerCase() == 'pending';
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);
    
    final freeLimit = company.freeEmployeeLimit;
    final activeCount = company.activeEmployees;
    final remaining = (freeLimit - activeCount).clamp(0, 999999);

    final nextBillingText = company.nextBillingDate != null 
        ? DateFormat('dd MMM yyyy').format(company.nextBillingDate!)
        : 'N/A';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Subscription: ${company.planName}',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.amber.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPending ? 'Pending Payment' : 'Paid',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: isPending ? Colors.amber.shade900 : Colors.green.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Bill', style: TextStyle(fontFamily: 'Inter', color: subtitleColor, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(formatCurrency.format(company.monthlyBill), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Employees', style: TextStyle(fontFamily: 'Inter', color: subtitleColor, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$activeCount / $freeLimit free', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: subtitleColor),
                    const SizedBox(width: 4),
                    Text(
                      remaining > 0 
                          ? '$remaining free slots remaining' 
                          : 'Due: $nextBillingText',
                      style: TextStyle(fontFamily: 'Inter', color: subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/subscription'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Manage Billing', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDashboardCheckIn(BuildContext context, WidgetRef ref) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable GPS/Location in settings.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable them in system settings.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching current GPS coordinates...'),
          duration: Duration(seconds: 1),
        ),
      );

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String address = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            final parts = [
              if (place.name != null && place.name!.isNotEmpty && place.name != place.street) place.name,
              if (place.street != null && place.street!.isNotEmpty) place.street,
              if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
              if (place.locality != null && place.locality!.isNotEmpty) place.locality,
              if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
              if (place.postalCode != null && place.postalCode!.isNotEmpty) place.postalCode,
            ];
            address = parts.join(', ');
          }
        } catch (e) {
          debugPrint('Geocoding failed: $e');
        }
      }

      await ref.read(attendanceProvider.notifier).checkInUser(
        position.latitude,
        position.longitude,
        address,
      );
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text('Attendance Punch Failed', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to complete attendance punch due to a technical/GPS issue.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can retry the punch or submit an Attendance Override Request for supervisor review.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleDashboardCheckIn(context, ref);
                },
                child: const Text('Retry Punch'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/ess/attendance');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4CF0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Request Override'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildAdminDashboard({
    required BuildContext context,
    required WidgetRef ref,
    required UserModel user,
    required int totalEmployees,
    required int presentCount,
    required int leavesToday,
    required int activeLeadsCount,
    required int ordersInProgress,
    required int pendingFollowupsCount,
    required int notificationCount,
    required AsyncValue<CompanyModel?> companyAsync,
    required AsyncValue<List<LeadModel>> leadsState,
    required AsyncValue<List<UserModel>> employeesAsync,
    required AsyncValue<List<AttendanceModel>> attendanceTodayAsync,
    required AsyncValue<List<OrderModel>> ordersState,
    required bool isCheckedIn,
    required bool isCheckedOut,
    required String attendanceStatusText,
    required String locationText,
    required Duration elapsed,
    required AttendanceState attendanceState,
  }) {
    final List<RecentActivity> activities = [];

    // 1. Employee Check In
    final attendanceToday = attendanceTodayAsync.value ?? [];
    for (final log in attendanceToday) {
      activities.add(RecentActivity(
        title: 'Employee Check In',
        description: '${log.employeeName} checked in',
        time: log.checkInTime,
        icon: Icons.login_rounded,
        color: const Color(0xFF10B981),
      ));
    }

    // 3. Follow Up Scheduled
    final leads = leadsState.value ?? [];
    final followups = ref.watch(followupsProvider).value ?? [];
    for (final followup in followups) {
      final lead = leads.firstWhere(
        (l) => l.leadId == followup.leadId,
        orElse: () => LeadModel(
          leadId: '',
          companyId: '',
          customerName: 'Unknown Customer',
          mobileNumber: '',
          companyName: '',
          location: '',
          requirement: '',
          leadSource: 'Direct',
          assignedTo: 'Unknown',
          assignedToId: '',
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      activities.add(RecentActivity(
        title: 'Follow Up Scheduled',
        description: 'Follow-up with ${lead.customerName}: ${followup.remarks}',
        time: followup.createdAt,
        icon: Icons.phone_callback_rounded,
        color: const Color(0xFF8B5CF6),
      ));
    }

    // 4. Order Created
    final orders = ordersState.value ?? [];
    for (final order in orders) {
      activities.add(RecentActivity(
        title: 'Order Created',
        description: 'New order created for ${order.customerName}',
        time: order.createdAt,
        icon: Icons.shopping_bag_rounded,
        color: const Color(0xFFF59E0B),
      ));
    }

    // 5. Payroll Processed
    final payrollState = ref.watch(payrollProvider);
    final payrolls = payrollState.payrolls;
    for (final payroll in payrolls) {
      activities.add(RecentActivity(
        title: 'Payroll Processed',
        description: 'Payroll for ${payroll.employeeName}: ${payroll.status}',
        time: payroll.generatedAt,
        icon: Icons.payments_rounded,
        color: const Color(0xFFEC4899),
      ));
    }

    activities.sort((a, b) => b.time.compareTo(a.time));
    final displayActivities = activities.take(5).toList();

    final employeeHRItems = [
      {
        'title': 'Employee Management',
        'icon': Icons.people_alt_rounded,
        'route': '/company-admin/employees',
      },
      {
        'title': 'HR Management',
        'icon': Icons.badge_rounded,
        'route': '/company-admin/hr',
      },
      {
        'title': 'Employee Documents',
        'icon': Icons.folder_shared_rounded,
        'action': (BuildContext ctx, UserModel u) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (context) => const EmployeeDocumentsScreen(),
            ),
          );
        },
      },
      {
        'title': 'Employee Profile',
        'icon': Icons.account_box_rounded,
        'action': (BuildContext ctx, UserModel u) {
          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (context) => EmployeeProfileScreen(employee: u),
            ),
          );
        },
      },
    ];

    final companyAdminItems = [
      {
        'title': 'Company Profile',
        'icon': Icons.business_rounded,
        'route': '/company-profile',
      },
      {
        'title': 'Department Management',
        'icon': Icons.corporate_fare_rounded,
        'route': '/company-admin/departments',
      },
      {
        'title': 'Designation Management',
        'icon': Icons.badge_rounded,
        'route': '/company-admin/designations',
      },
      {
        'title': 'Role & Permissions',
        'icon': Icons.security_rounded,
        'route': '/company-admin/permissions',
      },
      {
        'title': 'Subscription',
        'icon': Icons.credit_card_rounded,
        'route': '/subscription',
      },
      {
        'title': 'Branch Management',
        'icon': Icons.store_mall_directory_rounded,
        'route': '/company-admin/branches',
      },
    ];

    final attendanceLeaveItems = [
      {
        'title': 'Attendance Settings',
        'icon': Icons.settings_rounded,
        'route': '/company-admin/attendance-rules',
      },
      {
        'title': 'Shift Management',
        'icon': Icons.schedule_rounded,
        'route': '/company-admin/shifts',
      },
      {
        'title': 'Holiday Management',
        'icon': Icons.beach_access_rounded,
        'route': '/company-admin/holidays',
      },
      {
        'title': 'Leave Policies',
        'icon': Icons.time_to_leave_rounded,
        'route': '/company-admin/leave-policy',
      },
      {
        'title': 'Overtime Settings',
        'icon': Icons.more_time_rounded,
        'route': '/company-admin/overtime',
      },
      {
        'title': 'Override Approvals',
        'icon': Icons.assignment_turned_in_rounded,
        'route': '/company-admin/approvals',
      },
    ];

    final payrollItems = [
      {
        'title': 'Payroll Processing',
        'icon': Icons.payments_rounded,
        'route': '/company-admin/payroll',
      },
      /*
      {
        'title': 'Payroll Settings',
        'icon': Icons.settings_suggest_rounded,
        'route': '/company-admin/payroll-settings',
      },
      */
      {
        'title': 'Salary Structures',
        'icon': Icons.account_tree_rounded,
        'route': '/company-admin/salary-structures',
      },
      /*
      {
        'title': 'Salary Components',
        'icon': Icons.list_rounded,
        'route': '/company-admin/salary-components',
      },
      */
      {
        'title': 'Salary Payroll',
        'icon': Icons.wallet_rounded,
        'route': '/company-admin/salary-payroll',
      },
      {
        'title': 'Salary Payslips',
        'icon': Icons.receipt_long_rounded,
        'route': '/company-admin/salary-payroll',
      },
      {
        'title': 'PF / ESI / Tax',
        'icon': Icons.percent_rounded,
        'route': '/company-admin/pf-esi-tax',
      },
    ];



    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFFCF8FF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildSaaSHeader(
              context: context,
              user: user,
              notificationCount: notificationCount,
              greeting: getGreeting(),
              ref: ref,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (companyAsync.value != null && !(companyAsync.value!.isSetupCompleted)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B4CF0), Color(0xFF7C72F4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B4CF0).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Company Setup Wizard',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure branches, departments, shifts, and holidays to get started with WorkTrack SaaS.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF5B4CF0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OnboardingWizardScreen(),
                                ),
                              );
                            },
                            child: const Text('Start Setup Wizard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _buildSaaSTodaySummary(
                  context: context,
                  presentEmployees: presentCount,
                  employeesOnLeave: leavesToday,
                  activeLeads: activeLeadsCount,
                  pendingOrders: ordersInProgress,
                  pendingFollowups: pendingFollowupsCount,
                  showLeads: false,
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick Actions',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildSaaSQuickActions(context),
                const SizedBox(height: 16),
                Text(
                  'Management Console',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildExpandableSection(
                  title: 'Employee & HR',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF6366F1),
                  items: employeeHRItems,
                  context: context,
                  user: user,
                ),
                _buildExpandableSection(
                  title: 'Company Administration',
                  icon: Icons.business_rounded,
                  color: const Color(0xFF3B82F6),
                  items: companyAdminItems,
                  context: context,
                  user: user,
                ),
                _buildExpandableSection(
                  title: 'Attendance & Leave',
                  icon: Icons.fingerprint_rounded,
                  color: const Color(0xFF10B981),
                  items: attendanceLeaveItems,
                  context: context,
                  user: user,
                ),
                _buildExpandableSection(
                  title: 'Payroll',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFEC4899),
                  items: payrollItems,
                  context: context,
                  user: user,
                ),
                const SizedBox(height: 16),
                Text(
                  'Recent Activity Timeline',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildSaaSActivityTimeline(context, displayActivities),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required BuildContext context,
    required UserModel user,
  }) {
    const bool showBranchManagement = false;
    final filteredItems = items.where((item) {
      if (item['title'] == 'Branch Management' && !showBranchManagement) {
        return false;
      }
      return true;
    }).toList();

    if (filteredItems.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final itemBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final itemTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
      color: cardBgColor,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          backgroundColor: cardBgColor,
          collapsedBackgroundColor: cardBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: titleColor,
            ),
          ),
          iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          collapsedIconColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Divider(color: borderColor, height: 1, thickness: 1),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, idx) {
                final item = filteredItems[idx];
                return InkWell(
                  onTap: () {
                    if (item['action'] != null) {
                      (item['action'] as Function(BuildContext, UserModel))(context, user);
                    } else if (item['route'] != null) {
                      context.push(item['route'] as String);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: itemBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData? ?? Icons.circle_outlined,
                          color: color,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: itemTextColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaaSActivityTimeline(BuildContext context, List<RecentActivity> activities) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            'No recent activities recorded.',
            style: TextStyle(fontFamily: 'Inter', color: subtitleColor, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        itemBuilder: (context, idx) {
          final act = activities[idx];
          final isLast = idx == activities.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: act.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act.icon, color: act.color, size: 16),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: borderColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              act.title,
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                            ),
                            Text(
                              _formatRelativeTime(act.time),
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          act.description,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: subtitleColor, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dateTime);
  }

  Widget _buildEmployeeDashboard({
    required BuildContext context,
    required WidgetRef ref,
    required UserModel user,
    required int totalEmployees,
    required int presentCount,
    required int leavesToday,
    required int leadsAddedCount,
    required int ordersInProgress,
    required int activeLeadsCount,
    required int pendingFollowupsCount,
    required int pendingTasksCount,
    required int notificationCount,
    required String attendanceStatusText,
    required String locationText,
    required bool isCheckedIn,
    required bool isCheckedOut,
    required Duration elapsed,
    required AsyncValue<List<LeadModel>> leadsState,
    required AsyncValue<CompanyModel?> companyAsync,
    required AttendanceState attendanceState,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD);

    final permService = ref.watch(permissionServiceProvider);

    // 1. Employee-specific Tasks
    final tasksState = ref.watch(tasksProvider);
    final allTasks = tasksState.value ?? [];
    final myTasks = allTasks.where((t) => t.assignedToId == user.uid).toList();
    final myPendingTasks = myTasks.where((t) => t.status != 'Completed').toList();
    final myCompletedTasks = myTasks.where((t) => t.status == 'Completed').toList();

    // 2. Employee-specific Follow-ups
    final followupsState = ref.watch(followupsProvider);
    final allFollowups = followupsState.value ?? [];
    final myFollowups = allFollowups.where((f) => f.assignedUserId == user.uid).toList();

    // 3. Employee-specific Targeted Notifications
    final notificationsState = ref.watch(notificationsProvider);
    final myNotifications = notificationsState.value ?? [];

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildEmployeeHeader(
              context: context,
              user: user,
              greeting: getGreeting(),
              ref: ref,
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Today's Attendance Overview & Check In / Check Out Area
                _buildAttendanceWidget(
                  context: context,
                  ref: ref,
                  isCheckedIn: isCheckedIn,
                  isCheckedOut: isCheckedOut,
                  statusText: attendanceStatusText,
                  location: locationText,
                  elapsed: elapsed,
                  attendanceState: attendanceState,
                ),

                const SizedBox(height: 24),

                // 2. Attendance Summary This Month
                _buildAttendanceMonthSummary(
                  context: context,
                  logs: attendanceState.logs,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 3. Recent Attendance History
                _buildAttendanceHistorySection(
                  context: context,
                  logs: attendanceState.logs,
                  permService: permService,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 5. Quick Actions
                _buildEmployeeQuickActions(
                  context: context,
                  permService: permService,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 6. My Tasks Section
                _buildMyTasksSection(
                  context: context,
                  myPendingTasks: myPendingTasks,
                  permService: permService,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 7. My Recent Activity
                _buildEmployeeRecentActivitySection(
                  context: context,
                  myTasks: myTasks,
                  myFollowups: myFollowups,
                  myNotifications: myNotifications,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // 8. Compact Employee Profile Summary Card
                _buildEmployeeProfileCard(
                  context: context,
                  user: user,
                  isDark: isDark,
                ),

                const SizedBox(height: 60),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader({
    required BuildContext context,
    required UserModel user,
    required String greeting,
    required WidgetRef ref,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF422CD8), Color(0xFF5B4CF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3D422CD8),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, ${user.name} 👋',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Here's your work overview for today.",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const NotificationBellWidget(iconColor: Colors.white, iconSize: 24),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'My Profile & Account',
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (val) async {
                      if (val == 'profile') {
                        context.push('/profile');
                      } else if (val == 'settings') {
                        context.push('/settings');
                      } else if (val == 'logout') {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const Divider(height: 16),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF5B4CF0)),
                            SizedBox(width: 10),
                            Text(
                              'View Profile',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 20, color: Color(0xFF64748B)),
                            SizedBox(width: 10),
                            Text(
                              'App Settings',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
                            SizedBox(width: 10),
                            Text(
                              'Logout',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: AppUserAvatar(
                      user: user,
                      radius: 18,
                      showBorder: true,
                      borderColor: Colors.white30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSummaryCards({
    required BuildContext context,
    required int totalTasks,
    required int pendingTasks,
    required int completedTasks,
    required int followupsCount,
    required PermissionService permService,
    required bool isDark,
  }) {
    final List<Map<String, dynamic>> cards = [];

    if (permService.hasPermission('task_view')) {
      cards.add({
        'title': 'My Tasks',
        'value': '$totalTasks',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFF5B4CF0),
        'route': '/tasks',
      });
      cards.add({
        'title': 'Pending Tasks',
        'value': '$pendingTasks',
        'icon': Icons.pending_actions_rounded,
        'color': const Color(0xFFF59E0B),
        'route': '/tasks',
      });
      cards.add({
        'title': 'Completed',
        'value': '$completedTasks',
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFF10B981),
        'route': '/tasks',
      });
    }

    if (permService.hasPermission('followup_view')) {
      cards.add({
        'title': 'Follow-ups',
        'value': '$followupsCount',
        'icon': Icons.phone_callback_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': '/followups',
      });
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: cards.length,
          itemBuilder: (context, idx) {
            final c = cards[idx];
            final color = c['color'] as Color;

            return InkWell(
              onTap: () => context.push(c['route'] as String),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : const Color(0xFF111827).withOpacity(0.03),
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
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(c['icon'] as IconData, color: color, size: 16),
                        ),
                        Text(
                          c['value'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      c['title'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeQuickActions({
    required BuildContext context,
    required PermissionService permService,
    required bool isDark,
  }) {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'Attendance',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF5B4CF0),
        'route': '/main?tab=1',
      },
      {
        'title': 'My Payslips',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF10B981),
        'route': '/main?tab=2',
      },
      {
        'title': 'Notifications',
        'icon': Icons.notifications_rounded,
        'color': const Color(0xFFF59E0B),
        'route': '/main?tab=3',
      },
      {
        'title': 'My Profile',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': '/profile',
      },
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: isMobile ? 0.92 : 1.15,
              ),
              itemCount: actions.length,
              itemBuilder: (context, idx) {
                final act = actions[idx];
                final color = act['color'] as Color;

                return InkWell(
                  onTap: () => context.push(act['route'] as String),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(act['icon'] as IconData, color: color, size: 18),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(
                              act['title'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF334155),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMyTasksSection({
    required BuildContext context,
    required List<TaskModel> myPendingTasks,
    required PermissionService permService,
    required bool isDark,
  }) {
    if (!permService.hasPermission('task_view')) return const SizedBox.shrink();

    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final displayTasks = myPendingTasks.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Assigned Tasks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/tasks'),
              child: const Text('View All', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (displayTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                const Icon(Icons.task_alt_rounded, size: 36, color: Color(0xFF10B981)),
                const SizedBox(height: 10),
                Text(
                  'No tasks assigned',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  "You're all caught up. New tasks assigned to you will appear here.",
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final task = displayTasks[idx];

              Color statusColor;
              switch (task.status.toLowerCase()) {
                case 'completed':
                  statusColor = const Color(0xFF10B981);
                  break;
                case 'in progress':
                  statusColor = const Color(0xFF2563EB);
                  break;
                default:
                  statusColor = const Color(0xFFF59E0B);
              }

              return InkWell(
                onTap: () => context.push('/task-detail/${task.taskId}', extra: task),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.assignment_rounded, color: statusColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                task.description,
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.status.toUpperCase(),
                          style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmployeeRecentActivitySection({
    required BuildContext context,
    required List<TaskModel> myTasks,
    required List<FollowupModel> myFollowups,
    required List<AppNotificationModel> myNotifications,
    required bool isDark,
  }) {
    final List<RecentActivity> activities = [];

    // My Tasks Activity
    for (final t in myTasks) {
      activities.add(RecentActivity(
        title: t.status == 'Completed' ? 'Task Completed' : 'Task Assigned',
        description: t.title,
        time: t.createdAt,
        icon: t.status == 'Completed' ? Icons.task_alt_rounded : Icons.assignment_outlined,
        color: t.status == 'Completed' ? const Color(0xFF10B981) : const Color(0xFF5B4CF0),
      ));
    }

    // My Followups Activity
    for (final f in myFollowups) {
      activities.add(RecentActivity(
        title: f.status == 'Completed' ? 'Follow-up Completed' : 'Follow-up Scheduled',
        description: f.remarks,
        time: f.createdAt,
        icon: Icons.phone_callback_rounded,
        color: const Color(0xFF8B5CF6),
      ));
    }

    // My Personal / Announcement Notifications
    for (final n in myNotifications) {
      if (n.targetType.toUpperCase() == 'USER' || n.targetType.toUpperCase() == 'COMPANY') {
        activities.add(RecentActivity(
          title: n.title,
          description: n.body,
          time: n.createdAt,
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFF59E0B),
        ));
      }
    }

    activities.sort((a, b) => b.time.compareTo(a.time));
    final displayActivities = activities.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Recent Work & Activity',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        _buildSaaSActivityTimeline(context, displayActivities),
      ],
    );
  }

  Widget _buildEmployeeProfileCard({
    required BuildContext context,
    required UserModel user,
    required bool isDark,
  }) {
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          AppUserAvatar(user: user, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${user.employeeId ?? "N/A"} • ${user.designation ?? user.role}',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  user.companyEmail ?? user.email,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5B4CF0), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0).withOpacity(0.1),
              foregroundColor: const Color(0xFF5B4CF0),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('View Profile', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class RecentActivity {
  final String title;
  final String description;
  final DateTime time;
  final IconData icon;
  final Color color;

  const RecentActivity({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });
}
