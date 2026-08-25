import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../routes/app_routes.dart';
import '../companies/companies_screen.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../analytics/analytics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : Drawer(child: _buildSidebarContent(theme, authProvider)),
      body: Row(
        children: [
          // Desktop Sidebar
          if (isDesktop)
            SizedBox(
              width: 270,
              child: _buildSidebarContent(theme, authProvider),
            ),

          // Main Content Workspace
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                _buildHeaderBar(theme, authProvider, isDesktop),
                const Divider(),

                // Workspace Content Body
                Expanded(
                  child: _buildWorkspaceContent(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(ThemeData theme, AuthProvider authProvider, bool isDesktop) {
    final user = authProvider.userModel;
    final displayEmail = (user?.email != null && user!.email.isNotEmpty) ? user.email : 'superadmin@worktrack.local';
    final displayName = (user?.name != null && user!.name.isNotEmpty) ? user.name : 'SuperAdmin';

    return Container(
      height: 76,
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              Text(
                'SuperAdmin',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          // Authenticated SuperAdmin Profile Section
          Row(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SuperAdmin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // SuperAdmin Profile Display
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'SuperAdmin',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  Text(
                    displayEmail,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Avatar
              CircleAvatar(
                backgroundColor: theme.primaryColor,
                radius: 19,
                child: const Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Refresh Data Button
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Data',
                color: theme.primaryColor,
                onPressed: () => context.read<CompanyProvider>().fetchCompanies(),
              ),

              // Logout Action
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                tooltip: 'Sign Out',
                color: theme.colorScheme.error,
                onPressed: () async {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(ThemeData theme, AuthProvider authProvider) {
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: theme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WorkTrack',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'SuperAdmin Portal',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Sectioned Sidebar List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              children: [
                _buildSectionHeader('OVERVIEW'),
                _buildSidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isActive: _activeTabIndex == 0,
                  onTap: () => _selectTab(0),
                ),
                const SizedBox(height: 16),

                _buildSectionHeader('MANAGEMENT'),
                _buildSidebarItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Users',
                  isActive: _activeTabIndex == 1,
                  onTap: () => _selectTab(1),
                ),
                _buildSidebarItem(
                  icon: Icons.business_rounded,
                  label: 'Companies',
                  isActive: _activeTabIndex == 2,
                  onTap: () => _selectTab(2),
                ),
                _buildSidebarItem(
                  icon: Icons.card_membership_rounded,
                  label: 'Plans',
                  isActive: _activeTabIndex == 3,
                  onTap: () => _selectTab(3),
                ),
                _buildSidebarItem(
                  icon: Icons.subscriptions_rounded,
                  label: 'Subscriptions',
                  isActive: _activeTabIndex == 4,
                  onTap: () => _selectTab(4),
                ),
                _buildSidebarItem(
                  icon: Icons.vpn_key_rounded,
                  label: 'Offline Licenses',
                  isActive: _activeTabIndex == 5,
                  onTap: () => _selectTab(5),
                ),
                _buildSidebarItem(
                  icon: Icons.mark_email_unread_rounded,
                  label: 'Messages',
                  isActive: _activeTabIndex == 6,
                  onTap: () => _selectTab(6),
                ),
                _buildSidebarItem(
                  icon: Icons.assessment_rounded,
                  label: 'Reports',
                  isActive: _activeTabIndex == 7,
                  onTap: () => _selectTab(7),
                ),
                _buildSidebarItem(
                  icon: Icons.campaign_rounded,
                  label: 'Broadcasts',
                  isActive: _activeTabIndex == 8,
                  onTap: () => _selectTab(8),
                ),
                _buildSidebarItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Features & AI',
                  isActive: _activeTabIndex == 9,
                  onTap: () => _selectTab(9),
                ),
                const SizedBox(height: 16),

                _buildSectionHeader('SETTINGS'),
                _buildSidebarItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  isActive: _activeTabIndex == 10,
                  onTap: () => _selectTab(10),
                ),
              ],
            ),
          ),
          const Divider(),

          // Logout Action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _activeTabIndex = index;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: isActive ? theme.primaryColor.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isActive ? theme.primaryColor : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceContent(ThemeData theme) {
    switch (_activeTabIndex) {
      case 0:
        return _buildDashboardOverview(theme);
      case 1:
        return _buildUsersView(theme);
      case 2:
        return const CompaniesScreen();
      case 3:
        return _buildPlansMatrixView(theme);
      case 4:
        return const SubscriptionsScreen();
      case 5:
        return _buildOfflineLicensesView(theme);
      case 6:
        return _buildMessagesView(theme);
      case 7:
        return const AnalyticsScreen();
      case 8:
        return _buildBroadcastsView(theme);
      case 9:
        return _buildFeaturesAiView(theme);
      case 10:
        return _buildSettingsView(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDashboardOverview(ThemeData theme) {
    final companyProvider = Provider.of<CompanyProvider>(context);
    final companies = companyProvider.companies;
    final isLoading = companyProvider.isLoading;
    final errorMessage = companyProvider.errorMessage;

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching SuperAdmin platform metrics...', style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            const Text('Backend Request Failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(errorMessage, style: const TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => companyProvider.fetchCompanies(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Real Metrics Computation
    final totalCompaniesCount = companies.length;
    final activeCompaniesCount = companies.where((c) => c.status.toLowerCase() == 'active').length;
    final totalUsers = companyProvider.totalUsersCount > 0
        ? companyProvider.totalUsersCount
        : companies.fold<int>(0, (sum, c) => sum + companyProvider.getEmployeeCount(c.companyId));
    
    int totalEmployeesSum = 0;
    int freePlanCount = 0;
    int paidPlanCount = 0;

    for (final c in companies) {
      totalEmployeesSum += companyProvider.getEmployeeCount(c.companyId);
      if (c.subscriptionPlan.toLowerCase().contains('free')) {
        freePlanCount++;
      } else {
        paidPlanCount++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SuperAdmin Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time SaaS platform administration metrics and data insights.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => companyProvider.fetchCompanies(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Real Statistics Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 650 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.65,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatTile(theme, 'Total Users', '$totalUsers', Icons.people_alt_rounded, const Color(0xFF6366F1), 'Active platform accounts'),
                  _buildStatTile(theme, 'Total Companies', '$totalCompaniesCount', Icons.business_rounded, const Color(0xFF8B5CF6), '$activeCompaniesCount Active'),
                  _buildStatTile(theme, 'Active Companies', '$activeCompaniesCount', Icons.check_circle_rounded, const Color(0xFF10B981), 'Registered SaaS tenants'),
                  _buildStatTile(theme, 'Total Employees', '$totalEmployeesSum', Icons.badge_rounded, const Color(0xFF06B6D4), 'Employees across companies'),
                  _buildStatTile(theme, 'Active Subscriptions', '$activeCompaniesCount', Icons.card_membership_rounded, const Color(0xFF3B82F6), '$paidPlanCount Paid / $freePlanCount Free'),
                  _buildStatTile(theme, 'Online Sessions', '0', Icons.sensors_rounded, const Color(0xFFEC4899), 'No data available'),
                  _buildStatTile(theme, 'Total Devices', '0', Icons.devices_rounded, const Color(0xFFF59E0B), 'No data available'),
                  _buildStatTile(theme, 'Transactions', '0', Icons.receipt_long_rounded, const Color(0xFF14B8A6), 'No data available'),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Graphical Representation Section
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: Color(0xFF818CF8)),
                          SizedBox(width: 10),
                          Text('Subscription Plan Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Live Backend Data', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (companies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No historical data available',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        _buildChartBar(theme, 'Free Plan Tier', freePlanCount, totalCompaniesCount, const Color(0xFF3B82F6)),
                        const SizedBox(height: 14),
                        _buildChartBar(theme, 'Paid / Standard / Enterprise Tiers', paidPlanCount, totalCompaniesCount, const Color(0xFF8B5CF6)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Quick Actions
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
                      SizedBox(width: 10),
                      Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _selectTab(1),
                        icon: const Icon(Icons.people_alt_rounded, size: 17),
                        label: const Text('Manage Users'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectTab(2),
                        icon: const Icon(Icons.business_rounded, size: 17),
                        label: const Text('Manage Companies'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectTab(4),
                        icon: const Icon(Icons.subscriptions_rounded, size: 17),
                        label: const Text('View Subscriptions'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectTab(7),
                        icon: const Icon(Icons.assessment_rounded, size: 17),
                        label: const Text('View Reports'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _selectTab(8),
                        icon: const Icon(Icons.campaign_rounded, size: 17),
                        label: const Text('Send Broadcast'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recent Activity Section (Real Data or Clean Empty State)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recent Companies', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 16),
                        companies.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(child: Text('No recent activity', style: TextStyle(color: Color(0xFF64748B)))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: companies.length > 5 ? 5 : companies.length,
                                separatorBuilder: (_, _) => const Divider(height: 16),
                                itemBuilder: (context, idx) {
                                  final comp = companies[idx];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                                      child: Icon(Icons.business_rounded, color: theme.primaryColor, size: 18),
                                    ),
                                    title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    subtitle: Text('${comp.subscriptionPlan} • ${comp.status}', style: const TextStyle(fontSize: 12)),
                                    trailing: Text(
                                      comp.createdAt.toString().split(' ')[0],
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              Expanded(
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 36, color: Color(0xFF475569)),
                                SizedBox(height: 10),
                                Text('No recent activity', style: TextStyle(color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(ThemeData theme, String label, int count, int total, Color color) {
    final percent = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
            Text('$count companies (${(percent * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percent.clamp(0.0, 1.0),
          backgroundColor: const Color(0xFF0F172A),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildStatTile(ThemeData theme, String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersView(ThemeData theme) {
    final companyProvider = Provider.of<CompanyProvider>(context);
    final companies = companyProvider.companies;

    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Users & Tenant Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Overview of users registered across tenant organizations.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: companies.isEmpty
                    ? const Center(child: Text('No users available', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.separated(
                        itemCount: companies.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, idx) {
                          final comp = companies[idx];
                          final count = companyProvider.getEmployeeCount(comp.companyId);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                              child: Text('${idx + 1}', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Tenant ID: ${comp.companyId} • Plan: ${comp.subscriptionPlan}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
                              child: Text('$count Registered Users', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlansMatrixView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscription Plans Matrix', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Platform tier definitions and feature allocations.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPlanBox(theme, name: 'Free Tier', price: '\$0 / mo', limit: '10 Employees', storage: '1 GB Storage', color: Colors.blueAccent),
                  _buildPlanBox(theme, name: 'Basic Plan', price: '\$29 / mo', limit: '25 Employees', storage: '10 GB Storage', color: Colors.tealAccent),
                  _buildPlanBox(theme, name: 'Standard Plan', price: '\$79 / mo', limit: '50 Employees', storage: '25 GB Storage', color: Colors.indigoAccent),
                  _buildPlanBox(theme, name: 'Enterprise Tier', price: '\$199 / mo', limit: 'Unlimited', storage: '100 GB Storage', color: Colors.purpleAccent),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBox(ThemeData theme, {required String name, required String price, required String limit, required String storage, required Color color}) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.3))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Text('• Quota: $limit', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            Text('• Allocated: $storage', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('Active Tier', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateView(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: theme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            SizedBox(
              width: 420,
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBroadcastsView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SuperAdmin Announcements & Broadcasts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Dispatch announcements across tenant organizations.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Subject / Title', hintText: 'e.g. Scheduled Maintenance'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message Body', hintText: 'Enter announcement details for tenant administrators...'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Broadcast announcement dispatched successfully!'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Dispatch Broadcast'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change SuperAdmin Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Securely update your SuperAdmin portal password',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          prefixIcon: const Icon(Icons.key_outlined, color: Color(0xFF818CF8)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter your current password';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF818CF8)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter a new password';
                          if (val.length < 8) return 'Password must be at least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_reset_outlined, color: Color(0xFF818CF8)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                            ),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please confirm your new password';
                          if (val != newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);

                          final success = await authProvider.changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );

                          if (!context.mounted) return;
                          setState(() => isSubmitting = false);

                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(child: Text('SuperAdmin password updated successfully!')),
                                  ],
                                ),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else if (authProvider.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(authProvider.errorMessage!)),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineLicensesView(ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('offline_licenses').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline Licenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Manage standalone enterprise key allocations and offline installations.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline License Generator initialized.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Issue Offline License'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (docs.isEmpty)
                _buildEmptyStateView(
                  theme,
                  icon: Icons.vpn_key_rounded,
                  title: 'No Offline Licenses Issued',
                  description: 'No offline license keys have been generated yet for on-premise installations.',
                )
              else
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                            child: Icon(Icons.key_rounded, color: theme.primaryColor, size: 18),
                          ),
                          title: Text(data['key'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text('Company: ${data['company'] ?? 'N/A'} • Status: ${data['status'] ?? 'Active'}', style: const TextStyle(color: Color(0xFF94A3B8))),
                          trailing: Text(data['expiry'] ?? 'No Expiry', style: const TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesView(ThemeData theme) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('admin_messages').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SuperAdmin Messages & Inbox', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('System communications and tenant administrator inquiries.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _selectTab(8),
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Send System Broadcast'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (docs.isEmpty)
                _buildEmptyStateView(
                  theme,
                  icon: Icons.mark_email_unread_rounded,
                  title: 'No Admin Messages',
                  description: 'Your inbox is clear. Tenant communications and system alerts will appear here.',
                )
              else
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                            child: Icon(Icons.email_rounded, color: theme.primaryColor, size: 18),
                          ),
                          title: Text(data['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text('From: ${data['sender'] ?? 'System'} • ${data['body'] ?? ''}', style: const TextStyle(color: Color(0xFF94A3B8))),
                          trailing: Text(data['date'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeaturesAiView(ThemeData theme) {
    final featureFlags = Provider.of<FeatureFlagsProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SuperAdmin Features & AI Capabilities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Configure global AI model integration and feature flags.', style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: featureFlags.isSaving ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: featureFlags.isSaving ? Colors.amber.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      featureFlags.isSaving ? Icons.sync_rounded : Icons.cloud_done_rounded,
                      size: 14,
                      color: featureFlags.isSaving ? Colors.amber : Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      featureFlags.isSaving ? 'Syncing to Firestore...' : 'Configuration Persisted',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: featureFlags.isSaving ? Colors.amber : Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: theme.primaryColor,
                    title: const Text('AI Analytics Engine', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: const Text('Enable automated tenant usage insights and predictive AI analytics across platform.', style: TextStyle(color: Color(0xFF94A3B8))),
                    value: featureFlags.aiAnalyticsEngine,
                    onChanged: (val) async {
                      final success = await featureFlags.setAiAnalyticsEngine(val);
                      if (!success && mounted && featureFlags.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(featureFlags.errorMessage!), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeColor: theme.primaryColor,
                    title: const Text('Geofence Verification Service', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: const Text('Allow tenant admins to set location boundaries for employee attendance and check-ins.', style: TextStyle(color: Color(0xFF94A3B8))),
                    value: featureFlags.geofenceVerificationService,
                    onChanged: (val) async {
                      final success = await featureFlags.setGeofenceVerificationService(val);
                      if (!success && mounted && featureFlags.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(featureFlags.errorMessage!), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    activeColor: theme.primaryColor,
                    title: const Text('Multi-Factor Auth Requirement', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: const Text('Require 2FA verification for high-privilege tenant accounts.', style: TextStyle(color: Color(0xFF94A3B8))),
                    value: featureFlags.multiFactorAuthRequirement,
                    onChanged: (val) async {
                      final success = await featureFlags.setMultiFactorAuthRequirement(val);
                      if (!success && mounted && featureFlags.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(featureFlags.errorMessage!), backgroundColor: Colors.redAccent),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    final displayEmail = (user?.email != null && user!.email.isNotEmpty)
        ? user.email
        : 'superadmin@worktrack.local';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SuperAdmin System Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Platform maintenance parameters and SuperAdmin identity configuration.', style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Authenticated Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.primaryColor,
                      child: const Icon(Icons.shield_outlined, color: Colors.white),
                    ),
                    title: const Text('SuperAdmin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Text(displayEmail, style: const TextStyle(color: Color(0xFF94A3B8))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Text('SuperAdmin', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text('Security Operations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showChangePasswordDialog(context),
                    icon: const Icon(Icons.lock_reset_rounded, size: 18),
                    label: const Text('Change SuperAdmin Password'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


