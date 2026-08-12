import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';

class ESSAttendanceScreen extends ConsumerWidget {
  const ESSAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceState = ref.watch(attendanceProvider);
    final todayLog = attendanceState.todayLog;
    final historyLogs = attendanceState.logs;

    final leaves = ref.watch(leavesProvider).value ?? [];
    final approvedLeavesCount = leaves.where((l) => l.status == 'Approved').length;

    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now).toUpperCase();

    final isCheckedIn = todayLog != null;
    final isCheckedOut = todayLog != null && todayLog.checkOutTime != null;

    String checkInText = isCheckedIn ? DateFormat('hh:mm a').format(todayLog.checkInTime) : '--:--';
    String checkOutText = isCheckedOut ? DateFormat('hh:mm a').format(todayLog.checkOutTime!) : (isCheckedIn ? 'Checked In' : '--:--');

    String statusText = 'NOT CHECKED IN';
    Color statusColor = Colors.orange;
    if (isCheckedOut) {
      statusText = 'COMPLETED';
      statusColor = const Color(0xFF10B981);
    } else if (isCheckedIn) {
      statusText = 'PRESENT (WORKING)';
      statusColor = const Color(0xFF10B981);
    }

    String workingDuration = '--';
    if (isCheckedIn) {
      final endTime = todayLog.checkOutTime ?? now;
      final duration = endTime.difference(todayLog.checkInTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      workingDuration = '${hours}h ${minutes}m';
    }

    final thisMonthLogs = historyLogs.where((log) => log.checkInTime.year == now.year && log.checkInTime.month == now.month).toList();
    final presentDaysCount = thisMonthLogs.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'My Attendance & Timesheet',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Status Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TODAY'S WORK LOG", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Check-in Time: $checkInText', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Check-out Time: $checkOutText', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Working Duration: $workingDuration', style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold)),
                      Text(todayLog?.address != null ? 'GPS: Verified' : 'Location Pending', style: TextStyle(color: todayLog?.address != null ? const Color(0xFF10B981) : Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Monthly Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$monthName SUMMARY', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Present Days', '$presentDaysCount', Colors.green),
                      _buildSummaryStat('Approved Leaves', '$approvedLeavesCount', Colors.amber),
                      _buildSummaryStat('Total Logs', '${thisMonthLogs.length}', const Color(0xFF5B4CF0)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, fontFamily: 'Outfit')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
