import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event_model.dart';
import '../models/calendar_event_category.dart';
import '../providers/calendar_provider.dart';
import '../screens/event_detail_screen.dart';

class CalendarMonthView extends ConsumerWidget {
  const CalendarMonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final focused = state.focusedDate;

    // Calculate Month Days Grid
    final firstDayOfMonth = DateTime(focused.year, focused.month, 1);
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
    final leadingEmptyDays = (firstDayOfMonth.weekday - 1) % 7; // Monday = 1

    final totalGridCells = leadingEmptyDays + daysInMonth;
    final totalRows = (totalGridCells / 7).ceil();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Days of Week Header Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'].map((day) {
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Month Days Grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rawHeight = constraints.maxHeight / totalRows;
                final cellHeight = rawHeight < 56.0 ? 56.0 : rawHeight;
                final isScrollable = rawHeight < 56.0;

                return GridView.builder(
                  physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: cellHeight,
                  ),
                  itemCount: totalRows * 7,
                  itemBuilder: (context, index) {
                    final dayNumber = index - leadingEmptyDays + 1;
                    final isCurrentMonthDay = dayNumber >= 1 && dayNumber <= daysInMonth;

                    if (!isCurrentMonthDay) {
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x33000000) : const Color(0x33F8FAFC),
                          border: Border.all(color: isDark ? const Color(0x1F334155) : const Color(0x1FE2E8F0)),
                        ),
                      );
                    }

                    final currentCellDate = DateTime(focused.year, focused.month, dayNumber);
                    final now = DateTime.now();
                    final isToday = now.year == currentCellDate.year && now.month == currentCellDate.month && now.day == currentCellDate.day;
                    final isSelected = state.selectedDate.year == currentCellDate.year && state.selectedDate.month == currentCellDate.month && state.selectedDate.day == currentCellDate.day;

                    final dayEvents = state.getEventsForDay(currentCellDate);

                    return InkWell(
                      onTap: () => notifier.setSelectedDate(currentCellDate),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF5B4CF0).withValues(alpha: 0.06)
                              : (isToday ? (isDark ? const Color(0x335B4CF0) : const Color(0xFFEEECFE)) : Colors.transparent),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF5B4CF0)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Day Number Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: isToday
                                      ? const BoxDecoration(color: Color(0xFF5B4CF0), shape: BoxShape.circle)
                                      : null,
                                  child: Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isToday
                                          ? Colors.white
                                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                if (dayEvents.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5B4CF0).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${dayEvents.length}',
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                                    ),
                                  ),
                              ],
                            ),
                            if (dayEvents.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: dayEvents.length > 2 ? 2 : dayEvents.length,
                                  itemBuilder: (context, evtIdx) {
                                    final evt = dayEvents[evtIdx];
                                    return GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => EventDetailDialog(event: evt),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: evt.category.color.withValues(alpha: isDark ? 0.3 : 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: evt.category.color.withValues(alpha: 0.5), width: 0.5),
                                        ),
                                        child: Text(
                                          evt.title,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : evt.category.color,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
