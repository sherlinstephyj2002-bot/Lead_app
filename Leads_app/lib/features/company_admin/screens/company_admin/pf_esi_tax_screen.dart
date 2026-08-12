import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/pf_esi_tax_settings_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class PfEsiTaxScreen extends ConsumerStatefulWidget {
  const PfEsiTaxScreen({super.key});

  @override
  ConsumerState<PfEsiTaxScreen> createState() => _PfEsiTaxScreenState();
}

class _PfEsiTaxScreenState extends ConsumerState<PfEsiTaxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pfEmployerCtrl = TextEditingController();
  final _pfEmployeeCtrl = TextEditingController();
  final _esiEmployerCtrl = TextEditingController();
  final _esiEmployeeCtrl = TextEditingController();

  bool _pfEnabled = false;
  bool _esiEnabled = false;
  bool _profTaxEnabled = false;
  final List<Map<String, dynamic>> _taxSlabs = [];

  @override
  void dispose() {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PF, ESI & Statutory Taxes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Configure employee statutory contributions and tax brackets', style: TextStyle(fontSize: 11, color: Colors.white70)),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
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
                        title: const Text('Enable Provident Fund (PF) Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Calculates and deducts PF contribution from monthly payroll.'),
                        value: _pfEnabled,
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
                        title: const Text('Enable ESI Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Calculates medical benefits ESI deductions.'),
                        value: _esiEnabled,
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
                        title: const Text('Enable Professional Tax (PTax) / Income Tax Deductions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Deducts monthly tax based on the defined brackets/slabs.'),
                        value: _profTaxEnabled,
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
                            const Text('Tax Brackets / Slabs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                            ElevatedButton.icon(
                              onPressed: _showAddSlabDialog,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Slab', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
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
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Text('No tax slabs configured yet. Click Add Slab.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _taxSlabs.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final slab = _taxSlabs[index];
                              return Card(
                                elevation: 0,
                                color: const Color(0xFFF8FAFC),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  title: Text('Monthly Income: INR ${slab['min']} - INR ${slab['max']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text('Deduction: INR ${slab['tax']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                  ElevatedButton(
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Statutory compliance settings updated successfully.'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Update Statutory Settings'),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF1E293B)),
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
        title: const Text('Add Tax Slab'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
