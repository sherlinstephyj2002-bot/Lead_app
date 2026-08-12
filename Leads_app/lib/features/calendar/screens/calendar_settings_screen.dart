import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_settings_model.dart';
import '../providers/calendar_provider.dart';

class CalendarSettingsScreen extends ConsumerWidget {
  const CalendarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(calendarProvider);
    final settings = state.settings;
    final notifier = ref.read(calendarProvider.notifier);

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
          'Calendar Settings',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('WORKFORCE SCHEDULE CONFIGURATION', 'Working days, business hours & shift rules', isDark),
                const SizedBox(height: 12),

                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_view_week_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Default Shift Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(settings.defaultShift),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Business Working Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${settings.businessStartTime} - ${settings.businessEndTime}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                      title: const Text('Monthly Payroll Disbursement Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Day ${settings.payrollDate} of every month'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _buildSectionHeader('REMINDERS & TIME ZONE', 'Default alert offset & regional time settings', isDark),
                const SizedBox(height: 12),

                _buildCardContainer(
                  context: context,
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF5B4CF0)),
                      title: const Text('Default Event Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${settings.defaultReminderMinutes} Minutes Before Event'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('Company Time Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(settings.timeZone),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                    _buildDivider(isDark),
                    ListTile(
                      leading: const Icon(Icons.today_rounded, color: Color(0xFF5B4CF0)),
                      title: const Text('First Day of Week', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(settings.firstDayOfWeek == 1 ? 'Monday' : 'Sunday'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Color(0xFF5B4CF0),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required BuildContext context, required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }
}
