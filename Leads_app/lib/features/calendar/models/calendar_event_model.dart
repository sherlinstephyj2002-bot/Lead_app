import 'calendar_event_category.dart';

class CalendarEventModel {
  final String id;
  final String title;
  final String description;
  final CalendarEventCategory category;
  final String eventType;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isAllDay;
  final String? location;
  final String? assignedEmployee;
  final String? department;
  final String priority; // 'High', 'Medium', 'Low', 'Urgent'
  final String status;   // 'Scheduled', 'Approved', 'Pending', 'Completed'
  final List<String> attachments;
  final String? notes;
  final String? actionRoute;
  final String? actionLabel;
  final String recurringPattern; // 'None', 'Daily', 'Weekly', 'Monthly', 'Yearly'
  final int reminderOffsetMinutes; // 10, 30, 60, 1440

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.eventType,
    required this.startDateTime,
    required this.endDateTime,
    this.isAllDay = false,
    this.location,
    this.assignedEmployee,
    this.department,
    this.priority = 'Medium',
    this.status = 'Scheduled',
    this.attachments = const [],
    this.notes,
    this.actionRoute,
    this.actionLabel,
    this.recurringPattern = 'None',
    this.reminderOffsetMinutes = 30,
  });

  CalendarEventModel copyWith({
    String? id,
    String? title,
    String? description,
    CalendarEventCategory? category,
    String? eventType,
    DateTime? startDateTime,
    DateTime? endDateTime,
    bool? isAllDay,
    String? location,
    String? assignedEmployee,
    String? department,
    String? priority,
    String? status,
    List<String>? attachments,
    String? notes,
    String? actionRoute,
    String? actionLabel,
    String? recurringPattern,
    int? reminderOffsetMinutes,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      eventType: eventType ?? this.eventType,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      department: department ?? this.department,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      notes: notes ?? this.notes,
      actionRoute: actionRoute ?? this.actionRoute,
      actionLabel: actionLabel ?? this.actionLabel,
      recurringPattern: recurringPattern ?? this.recurringPattern,
      reminderOffsetMinutes: reminderOffsetMinutes ?? this.reminderOffsetMinutes,
    );
  }
}
