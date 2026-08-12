import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:worktrack/shared/providers/permissions_provider.dart';
import 'package:worktrack/constants/feature_flags.dart';

class CompanyAdminMenuScreen extends ConsumerWidget {
  const CompanyAdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionService = ref.watch(permissionServiceProvider);

    final List<Map<String, dynamic>> menuItems = [
      // 1. EMPLOYEE MANAGEMENT
      {
        'category': 'EMPLOYEE MANAGEMENT',
        'title': 'Employees Directory',
        'subtitle': 'Add, edit, activate & deactivate employee accounts',
        'icon': Icons.people_alt_rounded,
        'route': '/company-admin/employees',
        'color': const Color(0xFF0EA5E9),
        'permission': 'employee.view',
      },
      {
        'category': 'EMPLOYEE MANAGEMENT',
        'title': 'HR Management',
        'subtitle': 'Create & manage HR Admins and HR Executives',
        'icon': Icons.admin_panel_settings_rounded,
        'route': '/company-admin/hr',
        'color': const Color(0xFF6366F1),
        'permission': 'employee.create',
      },
      {
        'category': 'EMPLOYEE MANAGEMENT',
        'title': 'Departments',
        'subtitle': 'Manage department units & organizational structure',
        'icon': Icons.corporate_fare_rounded,
        'route': '/company-admin/departments',
        'color': const Color(0xFF10B981),
        'permission': 'employee.view',
      },
      {
        'category': 'EMPLOYEE MANAGEMENT',
        'title': 'Designations',
        'subtitle': 'Configure designation job titles & levels',
        'icon': Icons.badge_rounded,
        'route': '/company-admin/designations',
        'color': const Color(0xFFF59E0B),
        'permission': 'settings.manage',
      },
      {
        'category': 'EMPLOYEE MANAGEMENT',
        'title': 'Employee Requests',
        'subtitle': 'Approve or reject employee profile & data edit requests',
        'icon': Icons.verified_user_rounded,
        'route': '/employee-requests',
        'color': const Color(0xFF8B5CF6),
        'permission': 'settings.manage',
      },

      // 2. SALARY & PAYROLL
      {
        'category': 'SALARY & PAYROLL',
        'title': 'Salary Configuration & Payslips',
        'subtitle': 'Manage payslips, structure assignments & monthly generation',
        'icon': Icons.payments_rounded,
        'route': '/company-admin/salary-payroll',
        'color': const Color(0xFF10B981),
        'permission': 'payroll.manage',
      },
      {
        'category': 'SALARY & PAYROLL',
        'title': 'Monthly Payroll Processing',
        'subtitle': 'Verify working days, overtime, LOP & submit monthly payroll',
        'icon': Icons.account_balance_wallet_rounded,
        'route': '/company-admin/payroll-processing',
        'color': const Color(0xFF0EA5E9),
        'permission': 'payroll.manage',
      },
      {
        'category': 'SALARY & PAYROLL',
        'title': 'Salary Components',
        'subtitle': 'Configure earnings, deductions & allowance components',
        'icon': Icons.tune_rounded,
        'route': '/company-admin/salary-components',
        'color': const Color(0xFFF59E0B),
        'permission': 'payroll.manage',
      },
      {
        'category': 'SALARY & PAYROLL',
        'title': 'Salary Structure Templates',
        'subtitle': 'Configure salary packages, templates & employee structure mapping',
        'icon': Icons.receipt_long_rounded,
        'route': '/company-admin/salary-structures',
        'color': const Color(0xFF6366F1),
        'permission': 'payroll.manage',
      },
      {
        'category': 'SALARY & PAYROLL',
        'title': 'PF / ESI & Statutory Taxes',
        'subtitle': 'Manage Provident Fund, ESI, TDS & Tax compliance',
        'icon': Icons.shield_rounded,
        'route': '/company-admin/pf-esi-tax',
        'color': const Color(0xFF8B5CF6),
        'permission': 'payroll.manage',
      },
      {
        'category': 'SALARY & PAYROLL',
        'title': 'Payroll Settings',
        'subtitle': 'Configure pay cycle dates, LOP rules & pay slip templates',
        'icon': Icons.settings_suggest_rounded,
        'route': '/company-admin/payroll-settings',
        'color': const Color(0xFFEC4899),
        'permission': 'payroll.manage',
      },

      // 3. COMPANY ADMINISTRATION
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Company Profile',
        'subtitle': 'Company info, logo, branding & regional settings',
        'icon': Icons.business_center_rounded,
        'route': '/company-profile',
        'color': const Color(0xFF4F46E5),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Subscription',
        'subtitle': 'Manage plan, employee usage limits & billing',
        'icon': Icons.credit_card_rounded,
        'route': '/subscription',
        'color': const Color(0xFF8B5CF6),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Role Permissions',
        'subtitle': 'Customize module access matrix & system roles',
        'icon': Icons.security_rounded,
        'route': '/company-admin/permissions',
        'color': const Color(0xFF06B6D4),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Company Configuration',
        'subtitle': 'Working days, office timings, regional date/time formats',
        'icon': Icons.settings_applications_rounded,
        'route': '/company-admin/configuration',
        'color': const Color(0xFF14B8A6),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Announcements',
        'subtitle': 'Dispatch company-wide or department notifications',
        'icon': Icons.campaign_rounded,
        'route': '/company-admin/announcements',
        'color': const Color(0xFFF97316),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Audit Logs',
        'subtitle': 'Track company activity history & changes',
        'icon': Icons.history_rounded,
        'route': '/company-admin/audit-logs',
        'color': const Color(0xFFEF4444),
        'permission': 'settings.manage',
      },
      {
        'category': 'COMPANY ADMINISTRATION',
        'title': 'Consolidated Reports',
        'subtitle': 'View company overview reports & analytics',
        'icon': Icons.analytics_rounded,
        'route': '/company-admin/reports',
        'color': const Color(0xFF64748B),
        'permission': 'reports.view',
      },

