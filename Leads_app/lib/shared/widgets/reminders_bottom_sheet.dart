import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/app_notification_model.dart';
import '../../constants/user_roles.dart';

class RemindersBottomSheet extends ConsumerWidget {
  const RemindersBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followups = ref.watch(followupsProvider).value ?? [];
    final tasks = ref.watch(tasksProvider).value ?? [];
    final currentUser = ref.watch(authProvider).user;

    final today = DateTime.now();
    final todayFollowups = followups.where((f) =>
        f.status == 'Upcoming' &&
        f.followUpDate.year == today.year &&
        f.followUpDate.month == today.month &&
        f.followUpDate.day == today.day
    ).toList();

    final missedFollowups = followups.where((f) => f.status == 'Missed').toList();

    final myTasks = tasks.where((t) =>
        t.assignedToId == currentUser?.uid && t.status != 'Completed'
    ).toList();

    final notifications = ref.watch(notificationsProvider).value ?? [];
    final unreadNotifications = currentUser?.role == UserRoles.companyAdmin
        ? notifications.where((n) => !n.isRead).toList()
        : <AppNotificationModel>[];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminders & Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: (todayFollowups.isEmpty && missedFollowups.isEmpty && myTasks.isEmpty && unreadNotifications.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('No pending tasks or schedules for today!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (unreadNotifications.isNotEmpty) ...[
                        _buildReminderSectionHeader('System Notifications', const Color(0xFF6366F1)),
                        ...unreadNotifications.map((n) => ListTile(
                              leading: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6366F1)),
                              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(n.body, style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 16),
                              dense: true,
                              onTap: () async {
                                Navigator.pop(context);
                                await ref.read(notificationsProvider.notifier).markAsRead(n.notificationId);
                                if (context.mounted) {
                                  context.push('/employee-requests');
                                }
                              },
                            )),
                      ],
                      if (missedFollowups.isNotEmpty) ...[
                        _buildReminderSectionHeader('Missed Follow-ups', Colors.red),
                        ...missedFollowups.map((f) => ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                              title: Text(f.remarks.isNotEmpty ? f.remarks : 'Call Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Due: ${DateFormat('dd MMM hh:mm a').format(f.followUpDate)}', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 16),
                              dense: true,
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/followup-detail/${f.followUpId}');
                              },
                            )),
                      ],
                      if (todayFollowups.isNotEmpty) ...[
                        _buildReminderSectionHeader("Today's Schedule", Colors.orange),
                        ...todayFollowups.map((f) => ListTile(
                              leading: const Icon(Icons.phone_in_talk_outlined, color: Colors.orange),
                              title: Text(f.remarks.isNotEmpty ? f.remarks : 'Call Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Time: ${DateFormat('hh:mm a').format(f.followUpDate)}', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 16),
                              dense: true,
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/followup-detail/${f.followUpId}');
                              },
                            )),
                      ],
                      if (myTasks.isNotEmpty) ...[
                        _buildReminderSectionHeader('Pending Tasks', Colors.blue),
                        ...myTasks.map((t) => ListTile(
                              leading: const Icon(Icons.playlist_add_check_rounded, color: Colors.blue),
                              title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Due: ${DateFormat('dd MMM').format(t.dueDate)}', style: const TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right, size: 16),
                              dense: true,
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/tasks');
                              },
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
