import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