      // 4. ATTENDANCE & WORKFORCE
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Attendance Review & Corrections',
        'subtitle': 'Review daily logs, approve missed punches & correct records',
        'icon': Icons.fact_check_rounded,
        'route': '/company-admin/override-approval',
        'color': const Color(0xFF14B8A6),
        'permission': 'attendance.approve',
      },
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Attendance Settings',
        'subtitle': 'Configure check-in radius, biometric & location rules',
        'icon': Icons.touch_app_rounded,
        'route': '/company-admin/attendance-settings',
        'color': const Color(0xFF06B6D4),
        'permission': 'settings.manage',
      },
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Work Shifts',
        'subtitle': 'Configure shift timetables & late grace periods',
        'icon': Icons.access_time_rounded,
        'route': '/company-admin/shifts',
        'color': const Color(0xFF8B5CF6),
        'permission': 'settings.manage',
      },
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Overtime Settings',
        'subtitle': 'Configure overtime multipliers, caps & approval policies',
        'icon': Icons.more_time_rounded,
        'route': '/company-admin/overtime-settings',
        'color': const Color(0xFFF97316),
        'permission': 'settings.manage',
      },
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Leave Policy Configuration',
        'subtitle': 'Configure leave quotas, accruals, roll-over & encashment rules',
        'icon': Icons.time_to_leave_rounded,
        'route': '/company-admin/leave-policy',
        'color': const Color(0xFF3B82F6),
        'permission': 'settings.manage',
      },
      {
        'category': 'ATTENDANCE & WORKFORCE',
        'title': 'Holidays Calendar',
        'subtitle': 'Manage company holidays & annual calendar list',
        'icon': Icons.calendar_today_rounded,
        'route': '/company-admin/holidays',
        'color': const Color(0xFFEC4899),
        'permission': 'settings.manage',
      },
    ];

    // Filter items based on active RBAC permissions and feature flags
    final filteredMenuItems = menuItems.where((item) {
      if (item['route'] == '/company-admin/branches' && !FeatureFlags.enableBranchManagement) {
        return false;
      }
      final perm = item['permission'] as String?;
      if (perm == null) return true;
      return permissionService.hasPermission(perm);
    }).toList();

    // Group items by category
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final item in filteredMenuItems) {
      final cat = (item['category'] as String?) ?? 'GENERAL';
      categories.putIfAbsent(cat, () => []).add(item);
    }

    final isWide = MediaQuery.of(context).size.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Administration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text('Configure and manage settings for your company only', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderCol),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.admin_panel_settings_rounded, size: 36, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrative Console',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Strict isolation active. You can only view and manage your company\'s records. Super Admins cannot access this section.',
                            style: TextStyle(fontSize: 13, color: subtitleColor, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Render Categorized Section Hubs
            ...categories.entries.expand((entry) {
              final catName = entry.key;
              final catItems = entry.value;

              return [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, bottom: 12.0, top: 8.0),
                  child: Text(
                    catName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Color(0xFF5B4CF0),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isWide ? 1.5 : 1.1,
                  ),
                  itemCount: catItems.length,
                  itemBuilder: (context, index) {
                    final item = catItems[index];
                    return _buildMenuCard(context, item);
                  },
                ),
                const SizedBox(height: 24),
              ];
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, Map<String, dynamic> item) {
    final color = item['color'] as Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: InkWell(
        onTap: () => context.push(item['route']),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item['icon'] as IconData, color: color, size: 24),
              ),
              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      item['title'] as String,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'] as String,
                      style: TextStyle(fontSize: 10, color: subtitleColor, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
