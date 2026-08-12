import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Panel
          Container(
            width: 260,
            color: theme.colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: theme.primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'WORKTRACK',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                // Sidebar Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    children: [
                      _buildSidebarItem(
                        context,
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        isActive: _activeTabIndex == 0,
                        onTap: () => setState(() => _activeTabIndex = 0),
                      ),
                      _buildSidebarItem(
                        context,
                        icon: Icons.business_rounded,
                        label: 'Companies',
                        isActive: _activeTabIndex == 1,
                        onTap: () => setState(() => _activeTabIndex = 1),
                      ),
                      _buildSidebarItem(
                        context,
                        icon: Icons.subscriptions_rounded,
                        label: 'Subscriptions',
                        isActive: _activeTabIndex == 2,
                        onTap: () => setState(() => _activeTabIndex = 2),
                      ),
                      _buildSidebarItem(
                        context,
                        icon: Icons.analytics_rounded,
                        label: 'Analytics',
                        isActive: _activeTabIndex == 3,
                        onTap: () => setState(() => _activeTabIndex = 3),
                      ),
                      _buildSidebarItem(
                        context,
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        isActive: _activeTabIndex == 4,
                        onTap: () => setState(() => _activeTabIndex = 4),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Sign Out Option
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Body Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar
                Container(
                  height: 80,
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getHeaderTitle(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      // User Info Dropdown Widget
                      Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                user?.name ?? 'Super Admin',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user?.email ?? '',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          CircleAvatar(
                            backgroundColor: theme.primaryColor,
                            radius: 20,
                            child: Text(
                              (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                
                // Main Panel Workspace Screen
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

  String _getHeaderTitle() {
    switch (_activeTabIndex) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Companies Management';
      case 2:
        return 'Subscription Management';
      case 3:
        return 'Platform Analytics';
      case 4:
        return 'System Settings';
      default:
        return 'Super Admin Portal';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  Widget _buildWorkspaceContent(ThemeData theme) {
    switch (_activeTabIndex) {
      case 0:
        return _buildDashboardOverview(theme);
      case 1:
        return const CompaniesScreen();
      case 2:
        return const SubscriptionsScreen();
      case 3:
        return const AnalyticsScreen();
      case 4:
        return _buildPlaceholderScreen(
          theme,
          icon: Icons.settings_rounded,
          title: 'Portal Settings',
          description: 'Access tokens, system security guidelines, and maintenance mode parameters.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDashboardOverview(ThemeData theme) {
    final companyProvider = Provider.of<CompanyProvider>(context);
    final companies = companyProvider.companies;
    final isLoading = companyProvider.isLoading;

    final totalCompanies = companies.length;
    final activeCompanies = companies.where((c) => c.status.toLowerCase() == 'active').length;
    final inactiveCompanies = totalCompanies - activeCompanies;

    int totalEmployees = 0;
    int freePlanCompanies = 0;
    int paidPlanCompanies = 0;

    for (final company in companies) {
      totalEmployees += companyProvider.getEmployeeCount(company.companyId).toInt();
      if (company.subscriptionPlan.toLowerCase().contains('free')) {
        freePlanCompanies++;
      } else {
        paidPlanCompanies++;
      }
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Platform Metrics Overview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Metrics',
                onPressed: () => companyProvider.fetchCompanies(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview Metric Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    theme,
                    title: 'Total Companies',
                    value: '$totalCompanies',
                    icon: Icons.business_rounded,
                    color: Colors.indigoAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Active Companies',
                    value: '$activeCompanies',
                    icon: Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Inactive / Suspended',
                    value: '$inactiveCompanies',
                    icon: Icons.pause_circle_filled_rounded,
                    color: Colors.orangeAccent,
                  ),
                  _buildStatCard(
                    theme,
                    title: 'Total Employees',
                    value: '$totalEmployees',
                    icon: Icons.people_alt_rounded,
                    color: Colors.tealAccent,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Subscriptions & Platform Summary Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pie_chart_rounded, color: theme.primaryColor),
                            const SizedBox(width: 12),
                            Text(
                              'Subscription Plan Distribution',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPlanSummaryItem(
                              theme,
                              label: 'Free Plan Companies',
                              count: freePlanCompanies,
                              color: Colors.blueAccent,
                            ),
                            Container(width: 1, height: 40, color: theme.dividerColor.withValues(alpha: 0.2)),
                            _buildPlanSummaryItem(
                              theme,
                              label: 'Paid Plan Companies',
                              count: paidPlanCompanies,
                              color: Colors.purpleAccent,
                            ),
                          ],
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

  Widget _buildStatCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryItem(
    ThemeData theme, {
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPlaceholderScreen(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: isActive ? theme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
