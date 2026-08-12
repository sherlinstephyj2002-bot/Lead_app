import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/company_provider.dart';
import '../../models/company_model.dart';
import 'company_details_screen.dart';

class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final TextEditingController _searchController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyProvider = Provider.of<CompanyProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(32),
      color: theme.colorScheme.surface.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter and Search Header Card
          _buildFilterHeader(context, companyProvider),
          const SizedBox(height: 24),

          // Main Content Panel
          Expanded(
            child: _buildWorkspaceBody(context, companyProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(BuildContext context, CompanyProvider provider) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Search Input
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by company name or ID...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => provider.setSearchQuery(val),
              ),
            ),
            const SizedBox(width: 16),

            // Status Filter Dropdown
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: provider.statusFilter,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                ],
                onChanged: (val) {
                  if (val != null) provider.setStatusFilter(val);
                },
              ),
            ),
            const SizedBox(width: 16),

            // Subscription Plan Filter Dropdown
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                value: provider.subscriptionFilter,
                decoration: const InputDecoration(
                  labelText: 'Subscription Plan',
                  prefixIcon: Icon(Icons.card_membership_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Plans')),
                  DropdownMenuItem(value: 'Free', child: Text('Free')),
                  DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise')),
                ],
                onChanged: (val) {
                  if (val != null) provider.setSubscriptionFilter(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceBody(BuildContext context, CompanyProvider provider) {
    final theme = Theme.of(context);

    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching companies and metrics...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Load Failed',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.fetchCompanies(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    final filtered = provider.filteredCompanies;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_rounded, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No Companies Found',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No registered organization matching the selected filters is available.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            if (provider.searchQuery.isNotEmpty ||
                provider.statusFilter != 'All' ||
                provider.subscriptionFilter != 'All')
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.setSearchQuery('');
                  provider.setStatusFilter('All');
                  provider.setSubscriptionFilter('All');
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Reset Filters'),
              ),
          ],
        ),
      );
    }

    // Paginated list calculation
    final totalRecords = filtered.length;
    final startIndex = provider.currentPage * provider.rowsPerPage;
    final endIndex = (startIndex + provider.rowsPerPage > totalRecords)
        ? totalRecords
        : startIndex + provider.rowsPerPage;

    final pageItems = filtered.sublist(startIndex, endIndex);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Layout
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 320,
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(theme.scaffoldBackgroundColor),
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Company Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Subscription Plan', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Employee Count', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: pageItems.map((CompanyModel company) {
                      final employeeCount = provider.getEmployeeCount(company.companyId);
                      return DataRow(
                        cells: [
                          // Company name + ID
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  company.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  company.companyId,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          // Plan Badge
                          DataCell(_buildPlanBadge(context, company.subscriptionPlan)),
                          // Status Badge
                          DataCell(_buildStatusBadge(context, company.status)),
                          // Created date
                          DataCell(Text(DateFormat.yMMMd().format(company.createdAt))),
                          // Employee Count
                          DataCell(Text('$employeeCount employees')),
                          // View details action
                          DataCell(
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CompanyDetailsScreen(
                                      company: company,
                                      employeeCount: employeeCount,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility_rounded, size: 16),
                              label: const Text('View'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                foregroundColor: theme.primaryColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // Pagination Footer
          _buildPaginationFooter(context, provider, totalRecords, startIndex, endIndex),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(BuildContext context, String plan) {
    Color color;
    switch (plan.toLowerCase().trim()) {
      case 'enterprise':
        color = const Color(0xFF8B5CF6); // Violet
        break;
      case 'standard':
        color = const Color(0xFF10B981); // Emerald Green
        break;
      case 'free':
      default:
        color = const Color(0xFF64748B); // Slate Grey
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final isActive = status.toLowerCase().trim() == 'active';
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(
    BuildContext context,
    CompanyProvider provider,
    int totalRecords,
    int startIndex,
    int endIndex,
  ) {
    final theme = Theme.of(context);
    final totalPages = (totalRecords / provider.rowsPerPage).ceil();
    final currentPageNum = provider.currentPage + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Display items details
          Text(
            'Showing ${startIndex + 1} to $endIndex of $totalRecords companies',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),

          // Pagination Controls
          Row(
            children: [
              // Rows per page picker
              const Text('Rows per page:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: provider.rowsPerPage,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (val) {
                  if (val != null) provider.setRowsPerPage(val);
                },
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(width: 24),

              // Page navigator buttons
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: provider.currentPage > 0
                    ? () => provider.setCurrentPage(provider.currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Page $currentPageNum of $totalPages',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: currentPageNum < totalPages
                    ? () => provider.setCurrentPage(provider.currentPage + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
