import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_center_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(notificationCenterProvider);
    final settings = state.settings;
    final notifier = ref.read(notificationCenterProvider.notifier);

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
          'Notification Settings',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category Preferences Section ──
                _buildSectionHeader('CATEGORY PREFERENCES', 'Enable or disable alert channels by module', isDark),
                const SizedBox(height: 12),

                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    _buildSwitchTile(
                      title: 'Attendance Notifications',
                      subtitle: 'Alerts for check-ins, check-outs, late attendance and reminders',
                      value: settings.attendanceNotifications,
                      icon: Icons.fingerprint_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(attendanceNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Leave Management Notifications',
                      subtitle: 'Alerts for leave applications, approvals, rejections and balances',
                      value: settings.leaveNotifications,
                      icon: Icons.event_busy_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(leaveNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Lead & CRM Alerts',
                      subtitle: 'Updates on assigned leads, status updates and follow-up reminders',
                      value: settings.leadNotifications,
                      icon: Icons.person_search_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(leadNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Order & Invoice Alerts',
                      subtitle: 'Notifications for new order assignments, completion and invoicing',
                      value: settings.orderNotifications,
                      icon: Icons.receipt_long_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(orderNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Task Assignment Alerts',
                      subtitle: 'Alerts for assigned tasks, due date reminders and completions',
                      value: settings.taskNotifications,
                      icon: Icons.task_alt_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(taskNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Expense Claim Updates',
                      subtitle: 'Alerts for expense submissions, approvals and reimbursements',
                      value: settings.expenseNotifications,
                      icon: Icons.account_balance_wallet_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(expenseNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Payroll & Payslip Alerts',
                      subtitle: 'Notifications for monthly payroll generation and payslip releases',
                      value: settings.payrollNotifications,
                      icon: Icons.payments_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(payrollNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Company & Administration Alerts',
                      subtitle: 'Updates for branch creations, department additions and role changes',
                      value: settings.companyNotifications,
                      icon: Icons.corporate_fare_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(companyNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Company Announcements',
                      subtitle: 'Broadcast notifications for holidays, townhalls and executive notices',
                      value: settings.announcementNotifications,
                      icon: Icons.campaign_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(announcementNotifications: val)),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Delivery Channels Section ──
                _buildSectionHeader('DELIVERY CHANNELS', 'Configure delivery methods for alerts', isDark),
                const SizedBox(height: 12),

                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    _buildSwitchTile(
                      title: 'Email Notifications',
                      subtitle: 'Receive urgent and daily digest alerts via work email',
                      value: settings.emailNotifications,
                      icon: Icons.email_outlined,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(emailNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Push Notifications',
                      subtitle: 'Mobile & Web browser real-time push alerts',
                      value: settings.pushNotifications,
                      icon: Icons.notifications_active_outlined,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(pushNotifications: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Sound Effects',
                      subtitle: 'Play subtle enterprise sound chime on new incoming alerts',
                      value: settings.soundEnabled,
                      icon: Icons.volume_up_outlined,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(soundEnabled: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Vibration Alerts',
                      subtitle: 'Vibrate mobile device on urgent notifications',
                      value: settings.vibrationEnabled,
                      icon: Icons.vibration_rounded,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(vibrationEnabled: val)),
                      isDark: isDark,
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      title: 'Desktop Popup Banners',
                      subtitle: 'Display system desktop notifications when application is minimized',
                      value: settings.desktopNotifications,
                      icon: Icons.desktop_windows_outlined,
                      onChanged: (val) => notifier.updateSettings(settings.copyWith(desktopNotifications: val)),
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: const Color(0xFF5B4CF0),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required BuildContext context, required bool isDark, required List<Widget> children}) {
    return Material(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF5B4CF0),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF5B4CF0), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontFamily: 'Outfit',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 64,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}
