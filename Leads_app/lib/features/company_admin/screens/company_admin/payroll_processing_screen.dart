import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/company_admin_providers.dart';
import '../../models/payroll_model.dart';
import '../../../../constants/user_roles.dart';
import '../../../../shared/providers/providers.dart';

class PayrollProcessingScreen extends ConsumerStatefulWidget {
  const PayrollProcessingScreen({super.key});

  @override
  ConsumerState<PayrollProcessingScreen> createState() =>
      _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState
    extends ConsumerState<PayrollProcessingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Run Payroll tab state ──
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // ── Review tab state ──
  String _statusFilter = 'All';

  final _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static const _statusColors = {
    'Draft': Color(0xFF64748B),
    'Approved': Color(0xFF10B981),
    'Rejected': Color(0xFFEF4444),
    'Paid': Color(0xFF8B5CF6),
  };

  static const List<String> _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

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
    final payrollState = ref.watch(payrollProvider);

    // Show error snackbar
    ref.listen<PayrollState>(payrollProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!, style: const TextStyle(fontFamily: 'Outfit')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(payrollProvider.notifier).clearError();
      }
    });

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
            Text('Payroll Processing',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                    fontFamily: 'Outfit')),
            Text('Generate, review & approve monthly payroll',
                style: TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'Outfit')),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Outfit', fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline_rounded, size: 18), text: 'Run Payroll'),
            Tab(icon: Icon(Icons.rate_review_rounded, size: 18), text: 'Review & Approve'),
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRunPayrollTab(payrollState),
          _buildReviewTab(payrollState),
          _buildHistoryTab(payrollState),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  //  TAB 1 – RUN PAYROLL
  // ════════════════════════════════════════════
  Widget _buildRunPayrollTab(PayrollState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthLabel = _monthNames[_selectedMonth];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Info Banner Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Color(0xFF5B4CF0), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Automated Payroll Calculation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                      const SizedBox(height: 2),
                      Text('Payroll is computed for active employees using assigned salary structures, attendance, approved leaves, and Statutory settings.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Period Selector Header ──
          Text('Select Payroll Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _dropdownCard(
                  label: 'Month',
                  icon: Icons.calendar_month_rounded,
                  color: const Color(0xFF5B4CF0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedMonth,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(_monthNames[i + 1]),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedMonth = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdownCard(
                  label: 'Year',
                  icon: Icons.event_rounded,
                  color: const Color(0xFF10B981),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: List.generate(
                        5,
                        (i) {
                          final y = DateTime.now().year - 2 + i;
                          return DropdownMenuItem(
                            value: y,
                            child: Text('$y'),
                          );
                        },
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedYear = v);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Generate Payroll CTA ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: state.isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_filled_rounded),
              label: Text(
                state.isGenerating
                    ? 'Generating Payroll...'
                    : 'Generate Payroll for $monthLabel $_selectedYear',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: state.isGenerating
                  ? null
                  : () => _onGeneratePayroll(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Refresh Action Button ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Load / Refresh $monthLabel $_selectedYear Records', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4CF0),
                side: const BorderSide(color: Color(0xFF5B4CF0)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ref.read(payrollProvider.notifier).loadPayrolls(_selectedMonth, _selectedYear);
                _tabController.animateTo(1);
              },
            ),
          ),
          const SizedBox(height: 24),

          // ── Period Summary Cards ──
          if (state.payrolls.isNotEmpty &&
              state.selectedMonth == _selectedMonth &&
              state.selectedYear == _selectedYear)
            _buildSummaryCards(state.payrolls),
        ],
      ),
    );
  }

  Widget _dropdownCard({
    required String label,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Future<void> _onGeneratePayroll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate Payroll', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text(
            'Generate payroll for ${_monthNames[_selectedMonth]} $_selectedYear?\n\n'
            'This will compute payroll for all active employees with a salary structure. '
            'Existing records for this period will be skipped.',
            style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final count = await ref.read(payrollProvider.notifier).generatePayroll(_selectedMonth, _selectedYear);

    if (!mounted) return;
    if (count >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? 'No new payroll records generated. All eligible employees already have records for this period.'
              : '$count payroll record(s) generated successfully.', style: const TextStyle(fontFamily: 'Outfit')),
          backgroundColor: count == 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (count > 0) _tabController.animateTo(1);
    }
  }

  // ════════════════════════════════════════════
  //  TAB 2 – REVIEW & APPROVE
  // ════════════════════════════════════════════
  Widget _buildReviewTab(PayrollState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _statusFilter == 'All'
        ? state.payrolls
        : state.payrolls.where((p) => p.status == _statusFilter).toList();

    return Column(
      children: [
        // Filter Chips Bar
        Container(
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF5B4CF0)),
                  const SizedBox(width: 6),
                  Text(
                    '${_monthNames[state.selectedMonth]} ${state.selectedYear}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0), fontSize: 15, fontFamily: 'Outfit'),
                  ),
                  const Spacer(),
                  Text('${state.payrolls.length} employee(s)', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Draft', 'Approved', 'Rejected', 'Paid'].map((s) => _filterChip(s)).toList(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

        if (state.payrolls.isNotEmpty) _buildSummaryBar(state.payrolls),

        if (state.payrolls.isEmpty)
          Expanded(
            child: _emptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No payroll records found',
              subtitle: 'Go to "Run Payroll" tab and generate payroll for this period.',
            ),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: _emptyState(
              icon: Icons.filter_list_off_rounded,
              title: 'No records match filter',
              subtitle: 'Try a different status filter.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, sep) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _buildPayrollCard(filtered[i]),
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _statusFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
        )),
        selected: isSelected,
        selectedColor: const Color(0xFF5B4CF0),
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (val) {
          if (val) setState(() => _statusFilter = label);
        },
      ),
    );
  }

  Widget _buildSummaryBar(List<PayrollModel> list) {
    final totalGross = list.fold<double>(0, (s, p) => s + p.grossSalary);
    final totalDeductions = list.fold<double>(0, (s, p) => s + p.totalDeductions);
    final totalNet = list.fold<double>(0, (s, p) => s + p.netSalary);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryText('Gross', _currencyFmt.format(totalGross)),
          _summaryText('Deductions', _currencyFmt.format(totalDeductions), color: const Color(0xFFEF4444)),
          _summaryText('Net Pay', _currencyFmt.format(totalNet), color: const Color(0xFF10B981), isBold: true),
        ],
      ),
    );
  }

  Widget _summaryText(String label, String val, {Color? color, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)), fontFamily: 'Outfit')),
      ],
    );
  }

  Widget _buildPayrollCard(PayrollModel p) {
    final color = _statusColors[p.status] ?? const Color(0xFF64748B);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.2 : 0.1),
                child: Text(
                  p.employeeName.isNotEmpty ? p.employeeName[0].toUpperCase() : 'E',
                  style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.employeeName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                    Text('ID: ${p.employeeId}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(p.status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ),
            ],
          ),
          Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardInfoCol('Gross Pay', _currencyFmt.format(p.grossSalary)),
              _cardInfoCol('Total Deductions', _currencyFmt.format(p.totalDeductions), color: const Color(0xFFEF4444)),
              _cardInfoCol('Net Salary', _currencyFmt.format(p.netSalary), color: const Color(0xFF10B981), isBold: true),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final userRole = ref.watch(authProvider).user?.role;
              final canApprove = UserRoles.canApprovePayroll(userRole);

              if (!canApprove) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Approval restricted to HR Admin',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                      ),
                      if (p.status == 'Draft')
                        ElevatedButton.icon(
                          onPressed: () => _confirmSubmitPayrollToHRAdmin(p),
                          icon: const Icon(Icons.send_rounded, size: 14),
                          label: const Text('Submit to HR Admin', style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4CF0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (p.status == 'Draft' || p.status == 'Rejected')
                    TextButton.icon(
                      onPressed: () => _updateStatus(p, 'Approved'),
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Approve', style: TextStyle(color: Color(0xFF10B981), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  if (p.status == 'Draft' || p.status == 'Approved')
                    TextButton.icon(
                      onPressed: () => _updateStatus(p, 'Rejected'),
                      icon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                      label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit')),
                    ),
                  if (p.status == 'Approved')
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(p, 'Paid'),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Mark Paid', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cardInfoCol(String label, String val, {Color? color, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)), fontFamily: 'Outfit')),
      ],
    );
  }

  void _confirmSubmitPayrollToHRAdmin(PayrollModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF5B4CF0)),
            SizedBox(width: 8),
            Text('Submit Payroll to HR Admin?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to submit this payroll for "${p.employeeName}" to HR Admin for approval?',
          style: const TextStyle(fontFamily: 'Outfit', height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(payrollProvider.notifier).updatePayrollStatus(p.payrollId, 'Submitted');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payroll submitted to HR Admin successfully.', style: TextStyle(fontFamily: 'Outfit')),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Submit', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(PayrollModel p, String newStatus) async {
    await ref.read(payrollProvider.notifier).updatePayrollStatus(p.payrollId, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payroll for ${p.employeeName} updated to $newStatus', style: const TextStyle(fontFamily: 'Outfit')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ════════════════════════════════════════════
  //  TAB 3 – PAYROLL HISTORY
  // ════════════════════════════════════════════
  Widget _buildHistoryTab(PayrollState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final payrolls = state.payrolls;
    if (payrolls.isEmpty) {
      return _emptyState(
        icon: Icons.history_rounded,
        title: 'No Payroll History Found',
        subtitle: 'Generated payroll records for processed months will appear here.',
      );
    }

    // Group payrolls by payrollPeriod
    final Map<String, List<PayrollModel>> grouped = {};
    for (final p in payrolls) {
      grouped.putIfAbsent(p.payrollPeriod, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(payrolls),
        const SizedBox(height: 16),
        ...payrolls.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildPayrollCard(p),
            )),
      ],
    );
  }

  Widget _buildSummaryCards(List<PayrollModel> payrolls) {
    final totalGross = payrolls.fold<double>(0, (s, p) => s + p.grossSalary);
    final totalNet = payrolls.fold<double>(0, (s, p) => s + p.netSalary);
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
          Text('Batch Payroll Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Employees Processed:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text('${payrolls.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Gross Salary:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text(_currencyFmt.format(totalGross), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Net Salary:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
              Text(_currencyFmt.format(totalNet), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
        ],
      ),
    );
  }
}
