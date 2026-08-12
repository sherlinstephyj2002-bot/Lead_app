import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event_model.dart';
import '../providers/calendar_provider.dart';
import 'event_card_widget.dart';
import '../screens/event_detail_screen.dart';

class CalendarAgendaView extends ConsumerWidget {
  const CalendarAgendaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(calendarProvider);
    final events = state.filteredEvents;

    // Group Events by Date String
    final Map<String, List<CalendarEventModel>> grouped = {};
    for (var evt in events) {
      final key = DateFormat('EEEE, dd MMMM yyyy').format(evt.startDateTime);
      grouped.putIfAbsent(key, () => []).add(evt);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.view_agenda_rounded, color: Color(0xFF5B4CF0), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHRONOLOGICAL AGENDA FEED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All Upcoming Schedule Entries (${events.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_note_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 12),
                        Text(
                          'No scheduled agenda items found matching current filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final dateGroupHeader = grouped.keys.elementAt(index);
                      final items = grouped[dateGroupHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            margin: const EdgeInsets.only(top: 8, bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEECFE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dateGroupHeader,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                              ),
                            ),
                          ),
                          ...items.map((evt) {
                            return EventCardWidget(
                              event: evt,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => EventDetailDialog(event: evt),
                                );
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
