import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/features/company_admin/models/salary_component_model.dart';
import 'package:worktrack/features/company_admin/models/salary_component_audit_log_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/company_admin/widgets/company_admin/searchable_paginated_table.dart';

class SalaryComponentsScreen extends ConsumerStatefulWidget {
  const SalaryComponentsScreen({super.key});

  @override
  ConsumerState<SalaryComponentsScreen> createState() =>
      _SalaryComponentsScreenState();
}

class _SalaryComponentsScreenState
    extends ConsumerState<SalaryComponentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'active'; // 'active' | 'archived' | 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final componentsAsync = ref.watch(adminSalaryComponentsProvider);
    final auditLogsAsync = ref.watch(adminSalaryAuditLogsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salary Components',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Configure earnings, allowances & deductions',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(adminSalaryComponentsProvider.notifier).loadComponents();
              ref.read(adminSalaryAuditLogsProvider.notifier).loadLogs();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.monetization_on_rounded, size: 18), text: 'Earnings'),
            Tab(icon: Icon(Icons.remove_circle_outline_rounded, size: 18), text: 'Deductions'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Audit Log'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Status filter bar
          _StatusFilterBar(
            current: _statusFilter,
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1 - Earnings
                _ComponentsTab(
                  componentsAsync: componentsAsync,
                  statusFilter: _statusFilter,
                  typeFilter: 'Earning',
                ),
                // Tab 2 - Deductions
                _ComponentsTab(
                  componentsAsync: componentsAsync,
                  statusFilter: _statusFilter,
                  typeFilter: 'Deduction',
                ),
                // Tab 3 - Audit Log
                _AuditLogTab(auditLogsAsync: auditLogsAsync),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: UserRoles.canModifySalaryStructure(ref.watch(authProvider).user?.role)
          ? FloatingActionButton.extended(
              heroTag: 'salaryCompFab',
              onPressed: () => _showComponentForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Component'),
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  void _showComponentForm(BuildContext context, WidgetRef ref,
      {SalaryComponentModel? existingComp}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ComponentFormDialog(existingComp: existingComp),
    );
  }
}

// ============================================================
// STATUS FILTER BAR
// ============================================================
class _StatusFilterBar extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _StatusFilterBar(
      {required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text('Show:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(width: 12),
          ...[
            ('active', 'Active', const Color(0xFF10B981)),
            ('archived', 'Archived', const Color(0xFFF59E0B)),
            ('all', 'All', const Color(0xFF4F46E5)),
          ].map((entry) {
            final (value, label, color) = entry;
            final isSelected = current == value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : color)),
                selected: isSelected,
                selectedColor: color,
                backgroundColor: color.withValues(alpha: 0.08),
                side: BorderSide(
                    color: isSelected
                        ? color
                        : color.withValues(alpha: 0.3)),
                onSelected: (_) => onChanged(value),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENTS TAB
// ============================================================
class _ComponentsTab extends ConsumerWidget {
  final AsyncValue<List<SalaryComponentModel>> componentsAsync;
  final String statusFilter;
  final String typeFilter;

  const _ComponentsTab({
    required this.componentsAsync,
    required this.statusFilter,
    required this.typeFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: componentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
            child: Text('Error: $err',
                style: const TextStyle(color: Colors.red))),
        data: (allComponents) {
          // Filter by type and status
          final filtered = allComponents.where((c) {
            final matchType = c.componentType == typeFilter;
            final matchStatus = statusFilter == 'all'
                ? true
                : c.status == statusFilter;
            return matchType && matchStatus;
          }).toList();

          final isEarning = typeFilter == 'Earning';
          final accentColor = isEarning
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444);

          // Stats row
          final activeCount =
              filtered.where((c) => c.status == 'active').length;
          final archivedCount =
              filtered.where((c) => c.status == 'archived').length;
          final mandatoryCount =
              filtered.where((c) => c.isMandatory).length;
          final taxableCount =
              filtered.where((c) => c.isTaxable).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _StatCard(
                        label: 'Active',
                        value: '$activeCount',
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded),
                    const SizedBox(width: 10),
                    _StatCard(
                        label: 'Archived',
                        value: '$archivedCount',
                        color: const Color(0xFFF59E0B),
                        icon: Icons.archive_outlined),
                    const SizedBox(width: 10),
                    _StatCard(
                        label: 'Mandatory',
                        value: '$mandatoryCount',
                        color: const Color(0xFF4F46E5),
                        icon: Icons.lock_outline_rounded),
                    const SizedBox(width: 10),
                    _StatCard(
                        label: 'Taxable',
                        value: '$taxableCount',
                        color: const Color(0xFF0EA5E9),
                        icon: Icons.receipt_long_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: SearchablePaginatedTable<SalaryComponentModel>(
                  items: filtered,
                  searchPlaceholder:
                      'Search ${typeFilter.toLowerCase()} components...',
                  searchMatcher: (comp, query) =>
                      comp.componentName
                          .toLowerCase()
                          .contains(query.toLowerCase()),
                  headerAction: ElevatedButton.icon(
                    onPressed: () => _showForm(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Component',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  columns: const [
                    DataColumn(
                        label: Text('Component',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Calc. Type',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Default Value',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Flags',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('Actions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold))),
                  ],
                  rowBuilder: (comp) {
                    final isPercentage =
                        comp.calculationType == 'Percentage';
                    final valStr = isPercentage
                        ? '${comp.defaultValue.toStringAsFixed(1)}% of Basic'
                        : '₹${comp.defaultValue.toStringAsFixed(2)}';
                    final isActive = comp.status == 'active';

                    return [
                      // Component Name
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(comp.componentName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isActive
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF94A3B8))),
                          Text('ID: ${comp.componentId.substring(0, 8)}...',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFCBD5E1))),
                        ],
                      )),

                      // Calculation Type
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPercentage
                              ? const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.1)
                              : const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPercentage ? '% Percentage' : '₹ Fixed',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPercentage
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF0EA5E9)),
                        ),
                      )),

                      // Default Value
                      DataCell(Text(valStr,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: accentColor))),

                      // Flags
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (comp.isMandatory)
                            _FlagBadge(
                                label: 'Mandatory',
                                color: const Color(0xFF4F46E5)),
                          if (comp.isTaxable)
                            _FlagBadge(
                                label: 'Taxable',
                                color: const Color(0xFFF59E0B)),
                          if (!comp.isMandatory && !comp.isTaxable)
                            const Text('—',
                                style: TextStyle(
                                    color: Color(0xFFCBD5E1))),
                        ],
                      )),

                      // Status badge
                      DataCell(_StatusBadge(status: comp.status)),

                      // Actions
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive) ...[
                            _ActionBtn(
                              icon: Icons.edit_rounded,
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Edit',
                              onTap: () =>
                                  _showForm(context, ref, existing: comp),
                            ),
                            _ActionBtn(
                              icon: Icons.archive_rounded,
                              color: const Color(0xFFF59E0B),
                              tooltip: 'Archive',
                              onTap: () => _confirmArchive(
                                  context, ref, comp),
                            ),
                          ] else ...[
                            _ActionBtn(
                              icon: Icons.restore_rounded,
                              color: const Color(0xFF10B981),
                              tooltip: 'Restore',
                              onTap: () => _confirmRestore(
                                  context, ref, comp),
                            ),
                          ],
                        ],
                      )),
                    ];
                  },
                  emptyState: _EmptyState(
                      type: typeFilter, status: statusFilter),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {SalaryComponentModel? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ComponentFormDialog(
          existingComp: existing, preselectedType: typeFilter),
    );
  }

  void _confirmArchive(
      BuildContext context, WidgetRef ref, SalaryComponentModel comp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.archive_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          const Text('Archive Component'),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
            children: [
              const TextSpan(text: 'Archive salary component '),
              TextSpan(
                  text: '"${comp.componentName}"',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(
                  text:
                      '?\n\nIt will be hidden from active use but can be restored anytime.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(adminSalaryComponentsProvider.notifier)
                  .archiveComponent(comp.componentId, comp.componentName);
            },
            icon: const Icon(Icons.archive_rounded, size: 16),
            label: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(
      BuildContext context, WidgetRef ref, SalaryComponentModel comp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.restore_rounded, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          const Text('Restore Component'),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
            children: [
              const TextSpan(text: 'Restore '),
              TextSpan(
                  text: '"${comp.componentName}"',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ' to active status?'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(adminSalaryComponentsProvider.notifier)
                  .restoreComponent(comp.componentId, comp.componentName);
            },
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENT FORM DIALOG
// ============================================================
class _ComponentFormDialog extends ConsumerStatefulWidget {
  final SalaryComponentModel? existingComp;
  final String? preselectedType;

  const _ComponentFormDialog({this.existingComp, this.preselectedType});

  @override
  ConsumerState<_ComponentFormDialog> createState() =>
      _ComponentFormDialogState();
}

class _ComponentFormDialogState
    extends ConsumerState<_ComponentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _valueCtrl;
  late String _selectedType;
  late String _selectedCalc;
  late bool _isMandatory;
  late bool _isTaxable;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final comp = widget.existingComp;
    _nameCtrl = TextEditingController(text: comp?.componentName ?? '');
    _valueCtrl = TextEditingController(
        text: comp?.defaultValue.toStringAsFixed(2) ?? '0.00');
    _selectedType =
        comp?.componentType ?? widget.preselectedType ?? 'Earning';
    _selectedCalc = comp?.calculationType ?? 'Fixed';
    _isMandatory = comp?.isMandatory ?? false;
    _isTaxable = comp?.isTaxable ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existingComp != null;
  Color get _accentColor => _selectedType == 'Earning'
      ? const Color(0xFF10B981)
      : const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isEdit
                      ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                      : [const Color(0xFF10B981), const Color(0xFF0EA5E9)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEdit
                        ? Icons.edit_rounded
                        : Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? 'Edit Salary Component'
                              : 'Add Salary Component',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          _isEdit
                              ? 'Update component configuration'
                              : 'Define a new earnings or deduction component',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Component Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Component Name *',
                          hintText: 'e.g. House Rent Allowance',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _accentColor),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Component name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Type + Calculation Type row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Component Type',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                // Segmented toggle
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      _TypeToggle(
                                        label: 'Earning',
                                        icon: Icons.trending_up_rounded,
                                        isSelected:
                                            _selectedType == 'Earning',
                                        color: const Color(0xFF10B981),
                                        onTap: () => setState(() =>
                                            _selectedType = 'Earning'),
                                      ),
                                      _TypeToggle(
                                        label: 'Deduction',
                                        icon:
                                            Icons.trending_down_rounded,
                                        isSelected:
                                            _selectedType == 'Deduction',
                                        color: const Color(0xFFEF4444),
                                        onTap: () => setState(() =>
                                            _selectedType = 'Deduction'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Calculation Type',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF374151))),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      _TypeToggle(
                                        label: 'Fixed',
                                        icon: Icons.attach_money_rounded,
                                        isSelected:
                                            _selectedCalc == 'Fixed',
                                        color: const Color(0xFF0EA5E9),
                                        onTap: () => setState(
                                            () => _selectedCalc = 'Fixed'),
                                      ),
                                      _TypeToggle(
                                        label: 'Percentage',
                                        icon: Icons.percent_rounded,
                                        isSelected:
                                            _selectedCalc == 'Percentage',
                                        color: const Color(0xFF8B5CF6),
                                        onTap: () => setState(() =>
                                            _selectedCalc = 'Percentage'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Default Value field
                      TextFormField(
                        controller: _valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _selectedCalc == 'Percentage'
                              ? 'Percentage Rate (%) *'
                              : 'Default Fixed Amount (₹) *',
                          prefixIcon: Icon(
                            _selectedCalc == 'Percentage'
                                ? Icons.percent_rounded
                                : Icons.currency_rupee_rounded,
                          ),
                          suffixText:
                              _selectedCalc == 'Percentage' ? '%' : '₹',
                          border: const OutlineInputBorder(),
                          helperText: _selectedCalc == 'Percentage'
                              ? 'e.g. 40 means 40% of Basic'
                              : 'Fixed monthly amount in rupees',
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: _accentColor),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Value is required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Flags section
                      const Text('Component Flags',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _FlagTile(
                              icon: Icons.lock_outline_rounded,
                              color: const Color(0xFF4F46E5),
                              title: 'Mandatory Component',
                              subtitle:
                                  'Cannot be removed from salary structures',
                              value: _isMandatory,
                              onChanged: (v) =>
                                  setState(() => _isMandatory = v),
                            ),
                            const Divider(height: 1),
                            _FlagTile(
                              icon: Icons.receipt_long_outlined,
                              color: const Color(0xFFF59E0B),
                              title: 'Taxable Component',
                              subtitle:
                                  'Included in TDS/income tax calculation',
                              value: _isTaxable,
                              onChanged: (v) =>
                                  setState(() => _isTaxable = v),
                            ),
                          ],
                        ),
                      ),

                      // Preview card
                      const SizedBox(height: 20),
                      _ComponentPreviewCard(
                        name: _nameCtrl.text.trim().isEmpty
                            ? 'Component Preview'
                            : _nameCtrl.text.trim(),
                        type: _selectedType,
                        calcType: _selectedCalc,
                        value: double.tryParse(_valueCtrl.text) ?? 0.0,
                        isMandatory: _isMandatory,
                        isTaxable: _isTaxable,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(_isEdit
                            ? Icons.save_rounded
                            : Icons.add_circle_rounded),
                    label: Text(_isEdit ? 'Update Component' : 'Add Component'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final comp = SalaryComponentModel(
        componentId:
            widget.existingComp?.componentId ?? const Uuid().v4(),
        companyId: user.companyId,
        componentName: _nameCtrl.text.trim(),
        componentType: _selectedType,
        calculationType: _selectedCalc,
        defaultValue: double.parse(_valueCtrl.text.trim()),
        isMandatory: _isMandatory,
        isTaxable: _isTaxable,
        status: widget.existingComp?.status ?? 'active',
        createdAt: widget.existingComp?.createdAt ?? now,
        updatedAt: now,
      );

      await ref
          .read(adminSalaryComponentsProvider.notifier)
          .saveComponent(comp);

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ============================================================
// AUDIT LOG TAB
// ============================================================
class _AuditLogTab extends StatelessWidget {
  final AsyncValue<List<SalaryComponentAuditLogModel>> auditLogsAsync;

  const _AuditLogTab({required this.auditLogsAsync});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: auditLogsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.red))),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded,
                      size: 64, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 16),
                  Text('No audit logs yet.',
                      style: TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 16)),
                  SizedBox(height: 8),
                  Text(
                      'Create, edit or archive components to see the activity trail here.',
                      style: TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return SearchablePaginatedTable<SalaryComponentAuditLogModel>(
            items: logs,
            searchPlaceholder: 'Search logs by component or action...',
            searchMatcher: (log, q) =>
                log.componentName
                    .toLowerCase()
                    .contains(q.toLowerCase()) ||
                log.action.toLowerCase().contains(q.toLowerCase()) ||
                log.performedBy
                    .toLowerCase()
                    .contains(q.toLowerCase()),
            columns: const [
              DataColumn(
                  label: Text('Action',
                      style:
                          TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Component',
                      style:
                          TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Details',
                      style:
                          TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Performed By',
                      style:
                          TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(
                  label: Text('Timestamp',
                      style:
                          TextStyle(fontWeight: FontWeight.bold))),
            ],
            rowBuilder: (log) {
              final actionColor = _actionColor(log.action);
              return [
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_actionIcon(log.action),
                          size: 12, color: actionColor),
                      const SizedBox(width: 4),
                      Text(log.action,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: actionColor)),
                    ],
                  ),
                )),
                DataCell(Text(log.componentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(SizedBox(
                  width: 240,
                  child: Text(log.details,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(log.performedBy,
                        style: const TextStyle(fontSize: 12)),
                  ],
                )),
                DataCell(Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(log.timestamp),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)))),
              ];
            },
          );
        },
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'Create':
        return const Color(0xFF10B981);
      case 'Edit':
        return const Color(0xFF4F46E5);
      case 'Archive':
        return const Color(0xFFF59E0B);
      case 'Restore':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'Create':
        return Icons.add_circle_outline_rounded;
      case 'Edit':
        return Icons.edit_rounded;
      case 'Archive':
        return Icons.archive_rounded;
      case 'Restore':
        return Icons.restore_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

