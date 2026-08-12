import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/calendar_view_type.dart';
import '../providers/calendar_provider.dart';
import '../widgets/calendar_header_widget.dart';
import '../widgets/calendar_sidebar_widget.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/calendar_week_view.dart';
import '../widgets/calendar_day_view.dart';
import '../widgets/calendar_agenda_view.dart';
import 'event_form_dialog.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(calendarProvider);

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enterprise Calendar',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            Text(
              'Central scheduling hub for HRMS, Meetings, Tasks, Payroll & CRM',
              style: TextStyle(fontSize: 11, color: Color(0xFFC7D2FE)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Calendar Preferences',
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.push('/calendar/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const EventFormDialog(),
          );
        },
        backgroundColor: const Color(0xFF5B4CF0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Schedule Event', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;

            return Column(
              children: [
                // Top Calendar Control Toolbar
                const CalendarHeaderWidget(),
                const SizedBox(height: 16),

                // Calendar Main Body
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Desktop Left Sidebar
                      if (isDesktop) ...[
                        const CalendarSidebarWidget(),
                        const SizedBox(width: 16),
                      ],

                      // Main View Matrix
                      Expanded(
                        child: _buildCurrentView(state.viewType),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentView(CalendarViewType viewType) {
    switch (viewType) {
      case CalendarViewType.month:
        return const CalendarMonthView();
      case CalendarViewType.week:
        return const CalendarWeekView();
      case CalendarViewType.day:
        return const CalendarDayView();
      case CalendarViewType.agenda:
        return const CalendarAgendaView();
    }
  }
}
