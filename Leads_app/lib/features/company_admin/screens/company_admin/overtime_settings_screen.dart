import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/overtime_settings_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/utils/app_notification.dart';

class OvertimeSettingsScreen extends ConsumerStatefulWidget {
  const OvertimeSettingsScreen({super.key});

  @override
  ConsumerState<OvertimeSettingsScreen> createState() => _OvertimeSettingsScreenState();
}

class _OvertimeSettingsScreenState extends ConsumerState<OvertimeSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minOtCtrl = TextEditingController();
  final _maxOtCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _weekendPremiumCtrl = TextEditingController(text: '15');

  String _rateType = 'Hourly Rate';
  bool _approvalRequired = true;
  bool _strictCompliance = false;
  bool _autoNotification = true;

  @override
  void dispose() {
    _minOtCtrl.dispose();
    _maxOtCtrl.dispose();
    _rateCtrl.dispose();
    _weekendPremiumCtrl.dispose();
    super.dispose();
  }

  void _populateFields(OvertimeSettingsModel s) {
    _minOtCtrl.text = s.minOt.toString();
    _maxOtCtrl.text = (s.maxOt / 60).toStringAsFixed(1);
    _rateCtrl.text = s.hourlyRate.toString();
    _rateType = s.rateType;
    _approvalRequired = s.approvalRequired;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminOvertimeSettingsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        foregroundColor: isDark ? Colors.white : const Color(0xFF191C1E),
        elevation: 0,
        title: const Text('Policy Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF422CD8))),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E3E5), height: 1),
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading settings: $err')),
        data: (settings) {
          if (_minOtCtrl.text.isEmpty && _formKey.currentState == null) {
            _populateFields(settings);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Title and Actions
                  // Top Header with Title and Actions
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isCompactHeader = headerConstraints.maxWidth < 650;
                      final headerText = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overtime Settings',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF191C1E), fontFamily: 'Outfit'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure how the system calculates, limits, and approves extra working hours for employees across the organization.',
                            style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                          ),
                        ],
                      );

                      final headerActions = Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _populateFields(settings);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF474555),
                              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFC8C4D8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Discard Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _saveForm(settings),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF422CD8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      );

                      if (isCompactHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerText,
                            const SizedBox(height: 12),
                            headerActions,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: headerText),
                          const SizedBox(width: 16),
                          headerActions,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left: Overtime Boundaries
                              Expanded(
                                flex: isWide ? 7 : 12,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF422CD8).withValues(alpha: isDark ? 0.2 : 0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.timer_outlined, color: Color(0xFF422CD8), size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Overtime Boundaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                                Text('Set the daily threshold limits for overtime tracking.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      TextFormField(
                                        controller: _minOtCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Min OT Per Day (mins)',
                                          hintText: 'e.g. 15',
                                          prefixIcon: const Icon(Icons.av_timer_rounded, color: Color(0xFF422CD8)),
                                          suffixText: 'mins',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Minimum time required for extra work to be classified as overtime.', style: TextStyle(fontSize: 11, color: Color(0xFF777587))),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _maxOtCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Max OT Per Day (hours)',
                                          hintText: 'e.g. 4',
                                          prefixIcon: const Icon(Icons.alarm_on_rounded, color: Color(0xFF422CD8)),
                                          suffixText: 'hours',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Maximum allowable overtime per employee per day unless specifically authorized.', style: TextStyle(fontSize: 11, color: Color(0xFF777587))),
                                      const SizedBox(height: 24),

                                      // Warning Banner
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F4FF),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFD6E2FF)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline_rounded, color: Color(0xFF422CD8), size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'WorkTrack automatically flags any shifts exceeding the 12-hour total limit as a compliance risk based on labor laws.',
                                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF191C1E), height: 1.4),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isWide) const SizedBox(width: 24),

                              // Right: Approval Rules
                              if (isWide)
                                Expanded(
                                  flex: 5,
                                  child: Material(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    clipBehavior: Clip.antiAlias,
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF007834).withValues(alpha: isDark ? 0.2 : 0.08),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.shield_outlined, color: Color(0xFF007834), size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Approval Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                                    Text('Workflow & governance controls.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          SwitchListTile(
                                            activeColor: const Color(0xFF422CD8),
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Require Manager Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                            subtitle: Text('All overtime hours must be manually reviewed and approved by reporting manager before payroll.', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587))),
                                            value: _approvalRequired,
                                            onChanged: (v) => setState(() => _approvalRequired = v),
                                          ),
                                          Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                          SwitchListTile(
                                            activeColor: const Color(0xFF422CD8),
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Strict Compliance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                            subtitle: Text('Prevent clocking in if maximum daily limit is reached. Requires Admin override.', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587))),
                                            value: _strictCompliance,
                                            onChanged: (v) => setState(() => _strictCompliance = v),
                                          ),
                                          Divider(height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                          SwitchListTile(
                                            activeColor: const Color(0xFF422CD8),
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Auto-Notification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                            subtitle: Text('Notify payroll department immediately when an employee exceeds 20 hours of monthly overtime.', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587))),
                                            value: _autoNotification,
                                            onChanged: (v) => setState(() => _autoNotification = v),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Calculation & Rates Section (Span full width)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.2 : 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.payments_outlined, color: Color(0xFFD97706), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Calculation & Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                                          Text('Determine how monetary compensation is calculated for extra hours.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                LayoutBuilder(
                                  builder: (context, calcConstraints) {
                                    final isCompactCalc = calcConstraints.maxWidth < 600;
                                    final rateBillingTypeField = DropdownButtonFormField<String>(
                                      value: _rateType,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: 'Rate Billing Type',
                                        prefixIcon: const Icon(Icons.calculate_outlined, color: Color(0xFF422CD8)),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'Hourly Rate', child: Text('Time and a Half (1.5x)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Double Rate', child: Text('Double Time (2.0x)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Fixed Amount', child: Text('Fixed Daily Rate', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _rateType = val);
                                      },
                                    );

                                    final baseRateField = TextFormField(
                                      controller: _rateCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Base Rate Amount (INR / \$)',
                                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF422CD8)),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        isDense: true,
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: (v) => (v == null || double.tryParse(v) == null) ? 'Required' : null,
                                    );

                                    final weekendPremiumField = TextFormField(
                                      controller: _weekendPremiumCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Weekend Premium (%)',
                                        prefixIcon: const Icon(Icons.percent_rounded, color: Color(0xFF422CD8)),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    );

                                    if (isCompactCalc) {
                                      return Column(
                                        children: [
                                          rateBillingTypeField,
                                          const SizedBox(height: 12),
                                          baseRateField,
                                          const SizedBox(height: 12),
                                          weekendPremiumField,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: rateBillingTypeField),
                                        const SizedBox(width: 16),
                                        Expanded(child: baseRateField),
                                        const SizedBox(width: 16),
                                        Expanded(child: weekendPremiumField),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveForm(OvertimeSettingsModel settings) async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final minOtMins = int.parse(_minOtCtrl.text.trim());
      final maxOtHrs = double.parse(_maxOtCtrl.text.trim());

      final newSettings = OvertimeSettingsModel(
        companyId: user.companyId,
        minOt: minOtMins,
        maxOt: (maxOtHrs * 60).round(),
        rateType: _rateType,
        hourlyRate: double.parse(_rateCtrl.text.trim()),
        approvalRequired: _approvalRequired,
      );

      await ref.read(adminOvertimeSettingsProvider.notifier).saveSettings(newSettings);
      if (context.mounted) {
        AppNotification.showSuccess(context, 'Overtime settings updated successfully.');
      }
    }
  }
}
