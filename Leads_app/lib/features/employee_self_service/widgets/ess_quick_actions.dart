import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ESSQuickActions extends ConsumerWidget {
  const ESSQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      _ActionItem('Apply Leave', Icons.event_busy_rounded, const Color(0xFF5B4CF0), '/ess/leave'),
      _ActionItem('Check In / Out', Icons.fingerprint_rounded, const Color(0xFF0284C7), '/attendance'),
      _ActionItem('Submit Expense', Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B), '/ess/expenses'),
      _ActionItem('Download Payslip', Icons.payments_rounded, const Color(0xFF10B981), '/ess/payslips'),
      _ActionItem('View Attendance', Icons.calendar_today_rounded, const Color(0xFF8B5CF6), '/ess/attendance'),
      _ActionItem('Upload Documents', Icons.folder_open_rounded, const Color(0xFF059669), '/ess/documents'),
      _ActionItem('Update Profile', Icons.person_outline_rounded, const Color(0xFFEC4899), '/ess/profile'),
      _ActionItem('My Tasks', Icons.task_alt_rounded, const Color(0xFF3B82F6), '/ess/tasks'),
      _ActionItem('Resignation', Icons.exit_to_app_rounded, const Color(0xFFDC2626), '/ess/resignation'),
      _ActionItem('Notifications', Icons.notifications_none_rounded, const Color(0xFFEF4444), '/notifications'),
      _ActionItem('Career Timeline', Icons.timeline_rounded, const Color(0xFFD97706), '/ess/timeline'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded, color: Color(0xFF5B4CF0), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'EMPLOYEE QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final crossCount = isWide ? 5 : 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: isWide ? 1.4 : 0.95,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final act = actions[index];
                  return InkWell(
                    onTap: () => context.push(act.route),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: act.color.withValues(alpha: isDark ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(act.icon, color: act.color, size: 18),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            act.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _ActionItem(this.title, this.icon, this.color, this.route);
}
