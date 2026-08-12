import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/company_model.dart';
import '../../providers/company_provider.dart';
import '../../providers/auth_provider.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _planFilter = 'All';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompanies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSubscriptionDetails(BuildContext context, CompanyModel company, int empCount) {
    final theme = Theme.of(context);
    final isFree = company.subscriptionPlan.toLowerCase().contains('free');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.colorScheme.surface,
        child: Container(
          width: 650,
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.card_membership_rounded, color: theme.primaryColor, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          '${company.name} — Subscription Details',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // Tenant Information Summary
                Text('Tenant Information', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 12),
                _buildModalRow('SaaS Company ID', company.companyId),
                _buildModalRow('Company Name', company.name),
                _buildModalRow('Current Plan', company.subscriptionPlan),
                _buildModalRow('Subscription Status', company.status),
                _buildModalRow('Registration Date', DateFormat('MMM dd, yyyy').format(company.createdAt)),
                _buildModalRow('Renewal / Expiry Date', DateFormat('MMM dd, yyyy').format(company.createdAt.add(const Duration(days: 365)))),
                const SizedBox(height: 20),

                // Resource Usage & Limits
                Text('Resource Usage & Limits', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 12),
                _buildModalRow('Employee Usage', '$empCount / ${isFree ? 10 : (company.subscriptionPlan == 'Standard' ? 50 : 'Unlimited')}'),
                _buildModalRow('Storage Usage', '0 MB / ${isFree ? '1 GB' : '50 GB'}'),
                _buildModalRow('GeoFence Module', company.geofenceLat != null ? 'Configured (${company.geofenceRadius}m)' : 'Not Configured'),
                const SizedBox(height: 20),

                // Enabled Modules
                Text('Enabled Modules', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildModuleChip('Employees'),
                    _buildModuleChip('Attendance'),
                    _buildModuleChip('Leave'),
                    _buildModuleChip('Payroll'),
                    if (!isFree) _buildModuleChip('Leads'),
                    if (!isFree) _buildModuleChip('Orders'),
                  ],
                ),
                const SizedBox(height: 24),

                // Billing & Transaction Information
                Text('Billing & Payment History', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: Colors.white70),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No billing transactions available for this tenant.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModuleChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.indigo.withValues(alpha: 0.2),
      side: BorderSide(color: Colors.indigo.withValues(alpha: 0.4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyProvider = Provider.of<CompanyProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final companies = companyProvider.companies;
    final isLoading = companyProvider.isLoading;

    final adminEmail = authProvider.userModel?.email ?? 'super_admin@platform.com';

    // Compute Subscription Overview Metrics
    final totalCompanies = companies.length;
    final activeSubs = companies.where((c) => c.status.toLowerCase() == 'active').length;
    final freePlanComps = companies.where((c) => c.subscriptionPlan.toLowerCase().contains('free')).length;
    final paidPlanComps = totalCompanies - freePlanComps;
    final trialComps = companies.where((c) => c.subscriptionPlan.toLowerCase().contains('trial')).length;
    final suspendedComps = companies.where((c) => c.status.toLowerCase() == 'suspended').length;
    final expiringSoon = companies.where((c) {
      final days = DateTime.now().difference(c.createdAt).inDays;
      return days > 330;
    }).length;

    // Filter Companies List
    final filteredCompanies = companies.where((c) {
      final matchesSearch = _searchController.text.isEmpty ||
          c.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          c.companyId.toLowerCase().contains(_searchController.text.toLowerCase());

      final matchesPlan = _planFilter == 'All' || c.subscriptionPlan.toLowerCase() == _planFilter.toLowerCase();
      final matchesStatus = _statusFilter == 'All' || c.status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesSearch && matchesPlan && matchesStatus;
    }).toList();

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
                            'SaaS Subscription Management',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Monitor tenant billing plans, quotas, and subscription lifecycle across WorkTrack.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh Subscriptions',
                        onPressed: () => companyProvider.fetchCompanies(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // A. Subscription Overview Cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1100 ? 6 : (constraints.maxWidth > 700 ? 3 : 2);
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildOverviewTile(theme, 'Total Companies', '$totalCompanies', Icons.business_rounded, Colors.indigoAccent),
                          _buildOverviewTile(theme, 'Active Subscriptions', '$activeSubs', Icons.check_circle_rounded, Colors.greenAccent),
                          _buildOverviewTile(theme, 'Free Plan Companies', '$freePlanComps', Icons.card_giftcard_rounded, Colors.blueAccent),
                          _buildOverviewTile(theme, 'Trial Companies', '$trialComps', Icons.workspace_premium_rounded, Colors.tealAccent),
                          _buildOverviewTile(theme, 'Paid Plan Companies', '$paidPlanComps', Icons.star_rounded, Colors.purpleAccent),
                          _buildOverviewTile(theme, 'Expiring Soon', '$expiringSoon', Icons.timer_rounded, Colors.amberAccent),
                          _buildOverviewTile(theme, 'Suspended', '$suspendedComps', Icons.pause_circle_rounded, Colors.redAccent),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // B. Subscription Plans Matrix Section
                  Text('Platform Available Subscription Plans', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.25,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildPlanCard(theme, name: 'Free Tier', price: '\$0 / mo', limit: '10 Employees', storage: '1 GB Storage', color: Colors.blueAccent, modules: ['Employees', 'Attendance', 'Leave']),
                          _buildPlanCard(theme, name: 'Basic Plan', price: '\$29 / mo', limit: '25 Employees', storage: '10 GB Storage', color: Colors.tealAccent, modules: ['Core HR', 'Attendance', 'Leave']),
                          _buildPlanCard(theme, name: 'Standard Plan', price: '\$79 / mo', limit: '50 Employees', storage: '25 GB Storage', color: Colors.indigoAccent, modules: ['Core HR', 'Attendance', 'Payroll', 'Leads']),
                          _buildPlanCard(theme, name: 'Enterprise Plan', price: '\$199 / mo', limit: 'Unlimited', storage: '100 GB Storage', color: Colors.purpleAccent, modules: ['Full SaaS Suite', 'All Modules', 'API Access']),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // C. Company Subscription Table Section
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tenant Subscription Records', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 220,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        hintText: 'Search company...',
                                        prefixIcon: Icon(Icons.search_rounded),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  DropdownButton<String>(
                                    value: _planFilter,
                                    onChanged: (val) => setState(() => _planFilter = val!),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text('Plan: All')),
                                      DropdownMenuItem(value: 'Free', child: Text('Plan: Free')),
                                      DropdownMenuItem(value: 'Standard', child: Text('Plan: Standard')),
                                      DropdownMenuItem(value: 'Enterprise', child: Text('Plan: Enterprise')),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          filteredCompanies.isEmpty
                              ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No matching company subscription records found.')))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Company Name')),
                                      DataColumn(label: Text('SaaS Tenant ID')),
                                      DataColumn(label: Text('Plan')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Employee Usage')),
                                      DataColumn(label: Text('Registration Date')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: filteredCompanies.map((c) {
                                      final empCount = companyProvider.getEmployeeCount(c.companyId);
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                          DataCell(Text(c.companyId)),
                                          DataCell(_buildPlanBadge(c.subscriptionPlan)),
                                          DataCell(_buildStatusBadge(c.status)),
                                          DataCell(Text('$empCount users')),
                                          DataCell(Text(DateFormat('MMM dd, yyyy').format(c.createdAt))),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.visibility_outlined, size: 20),
                                                  tooltip: 'View Subscription Details',
                                                  onPressed: () => _showSubscriptionDetails(context, c, empCount),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                                  tooltip: 'Change Subscription Plan',
                                                  onPressed: () {
                                                    companyProvider.upgradeCompanyPlan(
                                                      companyId: c.companyId,
                                                      companyName: c.name,
                                                      planName: c.subscriptionPlan == 'Free' ? 'Standard' : 'Enterprise',
                                                      performedBy: adminEmail,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
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

  Widget _buildOverviewTile(ThemeData theme, String label, String value, IconData icon, Color color) {
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

  Widget _buildPlanCard(
    ThemeData theme, {
    required String name,
    required String price,
    required String limit,
    required String storage,
    required Color color,
    required List<String> modules,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
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
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text('• $limit', style: theme.textTheme.bodySmall),
            Text('• $storage', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: modules.map((m) => Chip(
                label: Text(m, style: const TextStyle(fontSize: 9)),
                padding: EdgeInsets.zero,
                backgroundColor: color.withValues(alpha: 0.1),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
      ),
      child: Text(plan, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isAct = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAct ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAct ? Colors.greenAccent : Colors.orangeAccent)),
    );
  }
}
