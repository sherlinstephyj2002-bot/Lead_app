import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:worktrack/shared/utils/app_formatter.dart';

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
  late final TextEditingController _monthlySalaryCtrl;
  late final TextEditingController _annualSalaryCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _incentiveCtrl;
  late final FocusNode _monthlyFocusNode;
  late final FocusNode _annualFocusNode;
  bool _isSyncing = false;

  late final Map<String, TextEditingController> _componentCtrls;
  late List<SalaryComponentModel> _normalizedComponents;
  late SalaryComponentModel _basicComp;

  List<SalaryComponentModel> _buildNormalizedComponents(List<SalaryComponentModel> sourceComps) {
    final list = sourceComps.where((c) {
      final n = c.name.toLowerCase().trim();
      return n != 'travel' && n != 'food' && n != 'other earnings' && n != 'bonus' && n != 'da';
    }).map((c) {
      final n = c.name.toLowerCase().trim();
      if (n == 'hra') {
        return c.copyWith(calculationType: 'Percentage', defaultValue: 40.0);
      } else if (n.contains('medical')) {
        return c.copyWith(calculationType: 'Percentage', defaultValue: 5.0);
      } else if (n == 'incentive') {
        return c.copyWith(calculationType: 'Percentage', defaultValue: 0.0);
      } else if (n == 'pf') {
        return c.copyWith(calculationType: 'Percentage', defaultValue: 12.0);
      } else if (n == 'esi') {
        return c.copyWith(calculationType: 'Percentage', defaultValue: 0.75);
      }
      return c;
    }).toList();

    if (!list.any((c) => c.name.toLowerCase().contains('travel & food'))) {
      list.add(SalaryComponentModel(
        componentId: 'travel_food_allowance',
        componentName: 'Travel & Food Allowance',
        componentType: 'Earning',
        calculationType: 'Percentage',
        defaultValue: 10.0,
        companyId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    if (!list.any((c) => c.name.toLowerCase().contains('other earnings & bonus'))) {
      list.add(SalaryComponentModel(
        componentId: 'other_earnings_bonus',
        componentName: 'Other Earnings & Bonus',
        componentType: 'Earning',
        calculationType: 'Percentage',
        defaultValue: 10.0,
        companyId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingStruct?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existingStruct?.description ?? '');
    
    final initialMonthly = widget.existingStruct?.monthlySalary ?? (widget.existingStruct?.basic ?? 15000.0);
    final initialAnnual = widget.existingStruct?.annualSalary ?? (initialMonthly * 12);
    final initialBonus = widget.existingStruct?.bonus ?? 0.0;
    final initialIncentive = widget.existingStruct?.incentive ?? 0.0;

    _monthlySalaryCtrl = TextEditingController(text: initialMonthly % 1 == 0 ? initialMonthly.toInt().toString() : initialMonthly.toStringAsFixed(2));
    _annualSalaryCtrl = TextEditingController(text: initialAnnual % 1 == 0 ? initialAnnual.toInt().toString() : initialAnnual.toStringAsFixed(2));
    _bonusCtrl = TextEditingController(text: initialBonus % 1 == 0 ? initialBonus.toInt().toString() : initialBonus.toStringAsFixed(2));
    _incentiveCtrl = TextEditingController(text: initialIncentive % 1 == 0 ? initialIncentive.toInt().toString() : initialIncentive.toStringAsFixed(2));

    _monthlyFocusNode = FocusNode();
    _annualFocusNode = FocusNode();

    _monthlySalaryCtrl.addListener(_onMonthlySalaryChanged);
    _annualSalaryCtrl.addListener(_onAnnualSalaryChanged);

    _normalizedComponents = _buildNormalizedComponents(widget.components);

    _basicComp = _normalizedComponents.firstWhere(
      (c) => c.name.toLowerCase().contains('basic'),
      orElse: () => _normalizedComponents.first,
    );

    _componentCtrls = {};
    for (final comp in _normalizedComponents) {
      double initialValue = comp.defaultValue;

      if (widget.existingStruct != null) {
        final struct = widget.existingStruct!;
        if (struct.componentPercentages.containsKey(comp.componentId)) {
          initialValue = struct.componentPercentages[comp.componentId]!;
        } else if (comp.componentId == _basicComp.componentId) {
          initialValue = struct.basic > 0 ? struct.basic : initialMonthly;
        } else if (comp.calculationType == 'Percentage') {
          final rupeeVal = comp.componentType == 'Earning'
              ? (struct.earnings[comp.componentId] ?? 0.0)
              : (struct.deductions[comp.componentId] ?? 0.0);
          if (struct.basic > 0 && rupeeVal > 0) {
            initialValue = (rupeeVal / struct.basic) * 100.0;
          }
        } else {
          initialValue = comp.componentType == 'Earning'
              ? (struct.earnings[comp.componentId] ?? comp.defaultValue)
              : (struct.deductions[comp.componentId] ?? comp.defaultValue);
        }
      } else {
        if (comp.componentId == _basicComp.componentId && comp.defaultValue == 0.0) {
          initialValue = initialMonthly;
        }
      }

      final textVal = initialValue % 1 == 0 ? initialValue.toInt().toString() : initialValue.toString();
      _componentCtrls[comp.componentId] = TextEditingController(text: textVal);
    }
  }

  void _onMonthlySalaryChanged() {
    if (_monthlyFocusNode.hasFocus && !_isSyncing) {
      _isSyncing = true;
      final monthly = double.tryParse(_monthlySalaryCtrl.text) ?? 0.0;
      final annual = monthly * 12;
      _annualSalaryCtrl.text = annual % 1 == 0 ? annual.toInt().toString() : annual.toStringAsFixed(2);
      if (_componentCtrls.containsKey(_basicComp.componentId)) {
        _componentCtrls[_basicComp.componentId]!.text = monthly % 1 == 0 ? monthly.toInt().toString() : monthly.toStringAsFixed(2);
      }
      _isSyncing = false;
      if (mounted) setState(() {});
    }
  }

  void _onAnnualSalaryChanged() {
    if (_annualFocusNode.hasFocus && !_isSyncing) {
      _isSyncing = true;
      final annual = double.tryParse(_annualSalaryCtrl.text) ?? 0.0;
      final monthly = annual / 12;
      _monthlySalaryCtrl.text = monthly % 1 == 0 ? monthly.toInt().toString() : monthly.toStringAsFixed(2);
      if (_componentCtrls.containsKey(_basicComp.componentId)) {
        _componentCtrls[_basicComp.componentId]!.text = monthly % 1 == 0 ? monthly.toInt().toString() : monthly.toStringAsFixed(2);
      }
      _isSyncing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _monthlySalaryCtrl.dispose();
    _annualSalaryCtrl.dispose();
    _bonusCtrl.dispose();
    _incentiveCtrl.dispose();
    _monthlyFocusNode.dispose();
    _annualFocusNode.dispose();
    for (final c in _componentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _basicVal => double.tryParse(_componentCtrls[_basicComp.componentId]?.text ?? '0') ?? 0.0;
  double get _bonusVal => double.tryParse(_bonusCtrl.text) ?? 0.0;
  double get _incentivePctVal => double.tryParse(_incentiveCtrl.text) ?? 0.0;
  double get _incentiveVal => _basicVal * (_incentivePctVal / 100.0);

  bool get _isEsiEligible => _basicVal <= 15000.0;

  double _getCompValue(SalaryComponentModel comp) {
    if (comp.componentId == _basicComp.componentId) {
      return _basicVal;
    }

    final text = _componentCtrls[comp.componentId]?.text ?? '0';
    final val = double.tryParse(text) ?? 0.0;

    if (comp.name.toLowerCase() == 'esi') {
      if (!_isEsiEligible) return 0.0;
      return _basicVal * (val / 100.0);
    }

    if (comp.calculationType == 'Percentage') {
      return _basicVal * (val / 100.0);
    }

    return val;
  }

  double get _totalAllowances {
    double sum = 0.0;
    for (final comp in _normalizedComponents.where((c) => c.componentType == 'Earning')) {
      if (comp.componentId == _basicComp.componentId) continue;
      sum += _getCompValue(comp);
    }
    return sum;
  }

  double get _totalEarnings {
    return _basicVal + _totalAllowances + _incentiveVal + _bonusVal;
  }

  double get _totalDeductions {
    double sum = 0.0;
    for (final comp in _normalizedComponents.where((c) => c.componentType == 'Deduction')) {
      sum += _getCompValue(comp);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingStruct != null;
    final earnings = _normalizedComponents.where((c) => c.componentType == 'Earning').toList();
    final deductions = _normalizedComponents.where((c) => c.componentType == 'Deduction').toList();

    final gross = _totalEarnings;
    final net = gross - _totalDeductions;
    final basic = _basicVal;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: isMobile ? screenWidth * 0.95 : (screenWidth > 1000 ? 820 : screenWidth * 0.8),
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
                          controller: _monthlySalaryCtrl,
                          focusNode: _monthlyFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Monthly Salary (₹) *',
                            prefixIcon: Icon(Icons.calendar_month_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                            helperText: 'e.g. ₹15,000',
                          ),
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final num = double.tryParse(v);
                            if (num == null || num < 0) return 'Invalid amount';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _annualSalaryCtrl,
                          focusNode: _annualFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Annual Salary (₹) *',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF5B4CF0)),
                            border: OutlineInputBorder(),
                            helperText: 'Monthly × 12',
                          ),
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final num = double.tryParse(v);
                            if (num == null || num < 0) return 'Invalid amount';
                            return null;
                          },
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
                                controller: _monthlySalaryCtrl,
                                focusNode: _monthlyFocusNode,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Monthly Salary (₹) *',
                                  prefixIcon: Icon(Icons.calendar_month_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                  helperText: 'e.g. ₹15,000',
                                ),
                                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final num = double.tryParse(v);
                                  if (num == null || num < 0) return 'Invalid amount';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _annualSalaryCtrl,
                                focusNode: _annualFocusNode,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Annual Salary (₹) *',
                                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF5B4CF0)),
                                  border: OutlineInputBorder(),
                                  helperText: 'Monthly × 12',
                                ),
                                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final num = double.tryParse(v);
                                  if (num == null || num < 0) return 'Invalid amount';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Basic Salary', icon: Icons.payments_outlined, color: const Color(0xFF0EA5E9)),
                      const SizedBox(height: 10),
                      _ComponentRow(
                        comp: _basicComp,
                        controller: _componentCtrls[_basicComp.componentId]!,
                        basicVal: basic,
                        isBasicComp: true,
                        isEsiEligible: _isEsiEligible,
                        calculatedVal: basic,
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Earnings Components', icon: Icons.trending_up_rounded, color: const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      ...earnings.where((c) => c.componentId != _basicComp.componentId).map((comp) => _ComponentRow(
                        comp: comp,
                        controller: _componentCtrls[comp.componentId]!,
                        basicVal: basic,
                        isBasicComp: false,
                        isEsiEligible: _isEsiEligible,
                        calculatedVal: _getCompValue(comp),
                        onChanged: () => setState(() {}),
                      )),
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Incentive & Bonus', icon: Icons.card_giftcard_rounded, color: const Color(0xFFF59E0B)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _incentiveCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Incentive (%)',
                                suffixText: '₹${AppFormatter.formatCurrency(_incentiveVal, includeSymbol: false)}',
                                prefixIcon: const Icon(Icons.stars_outlined, color: Color(0xFFF59E0B)),
                                border: const OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontFamily: 'Outfit'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _bonusCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Bonus Amount (₹)',
                                prefixIcon: Icon(Icons.card_giftcard_outlined, color: Color(0xFFF59E0B)),
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontFamily: 'Outfit'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _SectionHeader(title: 'Deductions Components', icon: Icons.trending_down_rounded, color: const Color(0xFFEF4444)),
                      const SizedBox(height: 10),
                      ...deductions.map((comp) => _ComponentRow(
                        comp: comp,
                        controller: _componentCtrls[comp.componentId]!,
                        basicVal: basic,
                        isBasicComp: comp.componentId == _basicComp.componentId,
                        isEsiEligible: _isEsiEligible,
                        calculatedVal: _getCompValue(comp),
                        onChanged: () => setState(() {}),
                      )),
                      const SizedBox(height: 20),

                      _SalarySummaryCard(
                        basic: basic,
                        totalAllowances: _totalAllowances,
                        incentive: _incentiveVal,
                        bonus: _bonusVal,
                        totalEarnings: gross,
                        totalDeductions: _totalDeductions,
                        netSalary: net,
                        isEsiEligible: _isEsiEligible,
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
    final Map<String, double> percentagesMap = {};
    double basicVal = _basicVal;

    for (final comp in _normalizedComponents) {
      final val = _getCompValue(comp);
      final rawPctOrFlat = double.tryParse(_componentCtrls[comp.componentId]?.text ?? '0') ?? 0.0;
      percentagesMap[comp.componentId] = rawPctOrFlat;

      if (comp.componentType == 'Earning') {
        earningsMap[comp.componentId] = val;
      } else {
        deductionsMap[comp.componentId] = val;
      }
    }

    final monthlyVal = double.tryParse(_monthlySalaryCtrl.text) ?? basicVal;
    final annualVal = double.tryParse(_annualSalaryCtrl.text) ?? (monthlyVal * 12);
    final bonusVal = _bonusVal;
    final incentiveVal = _incentivePctVal;

    final struct = SalaryStructureModel(
      structureId: widget.existingStruct?.structureId ?? const Uuid().v4(),
      companyId: user.companyId,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      monthlySalary: monthlyVal,
      annualSalary: annualVal,
      basic: basicVal,
      bonus: bonusVal,
      incentive: incentiveVal,
      earnings: earningsMap,
      deductions: deductionsMap,
      componentPercentages: percentagesMap,
      grossFormula: 'Basic + Allowances + Incentive + Bonus',
      netFormula: 'Gross - Deductions',
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
  final bool isBasicComp;
  final bool isEsiEligible;
  final double calculatedVal;
  final VoidCallback onChanged;

  const _ComponentRow({
    required this.comp,
    required this.controller,
    required this.basicVal,
    required this.isBasicComp,
    required this.isEsiEligible,
    required this.calculatedVal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEsi = comp.name.toLowerCase() == 'esi';
    final isPercentage = comp.calculationType == 'Percentage' && !isBasicComp;
    final isEsiDisabled = isEsi && !isEsiEligible;

    final currencyFmt = NumberFormat('#,##,##0');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isEsiDisabled ? Colors.grey : const Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                if (isEsiDisabled)
                  const Text(
                    'Not Applicable (Basic > ₹15,000)',
                    style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  )
                else if (isBasicComp)
                  const Text(
                    'Base Calculation Amount',
                    style: TextStyle(fontSize: 10, color: Color(0xFF5B4CF0), fontFamily: 'Outfit'),
                  )
                else if (isPercentage)
                  const Text(
                    'Calculated from Basic Pay',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: controller,
              enabled: !isEsiDisabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                prefixText: isPercentage ? null : '₹ ',
                suffixText: isPercentage ? ' %' : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: const OutlineInputBorder(),
                fillColor: isEsiDisabled ? Colors.grey[100] : null,
                filled: isEsiDisabled,
              ),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                color: isEsiDisabled ? Colors.grey : const Color(0xFF0F172A),
              ),
              validator: (v) {
                if (isEsiDisabled) return null;
                if (v == null || v.trim().isEmpty) return 'Required';
                final numVal = double.tryParse(v);
                if (numVal == null || numVal < 0) return 'Invalid';
                if (isPercentage && numVal > 100) return 'Max 100%';
                return null;
              },
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                isEsiDisabled
                    ? '₹0'
                    : '₹${currencyFmt.format(calculatedVal.round())}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isEsiDisabled
                      ? Colors.grey
                      : (comp.componentType == 'Earning' ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalarySummaryCard extends StatelessWidget {
  final double basic;
  final double totalAllowances;
  final double incentive;
  final double bonus;
  final double totalEarnings;
  final double totalDeductions;
  final double netSalary;
  final bool isEsiEligible;

  const _SalarySummaryCard({
    required this.basic,
    required this.totalAllowances,
    required this.incentive,
    required this.bonus,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netSalary,
    required this.isEsiEligible,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Salary Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
              if (!isEsiEligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ESI Excluded (Basic > ₹15,000)', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BASIC SALARY:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text(AppFormatter.formatCurrency(basic), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL ALLOWANCES:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text(AppFormatter.formatCurrency(totalAllowances), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit')),
            ],
          ),
          if (incentive > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('INCENTIVE:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                Text(AppFormatter.formatCurrency(incentive), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontFamily: 'Outfit')),
              ],
            ),
          ],
          if (bonus > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BONUS:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                Text(AppFormatter.formatCurrency(bonus), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontFamily: 'Outfit')),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GROSS SALARY:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit')),
              Text(AppFormatter.formatCurrency(totalEarnings), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL DEDUCTIONS:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
              Text(AppFormatter.formatCurrency(totalDeductions), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontFamily: 'Outfit')),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NET SALARY:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
              Text(AppFormatter.formatCurrency(netSalary), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontFamily: 'Outfit')),
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
