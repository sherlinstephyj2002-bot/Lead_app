import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/salary_component_model.dart';
import 'package:worktrack/features/company_admin/models/salary_structure_model.dart';
import 'package:worktrack/features/company_admin/models/salary_revision_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/features/company_admin/widgets/company_admin/searchable_paginated_table.dart';
import 'package:worktrack/shared/models/user_model.dart';

class SalaryStructuresScreen extends ConsumerStatefulWidget {
  const SalaryStructuresScreen({super.key});

  @override
  ConsumerState<SalaryStructuresScreen> createState() =>
      _SalaryStructuresScreenState();
}

class _SalaryStructuresScreenState
    extends ConsumerState<SalaryStructuresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

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
    final structuresAsync = ref.watch(adminSalaryStructuresProvider);
    final componentsAsync = ref.watch(adminSalaryComponentsProvider);
    final employeesAsync = ref.watch(adminEmployeesProvider);
    final revisionsAsync = ref.watch(adminAllRevisionsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salary Structure Management',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                    fontFamily: 'Outfit')),
            Text('Manage templates, employee assignments & revision history',
                style: TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'Outfit')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.read(adminSalaryStructuresProvider.notifier).loadStructures();
              ref.read(adminSalaryComponentsProvider.notifier).loadComponents();
              ref.read(adminEmployeesProvider.notifier).loadEmployees();
              ref.read(adminAllRevisionsProvider.notifier).loadAllRevisions();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Outfit', fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Salary Templates'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Salary Assignments'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Revision History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Salary Structure Templates
          _TemplatesTab(
            structuresAsync: structuresAsync,
            componentsAsync: componentsAsync,
            currencyFmt: _currencyFmt,
          ),

          // TAB 2: Employee Assignments
          _AssignmentsTab(
            employeesAsync: employeesAsync,
            structuresAsync: structuresAsync,
            currencyFmt: _currencyFmt,
          ),

          // TAB 3: Revision History
          _RevisionHistoryTab(
            revisionsAsync: revisionsAsync,
            employeesAsync: employeesAsync,
            currencyFmt: _currencyFmt,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TAB 1 - SALARY STRUCTURE TEMPLATES (STITCH DESIGN)
// ============================================================
class _TemplatesTab extends ConsumerWidget {
  final AsyncValue<List<SalaryStructureModel>> structuresAsync;
  final AsyncValue<List<SalaryComponentModel>> componentsAsync;
  final NumberFormat currencyFmt;

  const _TemplatesTab({
    required this.structuresAsync,
    required this.componentsAsync,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: structuresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
            child: Text('Error loading structures: $err',
                style: const TextStyle(color: Colors.red, fontFamily: 'Outfit'))),
        data: (structures) {
          return componentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
                child: Text('Error loading components: $err',
                    style: const TextStyle(color: Colors.red, fontFamily: 'Outfit'))),
            data: (components) {
              final activeCount = structures.where((s) => s.status == 'active').length;
              final avgGross = structures.isNotEmpty
                  ? structures.fold<double>(0, (s, item) => s + item.grossSalary) / structures.length
                  : 0.0;
              final avgNet = structures.isNotEmpty
                  ? structures.fold<double>(0, (s, item) => s + item.netSalary) / structures.length
                  : 0.0;

              return Column(
                children: [
                  // KPI Summary Row
                  LayoutBuilder(builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard(context, 'TOTAL TEMPLATES', '${structures.length}', 'Configured structures', Icons.assignment_rounded, const Color(0xFF5B4CF0), cardWidth),
                        _buildKpiCard(context, 'ACTIVE TEMPLATES', '$activeCount', 'Ready for assignment', Icons.check_circle_rounded, const Color(0xFF10B981), cardWidth),
                        _buildKpiCard(context, 'AVG GROSS SALARY', currencyFmt.format(avgGross), 'Across all templates', Icons.account_balance_wallet_rounded, const Color(0xFF0EA5E9), cardWidth),
                        _buildKpiCard(context, 'AVG NET PAY', currencyFmt.format(avgNet), 'Estimated take home', Icons.payments_rounded, const Color(0xFF8B5CF6), cardWidth),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SearchablePaginatedTable<SalaryStructureModel>(
                      items: structures,
                      searchPlaceholder: 'Search templates by name or description...',
                      searchMatcher: (struct, query) =>
                          struct.name.toLowerCase().contains(query.toLowerCase()) ||
                          struct.description.toLowerCase().contains(query.toLowerCase()),
                      headerAction: ElevatedButton.icon(
                        onPressed: () => _showStructureForm(context, ref, components),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create Template', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4CF0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                      columns: const [
                        DataColumn(label: Text('TEMPLATE NAME', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('BASIC', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('GROSS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('DEDUCTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('NET PAY', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('FORMULAS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                        DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                      ],
                      rowBuilder: (struct) {
                        return [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(struct.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(struct.status.toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              ),
                            ],
                          )),
                          DataCell(Text(
                              struct.description.isEmpty ? '--' : struct.description,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
                          DataCell(Text(currencyFmt.format(struct.basic), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0EA5E9), fontFamily: 'Outfit'))),
                          DataCell(Text(currencyFmt.format(struct.grossSalary), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit'))),
                          DataCell(Text(currencyFmt.format(struct.totalDeductions), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit'))),
                          DataCell(Text(currencyFmt.format(struct.netSalary), style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit'))),
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('G: ${struct.grossFormula}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                              Text('N: ${struct.netFormula}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                            ],
                          )),
                          DataCell(Row(
                            children: [
                              _ActionButton(
                                icon: Icons.edit_rounded,
                                color: const Color(0xFF3B82F6),
                                tooltip: 'Edit',
                                onTap: () => _showStructureForm(context, ref, components, existingStruct: struct),
                              ),
                              _ActionButton(
                                icon: Icons.delete_rounded,
                                color: const Color(0xFFEF4444),
                                tooltip: 'Archive',
                                onTap: () => _confirmDelete(context, ref, struct.structureId, struct.name),
                              ),
                            ],
                          )),
                        ];
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, String subtext, IconData icon, Color color, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                Text(subtext, style: TextStyle(fontSize: 10, color: color, fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStructureForm(
    BuildContext context,
    WidgetRef ref,
    List<SalaryComponentModel> components, {
    SalaryStructureModel? existingStruct,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SalaryStructureFormDialog(
        components: components,
        existingStruct: existingStruct,
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Archive', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to archive the salary template "$name"?', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(adminSalaryStructuresProvider.notifier).deleteStructure(id);
            },
            child: const Text('Archive', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SALARY STRUCTURE FORM DIALOG (STITCH DESIGN)
// ============================================================
class _SalaryStructureFormDialog extends ConsumerStatefulWidget {
  final List<SalaryComponentModel> components;
  final SalaryStructureModel? existingStruct;

  const _SalaryStructureFormDialog({
    required this.components,
    this.existingStruct,
  });

  @override
  ConsumerState<_SalaryStructureFormDialog> createState() =>
      _SalaryStructureFormDialogState();
}

class _SalaryStructureFormDialogState
    extends ConsumerState<_SalaryStructureFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _grossFormulaCtrl;
  late final TextEditingController _netFormulaCtrl;
  late final Map<String, TextEditingController> _componentCtrls;
  late SalaryComponentModel _basicComp;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingStruct?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existingStruct?.description ?? '');
    _grossFormulaCtrl = TextEditingController(text: widget.existingStruct?.grossFormula ?? 'Basic + Allowances');
    _netFormulaCtrl = TextEditingController(text: widget.existingStruct?.netFormula ?? 'Gross - Deductions');

    _basicComp = widget.components.firstWhere(
      (c) => c.name.toLowerCase() == 'basic',
      orElse: () => widget.components.first,
    );

    _componentCtrls = {};
    for (final comp in widget.components) {
      double initialValue = 0.0;
      if (widget.existingStruct != null) {
        if (comp.componentType == 'Earning') {
          initialValue = widget.existingStruct!.earnings[comp.componentId] ?? 0.0;
        } else {
          initialValue = widget.existingStruct!.deductions[comp.componentId] ?? 0.0;
        }
      } else {
        if (comp.calculationType == 'Flat') {
          initialValue = comp.defaultValue;
        }
      }
      _componentCtrls[comp.componentId] = TextEditingController(text: initialValue.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _grossFormulaCtrl.dispose();
    _netFormulaCtrl.dispose();
    for (final c in _componentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _basicVal => double.tryParse(_componentCtrls[_basicComp.componentId]?.text ?? '0') ?? 0.0;

  double _getCompValue(SalaryComponentModel comp) {
    final text = _componentCtrls[comp.componentId]?.text ?? '0';
    double val = double.tryParse(text) ?? 0.0;
    if (comp.calculationType == 'Percentage' && comp.componentId != _basicComp.componentId) {
      val = _basicVal * (comp.defaultValue / 100.0);
    }
    return val;
  }

  double get _totalEarnings {
    double sum = 0.0;
    for (final comp in widget.components.where((c) => c.componentType == 'Earning')) {
      sum += _getCompValue(comp);
    }
    return sum;
  }

  double get _totalDeductions {
    double sum = 0.0;
    for (final comp in widget.components.where((c) => c.componentType == 'Deduction')) {
      sum += _getCompValue(comp);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingStruct != null;
    final earnings = widget.components.where((c) => c.componentType == 'Earning').toList();
    final deductions = widget.components.where((c) => c.componentType == 'Deduction').toList();

    final gross = _totalEarnings;
    final net = gross - _totalDeductions;
    final basic = _basicVal;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: isMobile ? screenWidth * 0.95 : (screenWidth > 1000 ? 800 : screenWidth * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF5B4CF0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Salary Template' : 'Create Salary Template',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile) ...[
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Structure Name *',
                            prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontFamily: 'Outfit'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _grossFormulaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Gross Formula',
                            prefixIcon: Icon(Icons.calculate_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                            helperText: 'e.g. Basic + Allowances',
                          ),
                          style: const TextStyle(fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _netFormulaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Net Formula',
                            prefixIcon: Icon(Icons.calculate_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                            helperText: 'e.g. Gross - Deductions',
                          ),
                          style: const TextStyle(fontFamily: 'Outfit'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Structure Name *',
                                  prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontFamily: 'Outfit'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _descCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  prefixIcon: Icon(Icons.description_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontFamily: 'Outfit'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _grossFormulaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Gross Formula',
                                  prefixIcon: Icon(Icons.calculate_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                  helperText: 'e.g. Basic + Allowances',
                                ),
                                style: const TextStyle(fontFamily: 'Outfit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _netFormulaCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Net Formula',
                                  prefixIcon: Icon(Icons.calculate_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                  helperText: 'e.g. Gross - Deductions',
                                ),
                                style: const TextStyle(fontFamily: 'Outfit'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Earnings Components', icon: Icons.trending_up_rounded, color: const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      ...earnings.map((comp) => _ComponentRow(
                        comp: comp,
                        controller: _componentCtrls[comp.componentId]!,
                        basicVal: basic,
                        onChanged: () => setState(() {}),
                      )),
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Deductions Components', icon: Icons.trending_down_rounded, color: const Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      ...deductions.map((comp) => _ComponentRow(
                        comp: comp,
                        controller: _componentCtrls[comp.componentId]!,
                        basicVal: basic,
                        onChanged: () => setState(() {}),
                      )),
                      const SizedBox(height: 20),

                      _SalarySummaryCard(
                        basic: basic,
                        grossFormula: _grossFormulaCtrl.text,
                        netFormula: _netFormulaCtrl.text,
                        totalEarnings: gross,
                        totalDeductions: _totalDeductions,
                        netSalary: net,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(isEdit ? 'Update Template' : 'Save Template', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4CF0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _save,
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

    Navigator.pop(context);

    final Map<String, double> earningsMap = {};
    final Map<String, double> deductionsMap = {};
    double basicVal = 0.0;

    for (final comp in widget.components) {
      final val = _getCompValue(comp);
      if (comp.componentType == 'Earning') {
        earningsMap[comp.componentId] = val;
        if (comp.componentId == _basicComp.componentId) {
          basicVal = val;
        }
      } else {
        deductionsMap[comp.componentId] = val;
      }
    }

    final struct = SalaryStructureModel(
      structureId: widget.existingStruct?.structureId ?? const Uuid().v4(),
      companyId: user.companyId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      basic: basicVal,
      earnings: earningsMap,
      deductions: deductionsMap,
      grossFormula: _grossFormulaCtrl.text.trim(),
      netFormula: _netFormulaCtrl.text.trim(),
      status: widget.existingStruct?.status ?? 'active',
      createdAt: widget.existingStruct?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(adminSalaryStructuresProvider.notifier).saveStructure(struct);
  }
}

// ============================================================
// TAB 2 - EMPLOYEE SALARY ASSIGNMENTS (STITCH DESIGN)
// ============================================================
class _AssignmentsTab extends ConsumerWidget {
  final AsyncValue<List<UserModel>> employeesAsync;
  final AsyncValue<List<SalaryStructureModel>> structuresAsync;
  final NumberFormat currencyFmt;

  const _AssignmentsTab({
    required this.employeesAsync,
    required this.structuresAsync,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontFamily: 'Outfit'))),
        data: (employees) => structuresAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontFamily: 'Outfit'))),
          data: (structures) {
            final activeStructures = structures.where((s) => s.status == 'active').toList();
            final assignedCount = employees.where((e) => e.salaryStructureId != null && e.salaryStructureId!.isNotEmpty).length;
            final unassignedCount = employees.length - assignedCount;

            return Column(
              children: [
                // KPI Row
                LayoutBuilder(builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildKpiCard(context, 'TOTAL EMPLOYEES', '${employees.length}', 'Active workforce', Icons.people_alt_rounded, const Color(0xFF5B4CF0), cardWidth),
                      _buildKpiCard(context, 'ASSIGNED SALARY', '$assignedCount', 'Configured templates', Icons.task_alt_rounded, const Color(0xFF10B981), cardWidth),
                      _buildKpiCard(context, 'UNASSIGNED', '$unassignedCount', 'Pending assignment', Icons.warning_amber_rounded, const Color(0xFFF59E0B), cardWidth),
                      _buildKpiCard(context, 'COVERAGE RATE', '${employees.isNotEmpty ? ((assignedCount / employees.length) * 100).toStringAsFixed(0) : 0}%', 'Template coverage', Icons.pie_chart_rounded, const Color(0xFF0EA5E9), cardWidth),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                Expanded(
                  child: SearchablePaginatedTable<UserModel>(
                    items: employees,
                    searchPlaceholder: 'Search employees by name or email...',
                    searchMatcher: (emp, query) =>
                        emp.name.toLowerCase().contains(query.toLowerCase()) ||
                        emp.email.toLowerCase().contains(query.toLowerCase()),
                    columns: const [
                      DataColumn(label: Text('EMPLOYEE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                      DataColumn(label: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                      DataColumn(label: Text('CURRENT TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    ],
                    rowBuilder: (emp) {
                      return [
                        DataCell(Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                              child: Text(
                                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                                Text(emp.email, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                              ],
                            ),
                          ],
                        )),
                        DataCell(Text(emp.department ?? '--', style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'Outfit'))),
                        DataCell(emp.salaryStructureName != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  emp.salaryStructureName!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Unassigned', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              )),
                        DataCell(Row(
                          children: [
                            _ActionButton(
                              icon: Icons.assignment_ind_rounded,
                              color: const Color(0xFF5B4CF0),
                              tooltip: 'Assign Structure',
                              onTap: () => _showAssignDialog(context, ref, emp, activeStructures),
                            ),
                            if (emp.salaryStructureId != null)
                              _ActionButton(
                                icon: Icons.history_rounded,
                                color: const Color(0xFF0EA5E9),
                                tooltip: 'View History',
                                onTap: () => _showRevisionHistory(context, ref, emp),
                              ),
                          ],
                        )),
                      ];
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, String subtext, IconData icon, Color color, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                Text(subtext, style: TextStyle(fontSize: 10, color: color, fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel employee,
    List<SalaryStructureModel> structures,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignStructureDialog(
        employee: employee,
        structures: structures,
      ),
    );
  }

  void _showRevisionHistory(
      BuildContext context, WidgetRef ref, UserModel emp) {
    showDialog(
      context: context,
      builder: (ctx) => _EmployeeRevisionDialog(employee: emp),
    );
  }
}

// ============================================================
// ASSIGN STRUCTURE DIALOG (STITCH DESIGN)
// ============================================================
class _AssignStructureDialog extends ConsumerStatefulWidget {
  final UserModel employee;
  final List<SalaryStructureModel> structures;

  const _AssignStructureDialog({
    required this.employee,
    required this.structures,
  });

  @override
  ConsumerState<_AssignStructureDialog> createState() =>
      _AssignStructureDialogState();
}

class _AssignStructureDialogState
    extends ConsumerState<_AssignStructureDialog> {
  SalaryStructureModel? _selected;
  final _notesCtrl = TextEditingController();
  DateTime _effectiveDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.employee.salaryStructureId != null) {
      _selected = widget.structures.firstWhere(
        (s) => s.structureId == widget.employee.salaryStructureId,
        orElse: () => widget.structures.isNotEmpty ? widget.structures.first : widget.structures.first,
      );
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: screenWidth < 600 ? screenWidth * 0.95 : 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF5B4CF0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_ind_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign Salary Structure', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
                        Text(widget.employee.name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Salary Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SalaryStructureModel>(
                    initialValue: _selected,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.assignment_rounded, color: Color(0xFF5B4CF0)),
                    ),
                    hint: const Text('Choose a template', style: TextStyle(fontFamily: 'Outfit')),
                    items: widget.structures
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit')),
                                  Text('Net: ₹${s.netSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                  const SizedBox(height: 16),

                  const Text('Effective Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _effectiveDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _effectiveDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF5B4CF0)),
                          const SizedBox(width: 10),
                          Text(DateFormat('dd MMMM yyyy').format(_effectiveDate), style: const TextStyle(fontSize: 13, fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Revision Reason / Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Annual Appraisal, Promotion bump, Policy update...',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Assign & Log Revision', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4CF0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSaving ? null : _save,
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
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a salary template', style: TextStyle(fontFamily: 'Outfit')), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authProvider).user;

      // Log revision entry
      final revision = SalaryRevisionModel(
        revisionId: const Uuid().v4(),
        companyId: widget.employee.companyId,
        employeeId: widget.employee.uid,
        employeeName: widget.employee.name,
        structureId: _selected!.structureId,
        structureName: _selected!.name,
        basic: _selected!.basic,
        totalAllowances: _selected!.totalAllowances,
        totalDeductions: _selected!.totalDeductions,
        grossSalary: _selected!.grossSalary,
        netSalary: _selected!.netSalary,
        grossFormula: _selected!.grossFormula,
        netFormula: _selected!.netFormula,
        earnings: _selected!.earnings,
        deductions: _selected!.deductions,
        effectiveDate: _effectiveDate,
        revisedBy: user?.name ?? 'Admin',
        notes: _notesCtrl.text.trim().isEmpty ? 'Salary Assignment' : _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(adminAllRevisionsProvider.notifier).addRevision(revision);

      // Update employee record
      await ref.read(companyAdminRepositoryProvider).assignSalaryStructure(
            widget.employee.uid,
            _selected!.structureId,
            _selected!.name,
          );

      // Reload providers
      ref.read(adminEmployeesProvider.notifier).loadEmployees();
      ref.read(adminAllRevisionsProvider.notifier).loadAllRevisions();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Salary structure "${_selected!.name}" assigned to ${widget.employee.name}', style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign structure: $e', style: const TextStyle(fontFamily: 'Outfit')), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }
}

// ============================================================
// TAB 3 - REVISION HISTORY (STITCH DESIGN)
// ============================================================
class _RevisionHistoryTab extends ConsumerWidget {
  final AsyncValue<List<SalaryRevisionModel>> revisionsAsync;
  final AsyncValue<List<UserModel>> employeesAsync;
  final NumberFormat currencyFmt;

  const _RevisionHistoryTab({
    required this.revisionsAsync,
    required this.employeesAsync,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: revisionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red, fontFamily: 'Outfit'))),
        data: (revisions) {
          final thisMonthCount = revisions.where((r) => r.createdAt.month == DateTime.now().month && r.createdAt.year == DateTime.now().year).length;

          return Column(
            children: [
              // KPI Row
              LayoutBuilder(builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 800;
                final cardWidth = isWide ? (constraints.maxWidth - 36) / 3 : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard(context, 'TOTAL REVISIONS', '${revisions.length}', 'Lifetime revision logs', Icons.history_rounded, const Color(0xFF5B4CF0), cardWidth),
                    _buildKpiCard(context, 'REVISIONS THIS MONTH', '$thisMonthCount', 'Current month audit', Icons.calendar_today_rounded, const Color(0xFF0EA5E9), cardWidth),
                    _buildKpiCard(context, 'AUDIT LOG STATUS', 'Complete', 'Firestore synced', Icons.verified_rounded, const Color(0xFF10B981), cardWidth),
                  ],
                );
              }),
              const SizedBox(height: 16),

              Expanded(
                child: SearchablePaginatedTable<SalaryRevisionModel>(
                  items: revisions,
                  searchPlaceholder: 'Search by employee name or notes...',
                  searchMatcher: (rev, query) =>
                      rev.employeeName.toLowerCase().contains(query.toLowerCase()) ||
                      (rev.notes?.toLowerCase().contains(query.toLowerCase()) ?? false),
                  columns: const [
                    DataColumn(label: Text('EMPLOYEE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    DataColumn(label: Text('STRUCTURE TEMPLATE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    DataColumn(label: Text('GROSS SALARY', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    DataColumn(label: Text('EFFECTIVE DATE', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    DataColumn(label: Text('REVISED BY', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                    DataColumn(label: Text('NOTES', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'))),
                  ],
                  rowBuilder: (rev) {
                    return [
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(rev.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                          Text('Log #${rev.revisionId.length >= 6 ? rev.revisionId.substring(0, 6) : rev.revisionId}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                        ],
                      )),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF5B4CF0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(rev.structureName, style: const TextStyle(fontSize: 11, color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                      )),
                      DataCell(Text(currencyFmt.format(rev.grossSalary), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit'))),
                      DataCell(Text(DateFormat('dd MMM yyyy').format(rev.effectiveDate), style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'Outfit'))),
                      DataCell(Text(rev.revisedBy, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontFamily: 'Outfit'))),
                      DataCell(Text(rev.notes ?? '--', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
                    ];
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String title, String value, String subtext, IconData icon, Color color, double width) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                Text(subtext, style: TextStyle(fontSize: 10, color: color, fontFamily: 'Outfit')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPLOYEE REVISION HISTORY MODAL DIALOG
// ============================================================
class _EmployeeRevisionDialog extends ConsumerWidget {
  final UserModel employee;

  const _EmployeeRevisionDialog({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisionsAsync = ref.watch(salaryRevisionsProvider(employee.uid));

    final screenWidth = MediaQuery.of(context).size.width;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: screenWidth < 650 ? screenWidth * 0.95 : 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF5B4CF0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Salary Revision History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
                        Text(employee.name, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Outfit')),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: revisionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontFamily: 'Outfit')),
                  data: (revisions) {
                    if (revisions.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('No salary revisions recorded for this employee.', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: revisions.length,
                      separatorBuilder: (_, sep) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final rev = revisions[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                              child: const Icon(Icons.change_circle_rounded, color: Color(0xFF5B4CF0), size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rev.structureName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Notes: ${rev.notes ?? '--'}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                                  Text('Effective: ${DateFormat('dd MMM yyyy').format(rev.effectiveDate)} • By ${rev.revisedBy}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Outfit')),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color, fontFamily: 'Outfit')),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final SalaryComponentModel comp;
  final TextEditingController controller;
  final double basicVal;
  final VoidCallback onChanged;

  const _ComponentRow({
    required this.comp,
    required this.controller,
    required this.basicVal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBasic = comp.name.toLowerCase() == 'basic';
    final isPercentage = comp.calculationType == 'Percentage' && !isBasic;
    double computedVal = double.tryParse(controller.text) ?? 0.0;

    if (isPercentage) {
      computedVal = basicVal * (comp.defaultValue / 100.0);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: controller,
              enabled: !isPercentage,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                isDense: true,
                border: const OutlineInputBorder(),
                helperText: isPercentage ? '${comp.defaultValue}% of Basic' : null,
              ),
              style: const TextStyle(fontFamily: 'Outfit'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              '₹${computedVal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B4CF0), fontFamily: 'Outfit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalarySummaryCard extends StatelessWidget {
  final double basic;
  final String grossFormula;
  final String netFormula;
  final double totalEarnings;
  final double totalDeductions;
  final double netSalary;

  const _SalarySummaryCard({
    required this.basic,
    required this.grossFormula,
    required this.netFormula,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netSalary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Structure Preview Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Basic Pay:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text('₹${basic.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Earnings (Gross):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
              Text('₹${totalEarnings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Deductions:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
              Text('₹${totalDeductions.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontFamily: 'Outfit')),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Net Take Home:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
              Text('₹${netSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: 18),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
