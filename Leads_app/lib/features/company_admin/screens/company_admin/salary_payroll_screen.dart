import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../models/salary_payslip_model.dart';
import '../../models/salary_structure_model.dart';
import '../../providers/company_admin_providers.dart';
import '../../providers/salary_payslip_provider.dart';
import '../../utils/salary_payslip_pdf.dart';
import '../../widgets/company_admin/searchable_paginated_table.dart';
import 'widgets/generate_payroll_dialog.dart';

class SalaryPayrollScreen extends ConsumerStatefulWidget {
  const SalaryPayrollScreen({super.key});

  @override
  ConsumerState<SalaryPayrollScreen> createState() => _SalaryPayrollScreenState();
}

class _SalaryPayrollScreenState extends ConsumerState<SalaryPayrollScreen> {
  // Screen Filters
  int? _filterMonth;
  int? _filterYear = DateTime.now().year;
  String? _filterEmployeeId;
  String? _filterStatus;

  // Active form state for the embedded top generation panel
  bool _showGenerationPanel = false;
  final _formKey = GlobalKey<FormState>();

  UserModel? _selectedEmployee;
  SalaryStructureModel? _assignedStructure;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final _presentDaysController = TextEditingController(text: '30');
  final _absentDaysController = TextEditingController(text: '0');
  final _leaveDaysController = TextEditingController(text: '0');

  final _bonusController = TextEditingController(text: '0.0');
  final _overtimeController = TextEditingController(text: '0.0');
  final _incentivesController = TextEditingController(text: '0.0');
  final _otherDeductionsController = TextEditingController(text: '0.0');

  bool _isSaving = false;

