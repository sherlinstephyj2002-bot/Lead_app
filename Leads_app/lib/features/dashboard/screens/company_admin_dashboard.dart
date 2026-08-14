import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/user_model.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../notifications/widgets/notification_bell_widget.dart';
import 'onboarding_wizard_screen.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/company_model.dart';
import '../../../shared/widgets/app_user_avatar.dart';
import '../../../shared/widgets/google_ads_banner.dart';
import '../../../constants/user_roles.dart';

class CompanyAdminDashboard extends ConsumerWidget {
  const CompanyAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final companyAsync = ref.watch(companyProvider);
    final employeesAsync = ref.watch(adminEmployeesProvider);
    final departmentsAsync = ref.watch(adminDepartmentsProvider);
    final designationsAsync = ref.watch(adminDesignationsProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    final company = companyAsync.value;
    final rawEmployees = employeesAsync.value ?? [];
    final employees = rawEmployees.where((e) => e.role != UserRoles.companyAdmin).toList();
    final departments = departmentsAsync.value ?? [];
    final designations = designationsAsync.value ?? [];
    final notifications = notificationsAsync.value ?? [];

    final totalEmployees = employees.length;
    final activeEmployees = employees.where((e) => e.status.toLowerCase() == 'active').length;
    final inactiveEmployees = totalEmployees - activeEmployees;

    final hrAdminsCount = employees.where((e) => e.role == UserRoles.hrAdmin || e.role == UserRoles.hr).length;
    final hrExecsCount = employees.where((e) => e.role == UserRoles.hrExecutive).length;
    final totalHrCount = hrAdminsCount + hrExecsCount;

    final isPaidPlan = company?.isPaidPlan ?? false;
    final maxSeats = isPaidPlan ? null : 5;
    final seatsRemaining = maxSeats != null ? (maxSeats - activeEmployees).clamp(0, maxSeats) : null;
    final isSeatLimitReached = maxSeats != null && activeEmployees >= maxSeats;

    final today = DateTime.now();
    final newEmployeesThisMonth = employees.where((e) {
      return e.createdAt.year == today.year && e.createdAt.month == today.month;
    }).length;

    // Build real administrative activity timeline
    final List<AdminRecentActivity> activities = [];
    for (final emp in employees.take(5)) {
      activities.add(AdminRecentActivity(
        title: 'Employee Onboarded',
        description: '${emp.name} added as ${UserModel.denormalizeRole(emp.role)}',
        time: emp.createdAt,
        icon: Icons.person_add_rounded,
        color: const Color(0xFF5B4CF0),
      ));
    }
    for (final dept in departments.take(3)) {
      activities.add(AdminRecentActivity(
        title: 'Department Configured',
        description: 'Department "${dept.departmentName}" updated',
        time: dept.createdAt,
        icon: Icons.business_rounded,
        color: const Color(0xFF10B981),
      ));
    }
    for (final desig in designations.take(3)) {
      activities.add(AdminRecentActivity(
        title: 'Designation Added',
        description: 'Designation "${desig.designationName}" active',
        time: desig.createdAt,
        icon: Icons.badge_rounded,
        color: const Color(0xFFF59E0B),
      ));
    }
    activities.sort((a, b) => b.time.compareTo(a.time));
    final displayActivities = activities.take(5).toList();

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildAdminHeader(
              context: context,
              user: user,
              company: company,
              greeting: getGreeting(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Setup Wizard banner if incomplete
                if (company != null && !company.isSetupCompleted) ...[
                  _buildSetupWizardBanner(context),
                  const SizedBox(height: 16),
                ],

                // 1. Executive Quick Actions (Max 4)
                _buildSectionHeader(context, 'Quick Actions', Icons.bolt_rounded),
                const SizedBox(height: 10),
                _buildQuickActions(context, ref),
                const SizedBox(height: 20),

                // 2. Company Overview KPIs
                _buildSectionHeader(context, 'Company Overview', Icons.dashboard_outlined),
                const SizedBox(height: 10),
                _buildOverviewKpiCards(
                  context: context,
                  totalEmployees: totalEmployees,
                  activeEmployees: activeEmployees,
                  departmentsCount: departments.length,
                  designationsCount: designations.length,
                  hrUsersCount: totalHrCount,
                  isPaidPlan: isPaidPlan,
                  seatsRemaining: seatsRemaining,
                  isSeatLimitReached: isSeatLimitReached,
                  newEmployeesThisMonth: newEmployeesThisMonth,
                ),
                const SizedBox(height: 20),

                // 3. Subscription Status Banner
                _buildSubscriptionCard(
                  context: context,
                  company: company,
                  activeEmployees: activeEmployees,
                  isPaidPlan: isPaidPlan,
                  maxSeats: maxSeats,
                  seatsRemaining: seatsRemaining,
                  isSeatLimitReached: isSeatLimitReached,
                ),
                const SizedBox(height: 20),

                // 4. Company Health Breakdown
                _buildSectionHeader(context, 'Company Health Breakdown', Icons.analytics_outlined),
                const SizedBox(height: 10),
                _buildCompanyHealthCard(
                  context: context,
                  activeEmployees: activeEmployees,
                  inactiveEmployees: inactiveEmployees,
                  departmentCount: departments.length,
                  designationCount: designations.length,
                  hrAdminCount: hrAdminsCount,
                  hrExecCount: hrExecsCount,
                ),
                const SizedBox(height: 20),

                // Google Ads Banner (Free plan only)
                if (!isPaidPlan) ...[
                  const GoogleAdsBanner(),
                  const SizedBox(height: 20),
                ],

                // 5. Important Notifications
                _buildSectionHeaderWithAction(
                  context,
                  'Important Notifications',
                  Icons.notifications_active_outlined,
                  onAction: () => context.push('/notifications'),
                  actionLabel: 'View All',
                ),
                const SizedBox(height: 10),
                _buildNotificationsSection(context, notifications),
                const SizedBox(height: 20),

                // 6. Recent Administrative Activity Timeline
                _buildSectionHeader(context, 'Recent Administrative Activity', Icons.history_rounded),
                const SizedBox(height: 10),
                _buildActivityTimeline(context, displayActivities),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5B4CF0)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderWithAction(
    BuildContext context,
    String title,
    IconData icon, {
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF5B4CF0)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
          child: Text(
            actionLabel,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5B4CF0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminHeader({
    required BuildContext context,
    required UserModel user,
    required CompanyModel? company,
    required String greeting,
  }) {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3D422CD8),
            blurRadius: 14,
            offset: Offset(0, 6),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'COMPANY ADMIN DASHBOARD',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      company?.name ?? user.companyName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
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
                  const NotificationBellWidget(iconColor: Colors.white, iconSize: 24),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Tooltip(
                      message: 'Account Profile',
                      child: AppUserAvatar(
                        user: user,
                        radius: 18,
                        showBorder: true,
                        borderColor: Colors.white30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
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

  Widget _buildSetupWizardBanner(BuildContext context) {
    return Container(
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
            color: const Color(0xFF5B4CF0).withValues(alpha: 0.2),
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
            'Configure branches, departments, shifts, and holidays to complete your company onboarding.',
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
                  MaterialPageRoute(builder: (context) => const OnboardingWizardScreen()),
                );
              },
              child: const Text('Start Setup Wizard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final permissionService = ref.watch(permissionServiceProvider);
    final hasLeadView = permissionService.hasPermission('lead_view') || permissionService.hasPermission('lead.view');

    final actions = [
      if (hasLeadView)
        {
          'title': 'Lead Management',
          'icon': Icons.emoji_people_rounded,
          'color': const Color(0xFF3B82F6),
          'onTap': () => context.push('/leads'),
        },
      {
        'title': 'Add Employee',
        'icon': Icons.person_add_rounded,
        'color': const Color(0xFF5B4CF0),
        'onTap': () => context.push('/company-admin/employees'),
      },
      {
        'title': 'Departments',
        'icon': Icons.corporate_fare_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () => context.push('/company-admin/departments'),
      },
      if (!hasLeadView)
        {
          'title': 'Designations',
          'icon': Icons.badge_rounded,
          'color': const Color(0xFFF59E0B),
          'onTap': () => context.push('/company-admin/designations'),
        },
      {
        'title': 'Permissions',
        'icon': Icons.security_rounded,
        'color': const Color(0xFF0EA5E9),
        'onTap': () => context.push('/company-admin/permissions'),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (!isWide) {
          return GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.4,
            children: actions.map((act) {
              final color = act['color'] as Color;
              return InkWell(
                onTap: act['onTap'] as VoidCallback,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : const Color(0xFF111827).withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.2 : 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(act['icon'] as IconData, color: color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          act['title'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }

        return Row(
          children: actions.map((act) {
            final color = act['color'] as Color;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: act['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : const Color(0xFF111827).withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act['icon'] as IconData, color: color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      act['title'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  },
);
  }

  Widget _buildOverviewKpiCards({
    required BuildContext context,
    required int totalEmployees,
    required int activeEmployees,
    required int departmentsCount,
    required int designationsCount,
    required int hrUsersCount,
    required bool isPaidPlan,
    required int? seatsRemaining,
    required bool isSeatLimitReached,
    required int newEmployeesThisMonth,
  }) {
    final seatSubtitle = isPaidPlan
        ? 'Unlimited seats'
        : (isSeatLimitReached ? 'Limit reached' : '$seatsRemaining seats available');

    final List<Map<String, dynamic>> kpiItems = [
      {'title': 'Total Staff', 'value': '$totalEmployees', 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF6366F1), 'subtitle': '$activeEmployees Active'},
      {'title': 'Active Staff', 'value': '$activeEmployees', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF06B6D4), 'subtitle': 'Enabled accounts'},
      {'title': 'Employee Usage', 'value': isPaidPlan ? '$activeEmployees Active' : '$activeEmployees / 5', 'icon': Icons.pie_chart_rounded, 'color': isSeatLimitReached ? const Color(0xFFEF4444) : const Color(0xFF5B4CF0), 'subtitle': seatSubtitle},
      {'title': 'Departments', 'value': '$departmentsCount', 'icon': Icons.business_rounded, 'color': const Color(0xFF10B981), 'subtitle': 'Organized units'},
      {'title': 'Designations', 'value': '$designationsCount', 'icon': Icons.badge_rounded, 'color': const Color(0xFFF59E0B), 'subtitle': 'Configured roles'},
      {'title': 'HR Team', 'value': '$hrUsersCount', 'icon': Icons.admin_panel_settings_rounded, 'color': const Color(0xFF8B5CF6), 'subtitle': 'Admins & Execs'},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: kpiItems.length,
        itemBuilder: (context, idx) {
          final item = kpiItems[idx];
          final color = item['color'] as Color;

          return Container(
            width: 132,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0xFF111827).withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData, color: color, size: 16),
                    ),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['subtitle'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required BuildContext context,
    required CompanyModel? company,
    required int activeEmployees,
    required bool isPaidPlan,
    required int? maxSeats,
    required int? seatsRemaining,
    required bool isSeatLimitReached,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isSeatLimitReached
        ? const Color(0xFFEF4444)
        : (seatsRemaining == 1 ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)));

    String warningText = '';
    if (!isPaidPlan) {
      if (isSeatLimitReached) {
        warningText = 'Employee limit reached. Upgrade your plan to add more active employees.';
      } else if (seatsRemaining == 1) {
        warningText = 'You have 1 employee seat remaining.';
      } else if (seatsRemaining != null) {
        warningText = 'Free Plan includes up to 5 active employees ($seatsRemaining seats available).';
      }
    } else {
      warningText = 'Paid Plan active ($activeEmployees employees). USD 0.50 per active employee / month.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isSeatLimitReached || seatsRemaining == 1 ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF111827).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.credit_card_rounded, color: Color(0xFF5B4CF0), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT PLAN',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      Text(
                        isPaidPlan ? 'Paid Plan' : 'Free Plan',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.push('/subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4CF0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 0,
                ),
                child: const Text('Manage Subscription', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSeatLimitReached
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                  : (seatsRemaining == 1 ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB)) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isSeatLimitReached ? Icons.error_outline_rounded : (seatsRemaining == 1 ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
                  size: 16,
                  color: isSeatLimitReached ? const Color(0xFFEF4444) : (seatsRemaining == 1 ? const Color(0xFFF59E0B) : const Color(0xFF5B4CF0)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warningText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSeatLimitReached ? const Color(0xFFEF4444) : (seatsRemaining == 1 ? const Color(0xFFD97706) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHealthCard({
    required BuildContext context,
    required int activeEmployees,
    required int inactiveEmployees,
    required int departmentCount,
    required int designationCount,
    required int hrAdminCount,
    required int hrExecCount,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHealthMetric(context, 'Active Staff', '$activeEmployees', const Color(0xFF10B981)),
              _buildHealthMetric(context, 'Inactive Staff', '$inactiveEmployees', const Color(0xFFEF4444)),
              _buildHealthMetric(context, 'Departments', '$departmentCount', const Color(0xFF3B82F6)),
              _buildHealthMetric(context, 'Designations', '$designationCount', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HR Administrators: $hrAdminCount', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor)),
              Text('HR Executives: $hrExecCount', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context, List dynamicNotifications) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (dynamicNotifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 20),
            const SizedBox(width: 10),
            Text(
              'No new notifications',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: subtitleColor),
            ),
          ],
        ),
      );
    }

    final topNotifications = dynamicNotifications.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: topNotifications.map<Widget>((notif) {
          final title = notif.title ?? 'Notification';
          final body = notif.body ?? notif.message ?? '';

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF5B4CF0), size: 16),
            ),
            title: Text(
              title,
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              body,
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: subtitleColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityTimeline(BuildContext context, List<AdminRecentActivity> activities) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
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
            'No administrative activity recorded yet.',
            style: TextStyle(fontFamily: 'Inter', color: subtitleColor, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                        color: act.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act.icon, color: act.color, size: 16),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 2, color: borderColor),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              act.title,
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                            ),
                            Text(
                              _formatRelativeTime(act.time),
                              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          act.description,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: subtitleColor, height: 1.3),
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
}

class AdminRecentActivity {
  final String title;
  final String description;
  final DateTime time;
  final IconData icon;
  final Color color;

  const AdminRecentActivity({
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.color,
  });
}
