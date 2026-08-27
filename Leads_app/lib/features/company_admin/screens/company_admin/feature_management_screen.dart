import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/company_model.dart';
import 'package:worktrack/shared/utils/app_notification.dart';

class FeatureManagementScreen extends ConsumerStatefulWidget {
  const FeatureManagementScreen({super.key});

  @override
  ConsumerState<FeatureManagementScreen> createState() => _FeatureManagementScreenState();
}

class _FeatureManagementScreenState extends ConsumerState<FeatureManagementScreen> {
  bool _isSaving = false;

  Future<void> _toggleModule({
    required CompanyModel company,
    required String featureName,
    required bool newValue,
  }) async {
    setState(() => _isSaving = true);
    try {
      CompanyModel updatedCompany = company;
      switch (featureName) {
        case 'lead':
          updatedCompany = company.copyWith(isLeadManagementEnabled: newValue);
          break;
        case 'task':
          updatedCompany = company.copyWith(isTaskManagementEnabled: newValue);
          break;
        case 'attendance':
          updatedCompany = company.copyWith(isAttendanceEnabled: newValue);
          break;
        case 'leave':
          updatedCompany = company.copyWith(isLeaveEnabled: newValue);
          break;
        case 'payroll':
          updatedCompany = company.copyWith(isPayrollEnabled: newValue);
          break;
      }

      final repo = ref.read(companyRepositoryProvider);
      await repo.saveCompany(updatedCompany);
      
      // Refresh Riverpod company provider
      ref.invalidate(companyProvider);

      if (mounted) {
        AppNotification.showSuccess(
          context,
          '$featureName module ${newValue ? "enabled" : "disabled"} successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update feature settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Feature Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Enable or disable company application modules', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading company: $err')),
        data: (company) {
          if (company == null) {
            return const Center(child: Text('No company details found.'));
          }

          final features = [
            {
              'key': 'lead',
              'title': 'Lead Management',
              'subtitle': 'Enable lead tracking, sales pipelines, client contacts, and follow-up activities for authorized roles.',
              'icon': Icons.person_search_rounded,
              'color': const Color(0xFF3B82F6),
              'isEnabled': company.isLeadManagementEnabled,
            },
            {
              'key': 'task',
              'title': 'Task Management',
              'subtitle': 'Enable task assignment, project task tracking, priorities, and completions for authorized roles.',
              'icon': Icons.task_alt_rounded,
              'color': const Color(0xFF8B5CF6),
              'isEnabled': company.isTaskManagementEnabled,
            },
            {
              'key': 'attendance',
              'title': 'Attendance & Shifts',
              'subtitle': 'Enable employee daily check-ins, geofencing, shift timetables, and attendance regularization.',
              'icon': Icons.fingerprint_rounded,
              'color': const Color(0xFF10B981),
              'isEnabled': company.isAttendanceEnabled,
            },
            {
              'key': 'leave',
              'title': 'Leave Management',
              'subtitle': 'Enable leave applications, leave balances, policy rules, and multi-level manager approvals.',
              'icon': Icons.event_note_rounded,
              'color': const Color(0xFFEF4444),
              'isEnabled': company.isLeaveEnabled,
            },
            {
              'key': 'payroll',
              'title': 'Payroll & Salary',
              'subtitle': 'Enable salary component structures, monthly payroll cycle processing, statutory rates, and payslips.',
              'icon': Icons.payments_rounded,
              'color': const Color(0xFFF59E0B),
              'isEnabled': company.isPayrollEnabled,
            },
          ];

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Banner
                    Card(
                      elevation: 0,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: borderCol),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.tune_rounded, size: 24, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Administrative Module Controls',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Disabling a module hides its navigation tabs, reports, and notifications across your company while retaining underlying data intact.',
                                    style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Company Application Modules',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                    const SizedBox(height: 12),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: features.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final feat = features[index];
                        final isEnabled = feat['isEnabled'] as bool;
                        final color = feat['color'] as Color;

                        return Card(
                          elevation: 0,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderCol),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(feat['icon'] as IconData, color: color, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            feat['title'] as String,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isEnabled
                                                  ? Colors.green.withValues(alpha: 0.12)
                                                  : Colors.grey.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isEnabled ? 'ENABLED' : 'DISABLED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isEnabled ? Colors.green : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        feat['subtitle'] as String,
                                        style: TextStyle(fontSize: 11, color: subtitleColor, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Switch.adaptive(
                                  value: isEnabled,
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  onChanged: _isSaving
                                      ? null
                                      : (val) => _toggleModule(
                                            company: company,
                                            featureName: feat['key'] as String,
                                            newValue: val,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              if (_isSaving)
                Container(
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}
