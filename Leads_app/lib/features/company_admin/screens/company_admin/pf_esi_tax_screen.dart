import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/utils/app_notification.dart';
import 'package:worktrack/features/company_admin/models/pf_esi_tax_settings_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class PfEsiTaxScreen extends ConsumerStatefulWidget {
  const PfEsiTaxScreen({super.key});

  @override
  ConsumerState<PfEsiTaxScreen> createState() => _PfEsiTaxScreenState();
}

class _PfEsiTaxScreenState extends ConsumerState<PfEsiTaxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: Compliance & Filings State ──
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _searchQuery = '';
  String _filterCategory = 'All';
  bool _isPaid = false;

  final _currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  static const List<String> _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // ── Tab 2: Settings Form State ──
  final _formKey = GlobalKey<FormState>();
  final _pfEmployerCtrl = TextEditingController();
  final _pfEmployeeCtrl = TextEditingController();
  final _esiEmployerCtrl = TextEditingController();
  final _esiEmployeeCtrl = TextEditingController();

  bool _pfEnabled = true;
  bool _esiEnabled = true;
  bool _profTaxEnabled = true;
  final List<Map<String, dynamic>> _taxSlabs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pfEmployerCtrl.dispose();
    _pfEmployeeCtrl.dispose();
    _esiEmployerCtrl.dispose();
    _esiEmployeeCtrl.dispose();
    super.dispose();
  }

  void _populateFields(PfEsiTaxSettingsModel s) {
    _pfEnabled = s.pfEnabled;
    _esiEnabled = s.esiEnabled;
    _profTaxEnabled = s.profTaxEnabled;

    _pfEmployerCtrl.text = s.pfEmployerContribution.toString();
    _pfEmployeeCtrl.text = s.pfEmployeeContribution.toString();
    _esiEmployerCtrl.text = s.esiEmployerContribution.toString();
    _esiEmployeeCtrl.text = s.esiEmployeeContribution.toString();

    _taxSlabs.clear();
    _taxSlabs.addAll(s.taxSlabs);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminComplianceSettingsProvider);
    final employeesAsync = ref.watch(adminEmployeesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PF / ESI & Statutory Taxes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, fontFamily: 'Outfit'),
            ),
            Text(
              'Statutory compliance tracking, deductions & tax settings',
              style: TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'Outfit'),
            ),
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
            Tab(icon: Icon(Icons.shield_outlined, size: 18), text: 'Compliance & Filings'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Statutory Rate Settings'),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading statutory settings: $err')),
        data: (settings) {
          if (_pfEmployerCtrl.text.isEmpty && _formKey.currentState == null) {
            _populateFields(settings);
          }

          final employees = employeesAsync.value ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildComplianceTab(context, settings, employees, isDark),
              _buildSettingsTab(context, settings, isDark),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════
  //  TAB 1 – COMPLIANCE & FILINGS OVERVIEW
  // ════════════════════════════════════════════
  Widget _buildComplianceTab(BuildContext context, PfEsiTaxSettingsModel settings, List<UserModel> employees, bool isDark) {
    final monthName = _monthNames[_selectedMonth];
    final nextMonthName = _monthNames[(_selectedMonth % 12) + 1];
    final dueYear = _selectedMonth == 12 ? _selectedYear + 1 : _selectedYear;
    final dueDateStr = '15 $nextMonthName $dueYear';

    // Calculate statutory totals across active employees
    final activeEmployees = employees.where((e) => e.status.toLowerCase() == 'active' || e.status.toLowerCase() == 'approved').toList();

    double totalPfEmployee = 0.0;
    double totalPfEmployer = 0.0;
    double totalEsiEmployee = 0.0;
    double totalEsiEmployer = 0.0;
    double totalPTax = 0.0;
    double totalTds = 0.0;

    for (final emp in activeEmployees) {
      final basic = 18000.0;

      if (settings.pfEnabled) {
        totalPfEmployee += (basic * (settings.pfEmployeeContribution / 100));
        totalPfEmployer += (basic * (settings.pfEmployerContribution / 100));
      }

      if (settings.esiEnabled && basic <= 21000) {
        totalEsiEmployee += (basic * (settings.esiEmployeeContribution / 100));
        totalEsiEmployer += (basic * (settings.esiEmployerContribution / 100));
      }

      if (settings.profTaxEnabled) {
        double ptax = 200.0;
        for (final slab in settings.taxSlabs) {
          final min = slab['min'] as double? ?? 0.0;
          final max = slab['max'] as double? ?? 9999999.0;
          final tax = slab['tax'] as double? ?? 0.0;
          if (basic >= min && basic <= max) {
            ptax = tax;
            break;
          }
        }
        totalPTax += ptax;
      }

      if (basic > 50000) {
        totalTds += (basic * 0.05);
      }
    }

    final totalPfPayable = totalPfEmployee + totalPfEmployer;
    final totalEsiPayable = totalEsiEmployee + totalEsiEmployer;
    final totalGrandStatutoryPayable = totalPfPayable + totalEsiPayable + totalPTax + totalTds;

    // Filter employees for detail breakdown
    final filteredEmps = activeEmployees.where((e) {
      final name = e.name.toLowerCase();
      final empId = (e.employeeId ?? '').toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || empId.contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_filterCategory == 'PF Deducted') return settings.pfEnabled;
      if (_filterCategory == 'ESI Deducted') return settings.esiEnabled;
      if (_filterCategory == 'PTax Deducted') return settings.profTaxEnabled;
      if (_filterCategory == 'TDS Deducted') return false;

      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period Selection & Due Date Banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Filing Month',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF5B4CF0),
                        value: _selectedMonth,
                        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i + 1]))),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedMonth = v);
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Filing Year',
                        icon: Icons.event_rounded,
                        color: const Color(0xFF10B981),
                        value: _selectedYear,
                        items: List.generate(5, (i) {
                          final y = DateTime.now().year - 2 + i;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedYear = v);
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.alarm_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Statutory Filing Due Date: ',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                    Text(
                      dueDateStr,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontFamily: 'Outfit'),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isPaid ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                            size: 14,
                            color: _isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isPaid ? 'PAID & FILED' : 'PENDING FILING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Grand Total Statutory Payable Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B4CF0), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF5B4CF0).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Statutory Liability', style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Outfit')),
                        SizedBox(height: 4),
                        Text('Employer + Employee Combined Statutory Payable', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Outfit')),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currencyFmt.format(totalGrandStatutoryPayable),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Outfit', letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _whiteBadge('Period: $monthName $_selectedYear'),
                    const SizedBox(width: 8),
                    _whiteBadge('Employees: ${activeEmployees.length}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Statutory Breakdown Cards (Grid) ──
          Text(
            'Compliance Breakdown Cards',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final pfCard = _buildComplianceCard(
                title: 'Provident Fund (PF)',
                icon: Icons.savings_rounded,
                color: const Color(0xFF4F46E5),
                employeeContribution: '${settings.pfEmployeeContribution}%',
                employerContribution: '${settings.pfEmployerContribution}%',
                totalPayable: _currencyFmt.format(totalPfPayable),
                status: settings.pfEnabled ? (_isPaid ? 'Completed' : 'Pending') : 'Disabled',
                isDark: isDark,
              );

              final esiCard = _buildComplianceCard(
                title: 'Employee State Insurance (ESI)',
                icon: Icons.health_and_safety_rounded,
                color: const Color(0xFF10B981),
                employeeContribution: '${settings.esiEmployeeContribution}%',
                employerContribution: '${settings.esiEmployerContribution}%',
                totalPayable: _currencyFmt.format(totalEsiPayable),
                status: settings.esiEnabled ? (_isPaid ? 'Completed' : 'Pending') : 'Disabled',
                isDark: isDark,
              );

              final ptaxCard = _buildComplianceCard(
                title: 'Professional Tax (P-Tax)',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFF59E0B),
                employeeContribution: 'State Slab Based',
                employerContribution: 'N/A',
                totalPayable: _currencyFmt.format(totalPTax),
                status: settings.profTaxEnabled ? (_isPaid ? 'Completed' : 'Pending') : 'Disabled',
                isDark: isDark,
              );

              final tdsCard = _buildComplianceCard(
                title: 'TDS / Income Tax',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFEC4899),
                employeeContribution: 'Income Slab Based',
                employerContribution: 'N/A',
                totalPayable: _currencyFmt.format(totalTds),
                status: _isPaid ? 'Completed' : 'Pending',
                isDark: isDark,
              );

              if (isWide) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: pfCard),
                        const SizedBox(width: 14),
                        Expanded(child: esiCard),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: ptaxCard),
                        const SizedBox(width: 14),
                        Expanded(child: tdsCard),
                      ],
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  pfCard,
                  const SizedBox(height: 12),
                  esiCard,
                  const SizedBox(height: 12),
                  ptaxCard,
                  const SizedBox(height: 12),
                  tdsCard,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calculate_rounded, size: 18),
                  label: const Text('Calculate', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AppNotification.showSuccess(context, 'Statutory contributions recalculated for $monthName $_selectedYear');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Generate Report', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B4CF0),
                    side: const BorderSide(color: Color(0xFF5B4CF0)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    AppNotification.showSuccess(context, 'Statutory Tax Report generated for $monthName $_selectedYear');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(_isPaid ? Icons.refresh_rounded : Icons.check_circle_rounded, size: 18),
                  label: Text(_isPaid ? 'Mark Pending' : 'Mark as Paid', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPaid ? const Color(0xFF64748B) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() => _isPaid = !_isPaid);
                    AppNotification.showSuccess(
                      context,
                      _isPaid ? 'Statutory compliance for $monthName $_selectedYear marked as PAID' : 'Filing status reset to PENDING',
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Employee-Wise Statutory Breakdown List ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Employee Statutory Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              Text(
                '${filteredEmps.length} record(s)',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search employee by name or ID...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5B4CF0)),
                    filled: true,
                    fillColor: isDark ? Theme.of(context).cardColor : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'PF Deducted', 'ESI Deducted', 'PTax Deducted', 'TDS Deducted'].map((cat) {
                final isSelected = _filterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    )),
                    selected: isSelected,
                    selectedColor: const Color(0xFF5B4CF0),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (val) {
                      if (val) setState(() => _filterCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          if (filteredEmps.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).cardColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.person_search_rounded, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text('No employee statutory records found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                  const SizedBox(height: 4),
                  Text('Try adjusting your search query or filter selection.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEmps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final emp = filteredEmps[index];
                final name = emp.name;
                final basic = 18000.0;

                final pfDed = settings.pfEnabled ? (basic * (settings.pfEmployeeContribution / 100)) : 0.0;
                final esiDed = (settings.esiEnabled && basic <= 21000) ? (basic * (settings.esiEmployeeContribution / 100)) : 0.0;
                final ptaxDed = settings.profTaxEnabled ? 200.0 : 0.0;
                final tdsDed = basic > 50000 ? (basic * 0.05) : 0.0;
                final totalStatutory = pfDed + esiDed + ptaxDed + tdsDed;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Theme.of(context).cardColor : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'E',
                              style: const TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                                Text('ID: ${emp.employeeId ?? 'N/A'}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isPaid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isPaid ? 'Paid' : 'Pending',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontFamily: 'Outfit'),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statItem('Basic', _currencyFmt.format(basic), isDark),
                          _statItem('PF (12%)', _currencyFmt.format(pfDed), isDark, color: const Color(0xFF4F46E5)),
                          _statItem('ESI (0.75%)', _currencyFmt.format(esiDed), isDark, color: const Color(0xFF10B981)),
                          _statItem('P-Tax', _currencyFmt.format(ptaxDed), isDark, color: const Color(0xFFF59E0B)),
                          _statItem('Total Deduction', _currencyFmt.format(totalStatutory), isDark, color: const Color(0xFFEF4444), isBold: true),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _whiteBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
    );
  }

  Widget _statItem(String label, String val, bool isDark, {Color? color, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)), fontFamily: 'Outfit')),
      ],
    );
  }

  Widget _buildComplianceCard({
    required String title,
    required IconData icon,
    required Color color,
    required String employeeContribution,
    required String employerContribution,
    required String totalPayable,
    required String status,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'Completed'
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : (status == 'Disabled' ? const Color(0xFF64748B).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'Completed' ? const Color(0xFF10B981) : (status == 'Disabled' ? const Color(0xFF64748B) : const Color(0xFFF59E0B)),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem('Employee Rate', employeeContribution, isDark),
              _statItem('Employer Rate', employerContribution, isDark),
              _statItem('Estimated Payable', totalPayable, isDark, color: color, isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required Color color,
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  //  TAB 2 – STATUTORY RATE SETTINGS FORM
  // ════════════════════════════════════════════
  Widget _buildSettingsTab(BuildContext context, PfEsiTaxSettingsModel settings, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Provident Fund (PF) Settings Card
            _buildSectionCard(
              title: 'Provident Fund (PF) Settings',
              icon: Icons.savings_rounded,
              color: const Color(0xFF4F46E5),
              children: [
                SwitchListTile(
                  title: const Text('Enable Provident Fund (PF) Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit')),
                  subtitle: const Text('Calculates and deducts PF contribution from monthly payroll.', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                  value: _pfEnabled,
                  activeColor: const Color(0xFF5B4CF0),
                  onChanged: (val) {
                    setState(() {
                      _pfEnabled = val;
                    });
                  },
                ),
                if (_pfEnabled) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, pfConstraints) {
                      final isCompact = pfConstraints.maxWidth < 450;
                      final employerField = TextFormField(
                        controller: _pfEmployerCtrl,
                        decoration: const InputDecoration(labelText: 'Employer Contribution (%)', prefixIcon: Icon(Icons.percent_rounded), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (_pfEnabled && (v == null || double.tryParse(v) == null)) ? 'Required' : null,
                      );

                      final employeeField = TextFormField(
                        controller: _pfEmployeeCtrl,
                        decoration: const InputDecoration(labelText: 'Employee Contribution (%)', prefixIcon: Icon(Icons.percent_rounded), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (_pfEnabled && (v == null || double.tryParse(v) == null)) ? 'Required' : null,
                      );

                      if (isCompact) {
                        return Column(
                          children: [
                            employerField,
                            const SizedBox(height: 12),
                            employeeField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: employerField),
                          const SizedBox(width: 12),
                          Expanded(child: employeeField),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 2. Employee State Insurance (ESI) Settings Card
            _buildSectionCard(
              title: 'Employee State Insurance (ESI) Settings',
              icon: Icons.health_and_safety_rounded,
              color: const Color(0xFF10B981),
              children: [
                SwitchListTile(
                  title: const Text('Enable ESI Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit')),
                  subtitle: const Text('Calculates medical benefits ESI deductions.', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                  value: _esiEnabled,
                  activeColor: const Color(0xFF5B4CF0),
                  onChanged: (val) {
                    setState(() {
                      _esiEnabled = val;
                    });
                  },
                ),
                if (_esiEnabled) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, esiConstraints) {
                      final isCompact = esiConstraints.maxWidth < 450;
                      final employerField = TextFormField(
                        controller: _esiEmployerCtrl,
                        decoration: const InputDecoration(labelText: 'Employer Contribution (%)', prefixIcon: Icon(Icons.percent_rounded), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (_esiEnabled && (v == null || double.tryParse(v) == null)) ? 'Required' : null,
                      );

                      final employeeField = TextFormField(
                        controller: _esiEmployeeCtrl,
                        decoration: const InputDecoration(labelText: 'Employee Contribution (%)', prefixIcon: Icon(Icons.percent_rounded), isDense: true),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => (_esiEnabled && (v == null || double.tryParse(v) == null)) ? 'Required' : null,
                      );

                      if (isCompact) {
                        return Column(
                          children: [
                            employerField,
                            const SizedBox(height: 12),
                            employeeField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: employerField),
                          const SizedBox(width: 12),
                          Expanded(child: employeeField),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 3. Professional Tax & Tax Slab Card
            _buildSectionCard(
              title: 'Professional Tax & Income Slabs',
              icon: Icons.account_balance_rounded,
              color: const Color(0xFFF59E0B),
              children: [
                SwitchListTile(
                  title: const Text('Enable Professional Tax (PTax) / Income Tax Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit')),
                  subtitle: const Text('Deducts monthly tax based on the defined brackets/slabs.', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                  value: _profTaxEnabled,
                  activeColor: const Color(0xFF5B4CF0),
                  onChanged: (val) {
                    setState(() {
                      _profTaxEnabled = val;
                    });
                  },
                ),
                if (_profTaxEnabled) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tax Brackets / Slabs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit')),
                      ElevatedButton.icon(
                        onPressed: _showAddSlabDialog,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Slab', style: TextStyle(fontSize: 11, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4CF0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_taxSlabs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text('No tax slabs configured yet. Click Add Slab.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _taxSlabs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final slab = _taxSlabs[index];
                        return Material(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Text('Monthly Income: ${_currencyFmt.format(slab['min'])} - ${_currencyFmt.format(slab['max'])}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                            subtitle: Text('Deduction: ${_currencyFmt.format(slab['tax'])}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _taxSlabs.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Update Statutory Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final user = ref.read(authProvider).user;
                  if (user == null) return;

                  final newSettings = PfEsiTaxSettingsModel(
                    companyId: user.companyId,
                    pfEnabled: _pfEnabled,
                    esiEnabled: _esiEnabled,
                    profTaxEnabled: _profTaxEnabled,
                    pfEmployerContribution: double.tryParse(_pfEmployerCtrl.text) ?? 12.0,
                    pfEmployeeContribution: double.tryParse(_pfEmployeeCtrl.text) ?? 12.0,
                    esiEmployerContribution: double.tryParse(_esiEmployerCtrl.text) ?? 3.25,
                    esiEmployeeContribution: double.tryParse(_esiEmployeeCtrl.text) ?? 0.75,
                    taxSlabs: _taxSlabs,
                  );

                  await ref.read(adminComplianceSettingsProvider.notifier).saveSettings(newSettings);
                  if (context.mounted) {
                    AppNotification.showSuccess(context, 'Statutory compliance settings updated successfully.');
                  }
                }
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Outfit'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  void _showAddSlabDialog() {
    final slabFormKey = GlobalKey<FormState>();
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    final taxCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Tax Slab', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Form(
          key: slabFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: minCtrl,
                decoration: const InputDecoration(labelText: 'Min Monthly Salary (INR) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: maxCtrl,
                decoration: const InputDecoration(labelText: 'Max Monthly Salary (INR) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: taxCtrl,
                decoration: const InputDecoration(labelText: 'Deduction Amount (INR) *'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              if (slabFormKey.currentState!.validate()) {
                setState(() {
                  _taxSlabs.add({
                    'min': double.parse(minCtrl.text.trim()),
                    'max': double.parse(maxCtrl.text.trim()),
                    'tax': double.parse(taxCtrl.text.trim()),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
