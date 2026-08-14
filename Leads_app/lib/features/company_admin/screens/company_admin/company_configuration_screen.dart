import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/models/company_model.dart';
import '../../../../shared/utils/company_password_helper.dart';
import 'shift_management_screen.dart';
import 'holiday_management_screen.dart';

class CompanyConfigurationScreen extends ConsumerStatefulWidget {
  const CompanyConfigurationScreen({super.key});

  @override
  ConsumerState<CompanyConfigurationScreen> createState() => _CompanyConfigurationScreenState();
}

class _CompanyConfigurationScreenState extends ConsumerState<CompanyConfigurationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSaving = false;
  bool _showDefaultPassword = false;

  final Set<String> _workingDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
  final Set<String> _weeklyOffs = {'Saturday', 'Sunday'};

  TimeOfDay _officeStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _officeEndTime = const TimeOfDay(hour: 18, minute: 0);

  String _dateFormat = 'dd/MM/yyyy';
  String _timeFormat = '12 Hours (AM/PM)';
  String _currency = 'USD (\$)';
  String _financialYear = 'April - March';

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> _dateFormats = ['dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'];
  final List<String> _timeFormats = ['12 Hours (AM/PM)', '24 Hours'];
  final List<String> _currencies = ['USD (\$)', 'EUR (€)', 'GBP (£)', 'INR (₹)', 'CAD (\$)', 'AUD (\$)'];
  final List<String> _financialYears = ['January - December', 'April - March', 'July - June', 'October - September'];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Company Configuration',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
          tabs: const [
            Tab(text: 'General Settings'),
            Tab(text: 'Work Shifts'),
            Tab(text: 'Holidays Calendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralSettingsTab(isDark),
          const ShiftManagementScreen(),
          const HolidayManagementScreen(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettingsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader('Working Days & Weekly Off', Icons.calendar_month_rounded, isDark),
          const SizedBox(height: 12),
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
                const Text('Select Working Days:', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allDays.map((day) {
                    final isSelected = _workingDays.contains(day);
                    return FilterChip(
                      selected: isSelected,
                      label: Text(day, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                      selectedColor: const Color(0xFF5B4CF0),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _workingDays.add(day);
                            _weeklyOffs.remove(day);
                          } else {
                            _workingDays.remove(day);
                            _weeklyOffs.add(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildCardHeader('Office Timings', Icons.access_time_rounded, isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _officeStartTime);
                      if (picked != null) setState(() => _officeStartTime = picked);
                    },
                    icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: Text('Start: ${_officeStartTime.format(context)}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(context: context, initialTime: _officeEndTime);
                      if (picked != null) setState(() => _officeEndTime = picked);
                    },
                    icon: const Icon(Icons.nightlight_round, size: 16),
                    label: Text('End: ${_officeEndTime.format(context)}', style: const TextStyle(fontFamily: 'Outfit', fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildCardHeader('Regional & Date Formats', Icons.language_rounded, isDark),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _dateFormat,
                  decoration: const InputDecoration(labelText: 'Date Format'),
                  items: _dateFormats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _dateFormat = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _timeFormat,
                  decoration: const InputDecoration(labelText: 'Time Format'),
                  items: _timeFormats.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (v) => setState(() => _timeFormat = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _financialYear,
                  decoration: const InputDecoration(labelText: 'Financial Year Cycle'),
                  items: _financialYears.map((fy) => DropdownMenuItem(value: fy, child: Text(fy))).toList(),
                  onChanged: (v) => setState(() => _financialYear = v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Builder(
            builder: (context) {
              final company = ref.watch(companyProvider).value;
              final adminUser = ref.watch(authProvider).user;
              final companyName = company?.name ?? adminUser?.companyName ?? '';
              final defaultPassword = company?.defaultEmployeePassword ??
                  CompanyPasswordHelper.generateDefaultPassword(companyName, companyCode: company?.companyCode ?? adminUser?.companyCode);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader('Employee Default Login Password', Icons.lock_person_rounded, isDark),
                  const SizedBox(height: 12),
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
                        Text(
                          'Initial password assigned to all newly created employees. Employees must change this password after their first login.',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _showDefaultPassword ? defaultPassword : '•' * defaultPassword.length,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: _showDefaultPassword ? 0.5 : 2.0,
                                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _showDefaultPassword ? Icons.visibility_off : Icons.visibility,
                                        size: 18,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => setState(() => _showDefaultPassword = !_showDefaultPassword),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: company == null ? null : () => _showChangeDefaultPasswordDialog(context, company, defaultPassword),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B4CF0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text(
                                'Change Default Password',
                                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      await Future.delayed(const Duration(milliseconds: 600));
                      if (mounted) {
                        setState(() => _isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Company configuration saved successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    },
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Configuration', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5B4CF0)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _showChangeDefaultPasswordDialog(BuildContext context, CompanyModel company, String currentDefault) {
    final formKey = GlobalKey<FormState>();
    final passCtrl = TextEditingController(text: currentDefault);
    bool isSavingPassword = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_person_rounded, color: Color(0xFF5B4CF0)),
                  SizedBox(width: 8),
                  Text('Change Default Password', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter a new default password for future employee accounts. This will not change passwords of existing employees who have already set their personal passwords.',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Default Employee Password',
                        hintText: 'e.g. Jazz@123',
                        prefixIcon: Icon(Icons.vpn_key_outlined, size: 18),
                      ),
                      validator: CompanyPasswordHelper.validateDefaultPassword,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingPassword ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSavingPassword
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setModalState(() => isSavingPassword = true);
                            try {
                              final newPass = passCtrl.text.trim();
                              final updatedCompany = company.copyWith(defaultEmployeePassword: newPass);
                              await ref.read(companyRepositoryProvider).saveCompany(updatedCompany);
                              ref.read(companyProvider.notifier).loadCompany();
                              if (context.mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Default employee password updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isSavingPassword = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update default password: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  child: isSavingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
