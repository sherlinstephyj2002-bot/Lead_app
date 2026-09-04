import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../company_admin/providers/salary_payslip_provider.dart';
import '../../company_admin/utils/salary_payslip_pdf.dart';
import '../../company_admin/models/salary_payslip_model.dart';

class ESSPayslipsScreen extends ConsumerStatefulWidget {
  const ESSPayslipsScreen({super.key});

  @override
  ConsumerState<ESSPayslipsScreen> createState() => _ESSPayslipsScreenState();
}

class _ESSPayslipsScreenState extends ConsumerState<ESSPayslipsScreen> {
  int? _selectedMonth;
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider).user;
    final payslipsState = ref.watch(adminSalaryPayslipProvider);

    // Strict employee scoping
    var userPayslips = payslipsState.payslips.where((p) {
      if (user == null) return false;
      return p.employeeId == user.uid ||
          p.employeeId == user.employeeId ||
          (user.displayEmployeeId.isNotEmpty && p.employeeCode == user.displayEmployeeId);
    }).toList();

    // Apply month & year filters if selected
    if (_selectedMonth != null) {
      userPayslips = userPayslips.where((p) => p.month == _selectedMonth).toList();
    }
    if (_selectedYear != null) {
      userPayslips = userPayslips.where((p) => p.year == _selectedYear).toList();
    }

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'My Payslips & Statements',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month & Year Filter Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FILTER PAYSLIPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), letterSpacing: 1.0)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Month Selector
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Months')),
                            ...List.generate(12, (index) {
                              final m = index + 1;
                              return DropdownMenuItem<int?>(
                                value: m,
                                child: Text(_getMonthName(m)),
                              );
                            }),
                          ],
                          onChanged: (val) => setState(() => _selectedMonth = val),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Year Selector
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem<int?>(value: null, child: Text('All Years')),
                            DropdownMenuItem<int?>(value: 2026, child: Text('2026')),
                            DropdownMenuItem<int?>(value: 2025, child: Text('2025')),
                            DropdownMenuItem<int?>(value: 2024, child: Text('2024')),
                          ],
                          onChanged: (val) => setState(() => _selectedYear = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payslips List Section
            Text(
              'PAYSLIP HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),

            userPayslips.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32.0),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 54, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No payslips found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Payslips generated by HR for your account will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: userPayslips.map((p) {
                      final monthYearLabel = '${_getMonthName(p.month)} ${p.year}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Theme.of(context).cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthYearLabel,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(p.status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            _buildRow('Basic Salary', currencyFmt.format(p.basicSalary), isDark),
                            _buildRow('Allowances & Incentives', currencyFmt.format(p.bonus + p.overtime + p.incentive + p.earnings.values.fold(0.0, (s, e) => s + e)), isDark),
                            _buildRow('Gross Earnings', currencyFmt.format(p.grossSalary), isDark, isBold: true),
                            const SizedBox(height: 6),
                            _buildRow('Statutory & Structural Deductions', '- ${currencyFmt.format(p.deductions.values.fold(0.0, (s, d) => s + d))}', isDark, isRed: true),
                            _buildRow('Other Deductions', '- ${currencyFmt.format(p.otherDeduction)}', isDark, isRed: true),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('NET SALARY CREDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    Text(
                                      currencyFmt.format(p.netSalary),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit'),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _showPayslipBreakdownDialog(context, p, currencyFmt),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF5B4CF0),
                                        side: const BorderSide(color: Color(0xFF5B4CF0)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('View Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final company = ref.read(companyProvider).value;
                                        final companyName = company?.name ?? 'WorkTrack';
                                        await SalaryPayslipPdf.print(p, companyName);
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 16),
                                      label: const Text('Download PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5B4CF0),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  void _showPayslipBreakdownDialog(BuildContext context, SalaryPayslipModel p, NumberFormat currencyFmt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_getMonthName(p.month)} ${p.year} Payslip Breakdown', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Employee Name: ${p.employeeName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Employee ID: ${p.employeeCode ?? p.employeeId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 20),
              const Text('EARNINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              _buildRow('Basic Salary', currencyFmt.format(p.basicSalary), false),
              _buildRow('Bonus', currencyFmt.format(p.bonus), false),
              _buildRow('Incentive', currencyFmt.format(p.incentive), false),
              _buildRow('Overtime', currencyFmt.format(p.overtime), false),
              ...p.earnings.entries.map((e) => _buildRow(e.key, currencyFmt.format(e.value), false)),
              const Divider(height: 16),
              _buildRow('Gross Earnings', currencyFmt.format(p.grossSalary), false, isBold: true),
              const SizedBox(height: 16),
              const Text('DEDUCTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
              ...p.deductions.entries.map((e) => _buildRow(e.key, '- ${currencyFmt.format(e.value)}', false, isRed: true)),
              _buildRow('Other Deductions', '- ${currencyFmt.format(p.otherDeduction)}', false, isRed: true),
              const Divider(height: 16),
              _buildRow('NET SALARY', currencyFmt.format(p.netSalary), false, isBold: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _getMonthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    if (month >= 1 && month <= 12) return months[month];
    return '';
  }

  Widget _buildRow(String label, String val, bool isDark, {bool isBold = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isRed ? Colors.red : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
