import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/payroll_settings_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class PayrollSettingsScreen extends ConsumerStatefulWidget {
  const PayrollSettingsScreen({super.key});

  @override
  ConsumerState<PayrollSettingsScreen> createState() => _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends ConsumerState<PayrollSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startDayCtrl = TextEditingController();
  final _endDayCtrl = TextEditingController();
  final _creditDayCtrl = TextEditingController();
  final _workingDaysCtrl = TextEditingController();

  final List<String> _weeklyOffValues = [];
  final List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void dispose() {
    _startDayCtrl.dispose();
    _endDayCtrl.dispose();
    _creditDayCtrl.dispose();
    _workingDaysCtrl.dispose();
    super.dispose();
  }

  void _populateFields(PayrollSettingsModel s) {
    _startDayCtrl.text = s.payrollStartDate.toString();
    _endDayCtrl.text = s.payrollEndDate.toString();
    _creditDayCtrl.text = s.salaryCreditDate.toString();
    _workingDaysCtrl.text = s.workingDays.toString();

    _weeklyOffValues.clear();
    _weeklyOffValues.addAll(s.weeklyOff);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(adminPayrollSettingsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payroll Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Configure salary credit schedules and calendar cycles', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading payroll settings: $err')),
        data: (settings) {
          if (_startDayCtrl.text.isEmpty && _formKey.currentState == null) {
            _populateFields(settings);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Payroll Cycle Card
                  Card(
                    elevation: 0,
                    color: isDark ? Theme.of(context).cardColor : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
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
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.date_range_rounded, color: Color(0xFF0EA5E9), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text('Monthly Salary Cycle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isCompact = constraints.maxWidth < 450;
                              final startDayField = TextFormField(
                                controller: _startDayCtrl,
                                decoration: const InputDecoration(labelText: 'Cycle Start Day', prefixIcon: Icon(Icons.start_rounded), isDense: true),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || int.tryParse(v) == null) return 'Required';
                                  final val = int.parse(v);
                                  if (val < 1 || val > 31) return 'Enter 1 to 31';
                                  return null;
                                },
                              );

                              final endDayField = TextFormField(
                                controller: _endDayCtrl,
                                decoration: const InputDecoration(labelText: 'Cycle End Day', prefixIcon: Icon(Icons.stop_rounded), isDense: true),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || int.tryParse(v) == null) return 'Required';
                                  final val = int.parse(v);
                                  if (val < 1 || val > 31) return 'Enter 1 to 31';
                                  return null;
                                },
                              );

                              if (isCompact) {
                                return Column(
                                  children: [
                                    startDayField,
                                    const SizedBox(height: 12),
                                    endDayField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: startDayField),
                                  const SizedBox(width: 12),
                                  Expanded(child: endDayField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _creditDayCtrl,
                            decoration: const InputDecoration(labelText: 'Salary Credit Day of Month', prefixIcon: Icon(Icons.payments_rounded)),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || int.tryParse(v) == null) return 'Required';
                              final val = int.parse(v);
                              if (val < 1 || val > 31) return 'Enter 1 to 31';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _workingDaysCtrl,
                            decoration: const InputDecoration(labelText: 'Standard Working Days per Month', prefixIcon: Icon(Icons.calendar_view_month_rounded)),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weekly Offs
                  Card(
                    elevation: 0,
                    color: isDark ? Theme.of(context).cardColor : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
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
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.weekend_rounded, color: Colors.teal, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Text('Weekly Off Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _daysOfWeek.map((day) {
                              final isSelected = _weeklyOffValues.contains(day);
                              return FilterChip(
                                label: Text(day),
                                selected: isSelected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _weeklyOffValues.add(day);
                                    } else {
                                      _weeklyOffValues.remove(day);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final user = ref.read(authProvider).user;
                        if (user == null) return;

                        final newSettings = PayrollSettingsModel(
                          companyId: user.companyId,
                          payrollStartDate: int.parse(_startDayCtrl.text.trim()),
                          payrollEndDate: int.parse(_endDayCtrl.text.trim()),
                          salaryCreditDate: int.parse(_creditDayCtrl.text.trim()),
                          workingDays: int.parse(_workingDaysCtrl.text.trim()),
                          weeklyOff: _weeklyOffValues,
                        );

                        await ref.read(adminPayrollSettingsProvider.notifier).saveSettings(newSettings);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payroll settings updated successfully.'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Payroll Configuration'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