  final List<String> _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminEmployeesProvider.notifier).loadEmployees();
      ref.read(adminSalaryStructuresProvider.notifier).loadStructures();
      _refreshPayslips();
    });

    // Add listeners for live updates in the form
    _presentDaysController.addListener(_rebuild);
    _absentDaysController.addListener(_rebuild);
    _leaveDaysController.addListener(_rebuild);
    _bonusController.addListener(_rebuild);
    _overtimeController.addListener(_rebuild);
    _incentivesController.addListener(_rebuild);
    _otherDeductionsController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _presentDaysController.dispose();
    _absentDaysController.dispose();
    _leaveDaysController.dispose();
    _bonusController.dispose();
    _overtimeController.dispose();
    _incentivesController.dispose();
    _otherDeductionsController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _refreshPayslips() {
    ref.read(adminSalaryPayslipProvider.notifier).loadPayslips(
          month: _filterMonth,
          year: _filterYear,
          employeeId: _filterEmployeeId,
          status: _filterStatus,
        );
  }

  void _onEmployeeSelected(UserModel? emp) {
    setState(() {
      _selectedEmployee = emp;
      _assignedStructure = null;
    });

    if (emp != null && emp.salaryStructureId != null) {
      final structures = ref.read(adminSalaryStructuresProvider).value ?? [];
      final match = structures.where((s) => s.structureId == emp.salaryStructureId);
      if (match.isNotEmpty) {
        setState(() {
          _assignedStructure = match.first;
        });
      }
    }
  }

  // Live calculation getters
  double get _basic => _assignedStructure?.basic ?? 0.0;

  double get _structureAllowances {
    if (_assignedStructure == null) return 0.0;
    return _assignedStructure!.earnings.values.fold(0.0, (prev, e) => prev + e);
  }

  double get _bonus => double.tryParse(_bonusController.text) ?? 0.0;
  double get _overtime => double.tryParse(_overtimeController.text) ?? 0.0;
  double get _incentive => double.tryParse(_incentivesController.text) ?? 0.0;

  double get _grossSalary => _basic + _structureAllowances + _bonus + _overtime + _incentive;

  double get _structureDeductions {
    if (_assignedStructure == null) return 0.0;
    return _assignedStructure!.deductions.values.fold(0.0, (prev, d) => prev + d);
  }

  double get _otherDeduction => double.tryParse(_otherDeductionsController.text) ?? 0.0;

  double get _totalDeductions => _structureDeductions + _otherDeduction;

  double get _netSalary => _grossSalary - _totalDeductions;

  Future<void> _submitPayroll() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }

    final currentUser = ref.read(authProvider).user;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      final payslipId = const Uuid().v4();
      final payslip = SalaryPayslipModel(
        payslipId: payslipId,
        companyId: currentUser.companyId,
        employeeId: _selectedEmployee!.uid,
        employeeName: _selectedEmployee!.name,
        employeeCode: _selectedEmployee!.phoneNumber != null && _selectedEmployee!.phoneNumber!.isNotEmpty 
            ? _selectedEmployee!.phoneNumber 
            : 'EMP-${_selectedEmployee!.uid.substring(0, 5).toUpperCase()}',
        department: _selectedEmployee!.department ?? 'General',
        designation: _selectedEmployee!.designation ?? 'Employee',
        salaryStructureId: _assignedStructure?.structureId,
        salaryStructureName: _assignedStructure?.name,
        month: _selectedMonth,
        year: _selectedYear,
        basicSalary: _basic,
        earnings: _assignedStructure?.earnings ?? {},
        deductions: _assignedStructure?.deductions ?? {},
        bonus: _bonus,
        overtime: _overtime,
        incentive: _incentive,
        otherDeduction: _otherDeduction,
        presentDays: int.tryParse(_presentDaysController.text) ?? 30,
        absentDays: int.tryParse(_absentDaysController.text) ?? 0,
        leaveDays: int.tryParse(_leaveDaysController.text) ?? 0,
        grossSalary: _grossSalary,
        netSalary: _netSalary,
        generatedBy: currentUser.name,
        generatedDate: DateTime.now(),
        status: 'Generated',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(adminSalaryPayslipProvider.notifier).generatePayslip(payslip);

      setState(() {
        _selectedEmployee = null;
        _assignedStructure = null;
        _bonusController.text = '0.0';
        _overtimeController.text = '0.0';
        _incentivesController.text = '0.0';
        _otherDeductionsController.text = '0.0';
        _presentDaysController.text = '30';
        _absentDaysController.text = '0';
        _leaveDaysController.text = '0';
        _showGenerationPanel = false;
      });

      _refreshPayslips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payslip generated and saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate payslip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPayslipDetails(SalaryPayslipModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Payslip Details',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Employee snap
                  _buildDetailRow('Employee Name', p.employeeName),
                  _buildDetailRow('Employee Code', p.employeeCode ?? '—'),
                  _buildDetailRow('Department', p.department ?? '—'),
                  _buildDetailRow('Designation', p.designation ?? '—'),
                  _buildDetailRow('Period', p.payrollPeriod),
                  const Divider(height: 24),
                  _buildDetailRow('Present / Absent / Leaves', '${p.presentDays} / ${p.absentDays} / ${p.leaveDays} Days'),
                  _buildDetailRow('Assigned Structure', p.salaryStructureName ?? 'Custom / Standard'),
                  const Divider(height: 24),
                  // Earnings section
                  const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildDetailRow('Basic Salary', _currencyFormat.format(p.basicSalary)),
                  ...p.earnings.entries.map((e) => _buildDetailRow(e.key, _currencyFormat.format(e.value))),
                  if (p.bonus > 0) _buildDetailRow('Bonus', _currencyFormat.format(p.bonus)),
                  if (p.overtime > 0) _buildDetailRow('Overtime', _currencyFormat.format(p.overtime)),
                  if (p.incentive > 0) _buildDetailRow('Incentive', _currencyFormat.format(p.incentive)),
                  const Divider(height: 16),
                  _buildDetailRow('Gross Salary', _currencyFormat.format(p.grossSalary), isBold: true),
                  const SizedBox(height: 16),
                  // Deductions section
                  const Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...p.deductions.entries.map((e) => _buildDetailRow(e.key, _currencyFormat.format(e.value))),
                  if (p.otherDeduction > 0) _buildDetailRow('Other Deductions', _currencyFormat.format(p.otherDeduction)),
                  const Divider(height: 16),
                  _buildDetailRow('Total Deductions', _currencyFormat.format(p.totalDeductions), isBold: true),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Net Salary',
                    _currencyFormat.format(p.netSalary),
                    isBold: true,
                    fontSize: 20,
                    textColor: Colors.deepPurple,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final currentUser = ref.read(authProvider).user;
                            await SalaryPayslipPdf.print(p, currentUser?.companyName ?? 'WorkTrack');
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final currentUser = ref.read(authProvider).user;
                            await SalaryPayslipPdf.download(p, currentUser?.companyName ?? 'WorkTrack');
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download PDF'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.bold, color: textColor ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payslipsState = ref.watch(adminSalaryPayslipProvider);
    final employees = ref.watch(adminEmployeesProvider).value ?? [];
    final currentUser = ref.watch(authProvider).user;

    final payslips = payslipsState.payslips;

    // Stat totals
    final totalPayslips = payslips.length;
    final generatedThisMonth = payslips.where((p) => p.month == DateTime.now().month && p.year == DateTime.now().year).length;
    final pendingCount = payslips.where((p) => p.status == 'Draft').length;
    final downloadedCount = payslips.where((p) => p.status == 'Generated' || p.status == 'Sent').length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salary Payroll Processing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Generate and manage employee monthly payslips', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPayslips,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dashboard Stats Cards
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildStatCard('Total Payslips', totalPayslips.toString(), Icons.receipt_long_rounded, Colors.deepPurple),
                  const SizedBox(width: 16),
                  _buildStatCard('Generated This Month', generatedThisMonth.toString(), Icons.calendar_today, Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Pending / Draft', pendingCount.toString(), Icons.hourglass_empty, Colors.orange),
                  const SizedBox(width: 16),
                  _buildStatCard('Finalized / Sent', downloadedCount.toString(), Icons.check_circle_outline, Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Toggle Button for Generation Form Panel
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.payment, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Generate Payroll / Run Payslip Form',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  initiallyExpanded: _showGenerationPanel,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _showGenerationPanel = expanded;
                    });
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Employee
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<UserModel>(
                                    value: _selectedEmployee,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Employee *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                    items: employees.map((emp) {
                                      return DropdownMenuItem<UserModel>(
                                        value: emp,
                                        child: Text(emp.name),
                                      );
                                    }).toList(),
                                    onChanged: _isSaving ? null : _onEmployeeSelected,
                                    validator: (value) => value == null ? 'Employee is required' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Month
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedMonth,
                                    decoration: const InputDecoration(
                                      labelText: 'Month',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: List.generate(12, (index) {
                                      final m = index + 1;
                                      return DropdownMenuItem<int>(
                                        value: m,
                                        child: Text(_monthNames[m]),
                                      );
                                    }),
                                    onChanged: _isSaving ? null : (val) {
                                      if (val != null) setState(() => _selectedMonth = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Year
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedYear,
                                    decoration: const InputDecoration(
                                      labelText: 'Year',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: List.generate(5, (index) {
                                      final y = DateTime.now().year - 2 + index;
                                      return DropdownMenuItem<int>(
                                        value: y,
                                        child: Text(y.toString()),
                                      );
                                    }),
                                    onChanged: _isSaving ? null : (val) {
                                      if (val != null) setState(() => _selectedYear = val);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            if (_selectedEmployee != null && _assignedStructure == null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.amber.shade800),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Warning: No Salary Structure assigned to ${_selectedEmployee!.name}. Structure values default to 0.',
                                        style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Inputs
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _presentDaysController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Present', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _absentDaysController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Absent', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _leaveDaysController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Leaves', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Text('Payments & Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _bonusController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Bonus (₹)', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _overtimeController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Overtime (₹)', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _incentivesController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Incentives (₹)', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _otherDeductionsController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(labelText: 'Other Deductions (₹)', border: OutlineInputBorder(), isDense: true),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Preview Panel
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.deepPurple.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text('Auto Calculations Preview', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                        const Divider(height: 16),
                                        _buildCalcRow('Basic Salary', _currencyFormat.format(_basic)),
                                        _buildCalcRow('Allowances', _currencyFormat.format(_structureAllowances)),
                                        _buildCalcRow('Gross Salary', _currencyFormat.format(_grossSalary), isBold: true),
                                        _buildCalcRow('Deductions', _currencyFormat.format(_totalDeductions)),
                                        const Divider(height: 12),
                                        _buildCalcRow(
                                          'Net Salary',
                                          _currencyFormat.format(_netSalary),
                                          isBold: true,
                                          fontSize: 16,
                                          textColor: Colors.deepPurple.shade900,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepPurple,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: _isSaving ? null : _submitPayroll,
                                          child: _isSaving
                                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : const Text('Generate Payroll & Save'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Filters Panel
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Month filter
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _filterMonth,
                        decoration: const InputDecoration(labelText: 'Filter Month', border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Months')),
                          ...List.generate(12, (index) {
                            final m = index + 1;
                            return DropdownMenuItem<int?>(value: m, child: Text(_monthNames[m]));
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _filterMonth = val);
                          _refreshPayslips();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Year filter
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _filterYear,
                        decoration: const InputDecoration(labelText: 'Filter Year', border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('All Years')),
                          ...List.generate(5, (index) {
                            final y = DateTime.now().year - 2 + index;
                            return DropdownMenuItem<int?>(value: y, child: Text(y.toString()));
                          }),
                        ],
                        onChanged: (val) {
                          setState(() => _filterYear = val);
                          _refreshPayslips();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Employee Filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterEmployeeId,
                        decoration: const InputDecoration(labelText: 'Filter Employee', border: OutlineInputBorder(), isDense: true),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Employees')),
                          ...employees.map((e) => DropdownMenuItem<String?>(value: e.uid, child: Text(e.name))),
                        ],
                        onChanged: (val) {
                          setState(() => _filterEmployeeId = val);
                          _refreshPayslips();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _filterStatus,
                        decoration: const InputDecoration(labelText: 'Filter Status', border: OutlineInputBorder(), isDense: true),
                        items: const [
                          DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                          DropdownMenuItem<String?>(value: 'Draft', child: Text('Draft')),
                          DropdownMenuItem<String?>(value: 'Generated', child: Text('Generated')),
                          DropdownMenuItem<String?>(value: 'Sent', child: Text('Sent')),
                        ],
                        onChanged: (val) {
                          setState(() => _filterStatus = val);
                          _refreshPayslips();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Searchable Paginated Table
            SearchablePaginatedTable<SalaryPayslipModel>(
              items: payslips,
              searchPlaceholder: 'Search by employee or department...',
              searchMatcher: (p, query) {
                final q = query.toLowerCase();
                return p.employeeName.toLowerCase().contains(q) ||
                    (p.department != null && p.department!.toLowerCase().contains(q));
              },
              columns: const [
                DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Gross Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Net Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Generated Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rowBuilder: (p) {
                return [
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.employeeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (p.employeeCode != null)
                          Text(p.employeeCode!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  DataCell(Text(p.department ?? '—')),
                  DataCell(Text('${_monthNames[p.month]} ${p.year}')),
                  DataCell(Text(_currencyFormat.format(p.grossSalary))),
                  DataCell(Text(_currencyFormat.format(p.netSalary), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.status == 'Draft' ? Colors.orange.shade50 : Colors.green.shade50,
                        border: Border.all(color: p.status == 'Draft' ? Colors.orange.shade300 : Colors.green.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.status,
                        style: TextStyle(
                          color: p.status == 'Draft' ? Colors.orange.shade900 : Colors.green.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(DateFormat('dd MMM yyyy').format(p.generatedDate))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'View details',
                          icon: const Icon(Icons.visibility, color: Colors.deepPurple, size: 20),
                          onPressed: () => _showPayslipDetails(p),
                        ),
                        IconButton(
                          tooltip: 'Download PDF',
                          icon: const Icon(Icons.download_rounded, color: Colors.green, size: 20),
                          onPressed: () => SalaryPayslipPdf.download(p, currentUser?.companyName ?? 'WorkTrack'),
                        ),
                        IconButton(
                          tooltip: 'Print Payslip',
                          icon: const Icon(Icons.print_rounded, color: Colors.blue, size: 20),
                          onPressed: () => SalaryPayslipPdf.print(p, currentUser?.companyName ?? 'WorkTrack'),
                        ),
                        IconButton(
                          tooltip: 'Delete Payslip',
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                          onPressed: () => _confirmDelete(p),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'salaryPayrollFab',
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const GeneratePayrollDialog(),
          ).then((value) {
            if (value == true) _refreshPayslips();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Generate Payroll'),
      ),
    );
  }

  void _confirmDelete(SalaryPayslipModel p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payslip'),
        content: Text('Are you sure you want to delete the payslip of ${p.employeeName} for ${p.payrollPeriod}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(adminSalaryPayslipProvider.notifier).deletePayslip(p.payslipId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payslip deleted successfully'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete payslip: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool isBold = false, Color? textColor, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize - 1,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
