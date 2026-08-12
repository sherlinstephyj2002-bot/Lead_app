import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/features/company_admin/models/leave_policy_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';

class LeavePolicyScreen extends ConsumerStatefulWidget {
  const LeavePolicyScreen({super.key});

  @override
  ConsumerState<LeavePolicyScreen> createState() => _LeavePolicyScreenState();
}

class _LeavePolicyScreenState extends ConsumerState<LeavePolicyScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _daysCtrls = {};
  final Map<String, bool> _carryForwardValues = {};
  final Map<String, String> _approvalFlowValues = {};

  final List<String> _leaveTypes = ['Annual', 'Casual', 'Sick', 'Paternity', 'Loss Of Pay'];

  @override
  void initState() {
    super.initState();
    for (final type in _leaveTypes) {
      _daysCtrls[type] = TextEditingController();
      _carryForwardValues[type] = false;
      _approvalFlowValues[type] = 'Company Admin';
    }
  }

  @override
  void dispose() {
    for (final ctrl in _daysCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _populateFields(LeavePolicyModel model) {
    for (final type in _leaveTypes) {
      final policyItem = model.policies[type] ?? LeavePolicyItem(leaveType: type);
      _daysCtrls[type]!.text = policyItem.maxDays.toString();
      _carryForwardValues[type] = policyItem.carryForward;
      _approvalFlowValues[type] = policyItem.approvalFlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyAsync = ref.watch(adminLeavePolicyProvider);

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
          child: Container(color: const Color(0xFFE0E3E5), height: 1),
        ),
      ),
      body: policyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading policy: $err')),
        data: (policyModel) {
          if (_daysCtrls['Annual']!.text.isEmpty && _formKey.currentState == null) {
            _populateFields(policyModel);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header with Discard & Save Actions (Matching Overtime Settings)
                  // Page Header with Discard & Save Actions (Matching Overtime Settings)
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isCompactHeader = headerConstraints.maxWidth < 650;
                      final headerText = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leave Policy Config',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF191C1E), fontFamily: 'Outfit'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure annual days allowance, carry-forward rules, and approval flows across all workforce leave categories.',
                            style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555)),
                          ),
                        ],
                      );

                      final headerActions = Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _populateFields(policyModel);
                              setState(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : const Color(0xFF474555),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Discard Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _savePolicy(policyModel),
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

                  // 2-Column Responsive Bento Layout (Matching Overtime Settings)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;

                      if (isWide) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeavePolicyCard('Annual')),
                                const SizedBox(width: 24),
                                Expanded(child: _buildLeavePolicyCard('Casual')),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeavePolicyCard('Sick')),
                                const SizedBox(width: 24),
                                Expanded(child: _buildLeavePolicyCard('Paternity')),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildLeavePolicyCard('Loss Of Pay')),
                                const SizedBox(width: 24),
                                Expanded(child: _buildPolicyNoticeCard()),
                              ],
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            for (final type in _leaveTypes) ...[
                              _buildLeavePolicyCard(type),
                              const SizedBox(height: 20),
                            ],
                            _buildPolicyNoticeCard(),
                          ],
                        );
                      }
                    },
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

  Widget _buildLeavePolicyCard(String leaveType) {
    Color cardColor = const Color(0xFF422CD8);
    IconData cardIcon = Icons.directions_car_filled_rounded;
    String subText = 'Configures yearly allowance and manager routing.';

    if (leaveType == 'Casual') {
      cardColor = const Color(0xFF0EA5E9);
      cardIcon = Icons.beach_access_rounded;
      subText = 'Used for unexpected personal time off requests.';
    } else if (leaveType == 'Sick') {
      cardColor = const Color(0xFFEF4444);
      cardIcon = Icons.medical_services_rounded;
      subText = 'Requires medical certificate for multi-day leaves.';
    } else if (leaveType == 'Paternity') {
      cardColor = const Color(0xFF8B5CF6);
      cardIcon = Icons.face_rounded;
      subText = 'Special parental leave for eligible employees.';
    } else if (leaveType == 'Loss Of Pay') {
      cardColor = const Color(0xFF64748B);
      cardIcon = Icons.money_off_rounded;
      subText = 'Unpaid leave days processed directly into payroll.';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cardIcon, color: cardColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$leaveType Leave Policy',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF191C1E)),
                    ),
                    Text(subText, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final isCompactCard = cardConstraints.maxWidth < 450;
              final maxAnnualDaysField = TextFormField(
                controller: _daysCtrls[leaveType],
                decoration: InputDecoration(
                  labelText: 'Max Annual Days *',
                  prefixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF422CD8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
              );

              final approvalFlowField = DropdownButtonFormField<String>(
                value: _approvalFlowValues[leaveType],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Approval Flow *',
                  prefixIcon: const Icon(Icons.verified_user_outlined, color: Color(0xFF422CD8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'Company Admin', child: Text('Admin Approvals', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Direct Manager', child: Text('Manager Only', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'HR Admin', child: Text('HR Approvals', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _approvalFlowValues[leaveType] = val;
                    });
                  }
                },
              );

              if (isCompactCard) {
                return Column(
                  children: [
                    maxAnnualDaysField,
                    const SizedBox(height: 12),
                    approvalFlowField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: maxAnnualDaysField),
                  const SizedBox(width: 16),
                  Expanded(child: approvalFlowField),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Material(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
              ),
              child: SwitchListTile(
                activeColor: const Color(0xFF422CD8),
                contentPadding: EdgeInsets.zero,
                title: Text('Carry Forward Unused Leaves', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF191C1E))),
                subtitle: Text('Allows leaves to roll over into the next financial year.', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF777587))),
                value: _carryForwardValues[leaveType]!,
                onChanged: (val) {
                  setState(() {
                    _carryForwardValues[leaveType] = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNoticeCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFD6E2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Color(0xFF422CD8), size: 24),
              const SizedBox(width: 12),
              Text('Workforce Compliance Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF191C1E))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'WorkTrack automatically enforces maximum annual quota limits and routes approval requests according to the selected workflow hierarchy.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Unused leave balances subject to carry-forward will automatically transfer during financial year rollover.',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555), height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _savePolicy(LeavePolicyModel policyModel) async {
    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider).user;
      if (user == null) return;

      final Map<String, LeavePolicyItem> updatedPolicies = {};
      for (final type in _leaveTypes) {
        updatedPolicies[type] = LeavePolicyItem(
          leaveType: type,
          maxDays: int.parse(_daysCtrls[type]!.text.trim()),
          carryForward: _carryForwardValues[type]!,
          approvalFlow: _approvalFlowValues[type]!,
        );
      }

      final newModel = LeavePolicyModel(
        companyId: user.companyId,
        policies: updatedPolicies,
      );

      await ref.read(adminLeavePolicyProvider.notifier).savePolicy(newModel);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave policies updated successfully.'), backgroundColor: Colors.green),
        );
      }
    }
  }
}

