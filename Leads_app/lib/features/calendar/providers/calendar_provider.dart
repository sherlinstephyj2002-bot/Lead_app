import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:worktrack/features/company_admin/models/holiday_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import '../models/calendar_event_category.dart';
import '../models/calendar_event_model.dart';
import '../models/calendar_view_type.dart';
import '../models/calendar_settings_model.dart';

class CalendarState {
  final List<CalendarEventModel> events;
  final CalendarViewType viewType;
  final DateTime selectedDate;
  final DateTime focusedDate;
  final String searchQuery;
  final Set<CalendarEventCategory> selectedCategories;
  final String? selectedDepartment;
  final CalendarSettingsModel settings;

  const CalendarState({
    required this.events,
    this.viewType = CalendarViewType.month,
    required this.selectedDate,
    required this.focusedDate,
    this.searchQuery = '',
    this.selectedCategories = const {},
    this.selectedDepartment,
    required this.settings,
  });

  List<CalendarEventModel> get filteredEvents {
    return events.where((e) {
      // Category filter
      if (selectedCategories.isNotEmpty && !selectedCategories.contains(e.category)) {
        return false;
      }

      // Department filter
      if (selectedDepartment != null && selectedDepartment != 'All' && e.department != selectedDepartment) {
        return false;
      }

      // Search Query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(q);
        final matchDesc = e.description.toLowerCase().contains(q);
        final matchEmp = (e.assignedEmployee ?? '').toLowerCase().contains(q);
        final matchType = e.eventType.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc && !matchEmp && !matchType) return false;
      }

      return true;
    }).toList();
  }

  List<CalendarEventModel> getEventsForDay(DateTime day) {
    return filteredEvents.where((e) {
      final start = e.startDateTime;
      return start.year == day.year && start.month == day.month && start.day == day.day;
    }).toList();
  }

  List<CalendarEventModel> get upcomingEvents {
    final now = DateTime.now();
    final list = filteredEvents.where((e) => e.startDateTime.isAfter(now.subtract(const Duration(hours: 2)))).toList();
    list.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return list;
  }

  List<CalendarEventModel> get upcomingHolidays {
    return filteredEvents.where((e) => e.category == CalendarEventCategory.holidays).toList();
  }

  List<CalendarEventModel> get upcomingBirthdays {
    return filteredEvents.where((e) => e.category == CalendarEventCategory.birthdays).toList();
  }

  CalendarState copyWith({
    List<CalendarEventModel>? events,
    CalendarViewType? viewType,
    DateTime? selectedDate,
    DateTime? focusedDate,
    String? searchQuery,
    Set<CalendarEventCategory>? selectedCategories,
    String? selectedDepartment,
    bool clearDepartment = false,
    CalendarSettingsModel? settings,
  }) {
    return CalendarState(
      events: events ?? this.events,
      viewType: viewType ?? this.viewType,
      selectedDate: selectedDate ?? this.selectedDate,
      focusedDate: focusedDate ?? this.focusedDate,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedDepartment: clearDepartment ? null : (selectedDepartment ?? this.selectedDepartment),
      settings: settings ?? this.settings,
    );
  }
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier()
      : super(CalendarState(
          events: _getInitialMockEvents(),
          selectedDate: DateTime.now(),
          focusedDate: DateTime.now(),
          settings: const CalendarSettingsModel(),
        ));

  static List<CalendarEventModel> _getInitialMockEvents() {
    return [];
  }

  void setHolidays(List<HolidayModel> holidays) {
    final holidayEvents = holidays.where((h) => h.status.toLowerCase() != 'deleted').map((h) {
      return CalendarEventModel(
        id: h.holidayId,
        title: h.holidayName,
        description: h.description.isNotEmpty ? h.description : '${h.holidayType} Holiday',
        category: CalendarEventCategory.holidays,
        eventType: h.holidayType,
        startDateTime: DateTime(h.holidayDate.year, h.holidayDate.month, h.holidayDate.day, 9, 0),
        endDateTime: DateTime(h.holidayDate.year, h.holidayDate.month, h.holidayDate.day, 18, 0),
        isAllDay: true,
        location: h.branchId != null && h.branchId!.isNotEmpty ? 'Branch: ${h.branchId}' : 'All Locations',
        recurringPattern: h.isRecurring ? 'Yearly' : 'None',
        status: h.status == 'active' ? 'Approved' : 'Pending',
        priority: h.holidayType == 'National' ? 'High' : 'Medium',
      );
    }).toList();

    final nonHolidayEvents = state.events.where((e) => e.category != CalendarEventCategory.holidays).toList();
    state = state.copyWith(events: [...holidayEvents, ...nonHolidayEvents]);
  }

  void setViewType(CalendarViewType type) {
    state = state.copyWith(viewType: type);
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date, focusedDate: date);
  }

  void navigateDate(int step) {
    final curr = state.focusedDate;
    late DateTime next;
    switch (state.viewType) {
      case CalendarViewType.month:
        next = DateTime(curr.year, curr.month + step, 1);
        break;
      case CalendarViewType.week:
        next = curr.add(Duration(days: 7 * step));
        break;
      case CalendarViewType.day:
      case CalendarViewType.agenda:
        next = curr.add(Duration(days: step));
        break;
    }
    state = state.copyWith(focusedDate: next, selectedDate: next);
  }

  void setSearchQuery(String q) {
    state = state.copyWith(searchQuery: q);
  }

  void toggleCategoryFilter(CalendarEventCategory category) {
    final set = Set<CalendarEventCategory>.from(state.selectedCategories);
    if (set.contains(category)) {
      set.remove(category);
    } else {
      set.add(category);
    }
    state = state.copyWith(selectedCategories: set);
  }

  void setDepartmentFilter(String? dept) {
    state = state.copyWith(selectedDepartment: dept);
  }

  void addEvent(CalendarEventModel event) {
    final updated = [...state.events, event];
    state = state.copyWith(events: updated);
  }

  void updateEvent(CalendarEventModel event) {
    final updated = state.events.map((e) => e.id == event.id ? event : e).toList();
    state = state.copyWith(events: updated);
  }

  void deleteEvent(String id) {
    final updated = state.events.where((e) => e.id != id).toList();
    state = state.copyWith(events: updated);
  }

  void updateSettings(CalendarSettingsModel settings) {
    state = state.copyWith(settings: settings);
  }
}

final calendarProvider = StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  final notifier = CalendarNotifier();

  ref.listen<AsyncValue<List<HolidayModel>>>(adminHolidaysProvider, (prev, next) {
    next.whenData((holidays) {
      notifier.setHolidays(holidays);
    });
  });

  final initialHolidays = ref.read(adminHolidaysProvider).value;
  if (initialHolidays != null) {
    notifier.setHolidays(initialHolidays);
  }

  return notifier;
});
