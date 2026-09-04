import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../../shared/models/user_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../models/salary_payslip_model.dart';
import '../../../models/salary_structure_model.dart';
import '../../../providers/company_admin_providers.dart';
import '../../../providers/salary_payslip_provider.dart';

class GeneratePayrollDialog extends ConsumerStatefulWidget {
  const GeneratePayrollDialog({super.key});

  @override
  ConsumerState<GeneratePayrollDialog> createState() => _GeneratePayrollDialogState();
}

class _GeneratePayrollDialogState extends ConsumerState<GeneratePayrollDialog> {
  final _formKey = GlobalKey<FormState>();

  UserModel? _selectedEmployee;
  SalaryStructureModel? _assignedStructure;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Controllers
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

  @override
  void initState() {
    super.initState();
    // Ensure employees and structures are loaded
    Future.microtask(() {
      ref.read(adminEmployeesProvider.notifier).loadEmployees();
      ref.read(adminSalaryStructuresProvider.notifier).loadStructures();
    });

    // Add listeners for live updates
    _presentDaysController.addListener(_recalculate);
    _absentDaysController.addListener(_recalculate);
    _leaveDaysController.addListener(_recalculate);
    _bonusController.addListener(_recalculate);
    _overtimeController.addListener(_recalculate);
    _incentivesController.addListener(_recalculate);
    _otherDeductionsController.addListener(_recalculate);
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

  void _recalculate() {
    if (mounted) setState(() {});
  }

  void _onEmployeeSelected(UserModel? emp) {
    setState(() {
      _selectedEmployee = emp;
      _assignedStructure = null;
    });

    if (emp == null) return;

    final structures = ref.read(adminSalaryStructuresProvider).value ?? [];
    if (structures.isEmpty) return;

    SalaryStructureModel? chosen;
    if (emp.salaryStructureId != null && emp.salaryStructureId!.isNotEmpty) {
      final match = structures.where((s) => s.structureId == emp.salaryStructureId);
      if (match.isNotEmpty) chosen = match.first;
    }
    if (chosen == null) {
      final active = structures.where((s) => s.status.toLowerCase() == 'active');
      if (active.isNotEmpty) chosen = active.first;
    }

    if (chosen != null) {
      setState(() {
        _assignedStructure = chosen;
        if (chosen!.bonus > 0 && (_bonusController.text.isEmpty || _bonusController.text == '0')) {
          _bonusController.text = chosen.bonus % 1 == 0 ? chosen.bonus.toInt().toString() : chosen.bonus.toString();
        }
        if (chosen.incentive > 0 && (_incentivesController.text.isEmpty || _incentivesController.text == '0')) {
          final incVal = chosen.basic * (chosen.incentive / 100.0);
          _incentivesController.text = incVal % 1 == 0 ? incVal.toInt().toString() : incVal.toString();
        }
      });
    }
  }

  // Live Calculations
  double get _basic => _assignedStructure?.basic ?? 0.0;

  double get _structureAllowances {
    if (_assignedStructure == null) return 0.0;
    return _assignedStructure!.earnings.values.fold(0.0, (prev, e) => prev + e);
  }

  double get _bonus => double.tryParse(_bonusController.text) ?? 0.0;
  double get _overtime => double.tryParse(_overtimeController.text) ?? 0.0;
  double get _incentive => double.tryParse(_incentivesController.text) ?? 0.0;

  double get _grossSalary {
    // Basic + structure allowances (earnings) + bonus + overtime + incentive
    return _basic + _structureAllowances + _bonus + _overtime + _incentive;
  }

  double get _structureDeductions {
    if (_assignedStructure == null) return 0.0;
    return _assignedStructure!.deductions.values.fold(0.0, (prev, d) => prev + d);
  }

  double get _otherDeduction => double.tryParse(_otherDeductionsController.text) ?? 0.0;

  double get _totalDeductions {
    return _structureDeductions + _otherDeduction;
  }

  double get _netSalary {
    return _grossSalary - _totalDeductions;
  }

  Future<void> _submit() async {
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
        employeeCode: _selectedEmployee!.displayEmployeeId,
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

      if (mounted) {
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeesState = ref.watch(adminEmployeesProvider);
    final structuresState = ref.watch(adminSalaryStructuresProvider);

    final isLoading = employeesState.isLoading || structuresState.isLoading;
    final employees = employeesState.value ?? [];

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: isLoading
            ? const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            const Text(
                              'Generate Payslip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Selection Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Employee dropdown
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF451A03) : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF78350F) : Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: isDark ? const Color(0xFFFBBF24) : Colors.amber.shade800),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Warning: ${_selectedEmployee!.name} does not have an assigned salary structure. Structure-based components will default to 0.',
                                        style: TextStyle(color: isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Structure & Input sections
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Side: Input variables
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Attendance Details',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA78BFA) : Colors.deepPurple),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _presentDaysController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: const InputDecoration(
                                                labelText: 'Present Days',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              validator: (v) => v!.isEmpty ? 'Req' : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _absentDaysController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: const InputDecoration(
                                                labelText: 'Absent Days',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              validator: (v) => v!.isEmpty ? 'Req' : null,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _leaveDaysController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: const InputDecoration(
                                                labelText: 'Leave Days',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              validator: (v) => v!.isEmpty ? 'Req' : null,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 24),
                                      Text(
                                        'Additional Payments',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFA78BFA) : Colors.deepPurple),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _bonusController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Bonus (₹)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _overtimeController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Overtime (₹)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
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
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Incentives (₹)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _otherDeductionsController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Other Deductions (₹)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 24),

                                // Right Side: Live preview card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Live Payslip Calculation',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        _buildCalcRow('Basic Salary', currencyFormat.format(_basic), context: context),
                                        _buildCalcRow('Allowances', currencyFormat.format(_structureAllowances), context: context),
                                        _buildCalcRow('Bonus', currencyFormat.format(_bonus), context: context),
                                        _buildCalcRow('Overtime', currencyFormat.format(_overtime), context: context),
                                        _buildCalcRow('Incentives', currencyFormat.format(_incentive), context: context),
                                        Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        _buildCalcRow(
                                          'Gross Salary',
                                          currencyFormat.format(_grossSalary),
                                          isBold: true,
                                          color: isDark ? const Color(0xFF34D399) : Colors.green.shade700,
                                          context: context,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildCalcRow('Structure Deductions', '- ${currencyFormat.format(_structureDeductions)}', context: context),
                                        _buildCalcRow('Other Deductions', '- ${currencyFormat.format(_otherDeduction)}', context: context),
                                        Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                        _buildCalcRow(
                                          'Net Salary',
                                          currencyFormat.format(_netSalary),
                                          isBold: true,
                                          color: isDark ? const Color(0xFFA78BFA) : Colors.deepPurple,
                                          fontSize: 18,
                                          context: context,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _isSaving ? null : _submit,
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text(
                                          'Generate & Save',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, {bool isBold = false, Color? color, double fontSize = 14, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize - 1,
              color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

typedef GeneratePayslipDialog = GeneratePayrollDialog;