// ============================================================
// SHARED HELPER WIDGETS
// ============================================================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Archived',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FlagBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: isSelected ? Colors.white : color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FlagTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _ComponentPreviewCard extends StatelessWidget {
  final String name;
  final String type;
  final String calcType;
  final double value;
  final bool isMandatory;
  final bool isTaxable;

  const _ComponentPreviewCard({
    required this.name,
    required this.type,
    required this.calcType,
    required this.value,
    required this.isMandatory,
    required this.isTaxable,
  });

  @override
  Widget build(BuildContext context) {
    final isEarning = type == 'Earning';
    final isPercentage = calcType == 'Percentage';
    final color = isEarning
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.05),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isEarning
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Preview',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color)),
          const SizedBox(height: 4),
          Row(
            children: [
              _PreviewChip(
                  label: type,
                  color: color),
              const SizedBox(width: 6),
              _PreviewChip(
                  label: calcType,
                  color: const Color(0xFF64748B)),
              if (isMandatory) ...[
                const SizedBox(width: 6),
                _PreviewChip(
                    label: 'Mandatory',
                    color: const Color(0xFF4F46E5)),
              ],
              if (isTaxable) ...[
                const SizedBox(width: 6),
                _PreviewChip(
                    label: 'Taxable',
                    color: const Color(0xFFF59E0B)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPercentage
                ? '${value.toStringAsFixed(1)}% of Basic Salary'
                : '₹${value.toStringAsFixed(2)} per month',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final String label;
  final Color color;

  const _PreviewChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String type;
  final String status;

  const _EmptyState({required this.type, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'Earning'
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 56,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            status == 'archived'
                ? 'No archived ${type.toLowerCase()} components'
                : 'No ${type.toLowerCase()} components yet',
            style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            status == 'archived'
                ? 'Archive some components to see them here'
                : 'Click "Add Component" to create your first ${type.toLowerCase()} component',
            style: const TextStyle(
                color: Color(0xFFCBD5E1), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
