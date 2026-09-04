import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../constants/user_roles.dart';

class ESSAttendanceScreen extends ConsumerStatefulWidget {
  const ESSAttendanceScreen({super.key});

  @override
  ConsumerState<ESSAttendanceScreen> createState() => _ESSAttendanceScreenState();
}

class _ESSAttendanceScreenState extends ConsumerState<ESSAttendanceScreen> {
  void _showRegularizationDialog(
    BuildContext context, {
    String initialRequestType = 'Forgot Check-in',
    DateTime? initialDate,
    String? initialReason,
  }) {
    final formKey = GlobalKey<FormState>();
    String requestType = initialRequestType;
    DateTime selectedDate = initialDate ?? DateTime.now();
    final reasonCtrl = TextEditingController(text: initialReason ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Color(0xFF5B4CF0)),
              SizedBox(width: 8),
              Text('Attendance Regularization', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submit a request to correct or record a missed attendance entry.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                
                // Request Type Dropdown
                DropdownButtonFormField<String>(
                  value: requestType,
                  decoration: const InputDecoration(
                    labelText: 'Request Type *',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Forgot Check-in', child: Text('Forgot Check-in')),
                    DropdownMenuItem(value: 'Forgot Check-out', child: Text('Forgot Check-out')),
                    DropdownMenuItem(value: 'System Error', child: Text('System / Technical Error')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => requestType = val);
                  },
                ),
                const SizedBox(height: 12),

                // Date Selector
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: const Icon(Icons.calendar_today_rounded, color: Color(0xFF5B4CF0), size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 60)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Reason / Description Field
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Explanation *',
                    hintText: 'Describe why attendance was missed or incorrect...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = ref.read(authProvider).user;
                if (user == null) return;

                final reqId = const Uuid().v4();
                final now = DateTime.now();

                final reqData = {
                  'requestId': reqId,
                  'companyId': user.companyId,
                  'employeeId': user.uid,
                  'employeeName': user.name,
                  'employeeCode': user.displayEmployeeId,
                  'requestType': requestType,
                  'targetDate': Timestamp.fromDate(selectedDate),
                  'reason': reasonCtrl.text.trim(),
                  'status': 'Pending',
                  'createdAt': Timestamp.fromDate(now),
                };

                await FirebaseFirestore.instance.collection('attendance_corrections').doc(reqId).set(reqData);

                // Route notifications strictly to configured recipients (HR, Reporting Manager, Team Leader, Admin)
                final recipients = user.attendanceNotificationRecipients;
                final Set<String> notifiedUserIds = {user.uid};

                if (recipients.isNotEmpty) {
                  final userSnap = await FirebaseFirestore.instance
                      .collection('users')
                      .where('companyId', isEqualTo: user.companyId)
                      .where('status', isEqualTo: 'active')
                      .get();

                  final allUsers = userSnap.docs.map((d) => UserModel.fromMap(d.data())).toList();

                  for (final recipientRole in recipients) {
                    final targetUsers = allUsers.where((u) {
                      if (notifiedUserIds.contains(u.uid)) return false;
                      final r = u.role.toLowerCase();
                      if (recipientRole == 'hr' && (r.contains('hr') || r == 'hr')) return true;
                      if (recipientRole == 'reporting_manager' && (u.uid == user.managerId || r == 'manager')) return true;
                      if (recipientRole == 'team_leader' && (r.contains('team') || r == 'team_leader')) return true;
                      if (recipientRole == 'company_admin' && r == 'company_admin') return true;
                      return false;
                    });

                    for (final target in targetUsers) {
                      notifiedUserIds.add(target.uid);
                      final notifId = const Uuid().v4();
                      final notif = AppNotificationModel(
                        notificationId: notifId,
                        companyId: user.companyId,
                        title: 'Attendance Regularization Request',
                        body: '${user.name} (${user.displayEmployeeId}) submitted a $requestType regularization request for ${DateFormat('dd MMM yyyy').format(selectedDate)}.',
                        notificationType: 'ATTENDANCE_CORRECTION',
                        isRead: false,
                        createdAt: now,
                        targetType: 'USER',
                        targetUserId: target.uid,
                        actorUserId: user.uid,
                        actorName: user.name,
                        relatedModule: 'ATTENDANCE',
                      );

                      await FirebaseFirestore.instance.collection('notifications').doc(notifId).set(notif.toMap());
                    }
                  }
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attendance regularization request submitted successfully for manager review.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            tooltip: 'Request Regularization',
            icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
            onPressed: () => _showRegularizationDialog(context),
          ),
        ],
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
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRegularizationDialog(context),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                      label: const Text('Request Regularization / Missed Check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5B4CF0),
                        side: const BorderSide(color: Color(0xFF5B4CF0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
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
            const SizedBox(height: 20),

            // Attendance Logs History
            Text('ATTENDANCE HISTORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 12),
            if (historyLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_available_rounded, size: 36, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No attendance records found yet.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: historyLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final log = historyLogs[idx];
                  final checkInStr = DateFormat('hh:mm a').format(log.checkInTime);
                  final checkOutStr = log.checkOutTime != null ? DateFormat('hh:mm a').format(log.checkOutTime!) : 'N/A';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy (EEEE)').format(log.checkInTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('In: $checkInStr  •  Out: $checkOutStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(log.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ),
                      ],
                    ),
                  );
                },
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
