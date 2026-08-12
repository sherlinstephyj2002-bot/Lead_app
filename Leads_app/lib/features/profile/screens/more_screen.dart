import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'help_center_screen.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/user_roles.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import '../../../shared/providers/permissions_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final permissionService = ref.watch(permissionServiceProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final employeesAsync = ref.watch(companyEmployeesProvider);
    final leadsState = ref.watch(leadsProvider);
    final ordersState = ref.watch(ordersProvider);



    final totalEmployees = employeesAsync.value?.length ?? 0;
    
    int totalLeadsCount = 0;
    leadsState.whenData((list) {
      totalLeadsCount = list.length;
    });

    int totalOrdersCount = 0;
    double thisMonthSales = 0.0;
    ordersState.whenData((list) {
      totalOrdersCount = list.length;
      final today = DateTime.now();
      final thisMonthOrders = list.where((o) =>
          o.createdAt.year == today.year &&
          o.createdAt.month == today.month &&
          o.status != 'Cancelled'
      );
      thisMonthSales = thisMonthOrders.fold(0.0, (sum, item) => sum + item.amount);
    });

    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_IN', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final company = ref.watch(companyProvider).value;
    final isLeadEnabled = company?.isLeadManagementEnabled ?? true;
    final isTaskEnabled = company?.isTaskManagementEnabled ?? true;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('More', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Manage company settings, preferences & support', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: const [
          NotificationBellWidget(iconColor: Colors.white, iconSize: 26),
          SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (user.role != UserRoles.companyAdmin) ...[
      // Quick Summary metrics section
      Text(
        'Quick Summary',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSummaryMiniCard(context, '$totalEmployees', 'Employees', const Color(0xFF10B981)),
            if (isLeadEnabled)
              _buildSummaryMiniCard(context, '$totalLeadsCount', 'Total Leads', const Color(0xFF3B82F6)),
            if (permissionService.hasPermission('order_view') || permissionService.hasPermission('order.view')) ...[
              _buildSummaryMiniCard(context, '$totalOrdersCount', 'Orders', const Color(0xFFF59E0B)),
              _buildSummaryMiniCard(context, formatCurrency.format(thisMonthSales), 'This Month Sales', const Color(0xFF8B5CF6)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 28),
    ],

            // Secondary Settings & Utilities Only
            _buildSectionHeader(context, 'Account & Subscription'),
            _buildMenuItem(context, Icons.credit_card_rounded, 'Subscription Management', 'Manage your plan, usage limits, and billing details.', () => context.push('/subscription')),

            const SizedBox(height: 16),

            _buildSectionHeader(context, 'Preferences & Support'),
            _buildMenuItem(context, Icons.settings_rounded, 'App Settings', 'General application settings and preferences', () => context.push('/settings')),
            _buildMenuItem(context, Icons.help_center_rounded, 'Help Center', 'FAQs, guides and contact support', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen()))),
            _buildMenuItem(context, Icons.info_outline_rounded, 'About Us', 'About our app and version info', () => _showAboutUsDialog(context)),
            const SizedBox(height: 28),

            // 6. Logout row
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: isDark ? const Color(0xFF3B1C1C) : const Color(0xFFFEF2F2),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text('Sign out from your account', style: TextStyle(color: isDark ? const Color(0xFFF87171) : const Color(0xFFFCA5A5), fontSize: 11)),
              trailing: Icon(Icons.chevron_right, color: isDark ? const Color(0xFFF87171) : const Color(0xFFFCA5A5)),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildSummaryMiniCard(BuildContext context, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B)),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      trailing: Icon(Icons.chevron_right, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 18),
      onTap: onTap,
      dense: true,
    );
  }




  void _showAboutUsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('About Us', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.track_changes_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('WorkTrack App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
            const Text('Version 1.0.0 (Stable)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            const Text(
              'WorkTrack is a premium business suite helping sales teams, field services, and office managers track leads, orders, tasks, expenses, and employee attendance in real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('© 2026 WorkTrack Inc. All rights reserved.', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
