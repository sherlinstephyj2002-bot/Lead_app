import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/calendar_view_type.dart';
import '../providers/calendar_provider.dart';

class CalendarHeaderWidget extends ConsumerWidget {
  const CalendarHeaderWidget({super.key});

  String _getDateHeaderString(CalendarState state) {
    final date = state.focusedDate;
    switch (state.viewType) {
      case CalendarViewType.month:
        return DateFormat('MMMM yyyy').format(date);
      case CalendarViewType.week:
        final start = date.subtract(Duration(days: date.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
      case CalendarViewType.day:
      case CalendarViewType.agenda:
        return DateFormat('EEEE, dd MMMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          return Column(
            children: [
              Row(
                children: [
                  // Today Button
                  OutlinedButton(
                    onPressed: () => notifier.setSelectedDate(DateTime.now()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B4CF0),
                      side: const BorderSide(color: Color(0xFF5B4CF0)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Today', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),

                  // Chevron Prev / Next
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          onPressed: () => notifier.navigateDate(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          onPressed: () => notifier.navigateDate(1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Current Date Range Title
                  Expanded(
                    child: Text(
                      _getDateHeaderString(state),
                      style: TextStyle(
                        fontSize: isWide ? 18 : 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // View Switcher (Desktop view)
                  if (isWide)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: CalendarViewType.values.map((vt) {
                          final isSel = state.viewType == vt;
                          return ChoiceChip(
                            label: Text(
                              vt.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            selected: isSel,
                            selectedColor: const Color(0xFF5B4CF0),
                            backgroundColor: Colors.transparent,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onSelected: (_) => notifier.setViewType(vt),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),

              // Search & Dropdown Filter Row
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onChanged: (val) => notifier.setSearchQuery(val),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          hintText: 'Search meetings, tasks, leaves, birthdays...',
                          hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Department Filter Dropdown
                  SizedBox(
                    width: 160,
                    height: 40,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        hintText: 'Department',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      value: state.selectedDepartment,
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Depts')),
                        DropdownMenuItem(value: 'Engineering', child: Text('Engineering')),
                        DropdownMenuItem(value: 'Product', child: Text('Product')),
                        DropdownMenuItem(value: 'Management', child: Text('Management')),
                        DropdownMenuItem(value: 'HR Management', child: Text('HR Dept')),
                        DropdownMenuItem(value: 'Finance', child: Text('Finance')),
                        DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                      ],
                      onChanged: (dept) => notifier.setDepartmentFilter(dept),
                    ),
                  ),

                  // Mobile View Switcher
                  if (!isWide) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<CalendarViewType>(
                      icon: const Icon(Icons.view_module_rounded, color: Color(0xFF5B4CF0)),
                      onSelected: (vt) => notifier.setViewType(vt),
                      itemBuilder: (context) => CalendarViewType.values.map((vt) {
                        return PopupMenuItem(value: vt, child: Text(vt.label));
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
