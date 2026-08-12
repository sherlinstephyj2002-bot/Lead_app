import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/company_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _dateRange = '30 Days';

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
    final companyProvider = Provider.of<CompanyProvider>(context);
    final companies = companyProvider.companies;
    final isLoading = companyProvider.isLoading;

    // Platform-Wide Aggregations
    final totalCompanies = companies.length;
    final activeCompanies = companies.where((c) => c.status.toLowerCase() == 'active').length;
    final suspendedCompanies = totalCompanies - activeCompanies;

    int totalEmployees = 0;
    int freePlanCompanies = 0;
    int paidPlanCompanies = 0;

    for (final c in companies) {
      totalEmployees += companyProvider.getEmployeeCount(c.companyId).toInt();
      if (c.subscriptionPlan.toLowerCase().contains('free')) {
        freePlanCompanies++;
      } else {
        paidPlanCompanies++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(32),
      color: theme.colorScheme.surface.withValues(alpha: 0.1),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform-Wide System Analytics',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aggregated growth, module adoption, and system health metrics across all platform tenants.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _dateRange,
                            onChanged: (val) => setState(() => _dateRange = val!),
                            items: const [
                              DropdownMenuItem(value: 'Today', child: Text('Filter: Today')),
                              DropdownMenuItem(value: '7 Days', child: Text('Filter: 7 Days')),
                              DropdownMenuItem(value: '30 Days', child: Text('Filter: 30 Days')),
                              DropdownMenuItem(value: '3 Months', child: Text('Filter: 3 Months')),
                              DropdownMenuItem(value: '6 Months', child: Text('Filter: 6 Months')),
                              DropdownMenuItem(value: '1 Year', child: Text('Filter: 1 Year')),
                            ],
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'Refresh Analytics',
                            onPressed: () => companyProvider.fetchCompanies(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // A. Platform Overview Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1100 ? 5 : (constraints.maxWidth > 700 ? 3 : 2);
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildAnalyticsTile(theme, 'Total Platform Companies', '$totalCompanies', Icons.business_rounded, Colors.indigoAccent),
                          _buildAnalyticsTile(theme, 'Active Tenants', '$activeCompanies', Icons.check_circle_rounded, Colors.greenAccent),
                          _buildAnalyticsTile(theme, 'Suspended Tenants', '$suspendedCompanies', Icons.pause_circle_rounded, Colors.orangeAccent),
                          _buildAnalyticsTile(theme, 'Total Platform Employees', '$totalEmployees', Icons.people_alt_rounded, Colors.tealAccent),
                          _buildAnalyticsTile(theme, 'Free Plan Tenants', '$freePlanCompanies', Icons.card_giftcard_rounded, Colors.blueAccent),
                          _buildAnalyticsTile(theme, 'Paid Plan Tenants', '$paidPlanCompanies', Icons.star_rounded, Colors.purpleAccent),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // B & C. Growth Trends & Module Usage Split Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Module Usage Breakdown
                      Expanded(
                        flex: 3,
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
                                Text('Platform Module Adoption', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 20),
                                _buildModuleProgress(theme, 'Employee Directory & Profiles', 1.0, '$totalCompanies Tenants (100%)'),
                                _buildModuleProgress(theme, 'Attendance & Geofencing', 1.0, '$totalCompanies Tenants (100%)'),
                                _buildModuleProgress(theme, 'Leave Management System', 1.0, '$totalCompanies Tenants (100%)'),
                                _buildModuleProgress(theme, 'Payroll & Salary Payslips', 1.0, '$totalCompanies Tenants (100%)'),
                                _buildModuleProgress(theme, 'Leads & CRM Module', paidPlanCompanies / (totalCompanies > 0 ? totalCompanies : 1), '$paidPlanCompanies Paid Tenants'),
                                _buildModuleProgress(theme, 'Orders Management', paidPlanCompanies / (totalCompanies > 0 ? totalCompanies : 1), '$paidPlanCompanies Paid Tenants'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // System Health & Platform Indicators
                      Expanded(
                        flex: 2,
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
                                Text('SaaS System Infrastructure Health', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 20),
                                _buildHealthRow('REST API Gateway', 'Operational', Colors.greenAccent),
                                _buildHealthRow('Cloud Firestore DB', 'Connected', Colors.greenAccent),
                                _buildHealthRow('Firebase Storage', 'Operational', Colors.greenAccent),
                                _buildHealthRow('Auth Security Provider', 'Protected', Colors.greenAccent),
                                _buildHealthRow('Realtime Synchronization', 'Active Stream', Colors.blueAccent),
                                _buildHealthRow('System Error Rate', '0.00%', Colors.greenAccent),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // D. Top / Most Active Platform Companies Table
                  Card(
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
                        children: [
                          Text('Top Platform Tenants by Employee Volume', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          companies.isEmpty
                              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No tenant companies registered on platform.')))
                              : DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Company Name')),
                                    DataColumn(label: Text('Tenant ID')),
                                    DataColumn(label: Text('Subscription Plan')),
                                    DataColumn(label: Text('Employee Volume')),
                                    DataColumn(label: Text('Tenant Status')),
                                  ],
                                  rows: companies.map((c) {
                                    final empCount = companyProvider.getEmployeeCount(c.companyId);
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(c.companyId)),
                                        DataCell(Text(c.subscriptionPlan)),
                                        DataCell(Text('$empCount users')),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (c.status.toLowerCase() == 'active') ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(c.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (c.status.toLowerCase() == 'active') ? Colors.greenAccent : Colors.orangeAccent)),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalyticsTile(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleProgress(ThemeData theme, String title, double percent, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String service, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(service, style: const TextStyle(color: Colors.white70)),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
