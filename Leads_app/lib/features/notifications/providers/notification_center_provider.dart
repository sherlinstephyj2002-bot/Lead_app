import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/app_notification_model.dart';
import '../../../shared/providers/providers.dart';
import '../models/notification_category.dart';
import '../models/notification_priority.dart';
import '../models/notification_type.dart';
import '../models/notification_item_model.dart';
import '../models/notification_settings_model.dart';

class NotificationCenterState {
  final List<NotificationItemModel> notifications;
  final NotificationSettingsModel settings;
  final String searchQuery;
  final NotificationCategory? selectedCategory;
  final NotificationPriority? selectedPriority;
  final String dateFilter; // 'All', 'Today', 'Yesterday', 'This Week', 'Older'
  final String readFilter; // 'All', 'Unread', 'Read', 'Pinned'
  final Set<String> selectedNotificationIds;

  const NotificationCenterState({
    required this.notifications,
    required this.settings,
    this.searchQuery = '',
    this.selectedCategory,
    this.selectedPriority,
    this.dateFilter = 'All',
    this.readFilter = 'All',
    this.selectedNotificationIds = const {},
  });

  int get unreadCount => notifications.where((n) => !n.isRead && !n.isArchived).length;

  List<NotificationItemModel> get filteredNotifications {
    final now = DateTime.now();
    return notifications.where((n) {
      if (n.isArchived) return false;

      // Search Query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        final matchDesc = n.description.toLowerCase().contains(q);
        final matchCat = n.category.displayName.toLowerCase().contains(q);
        if (!matchTitle && !matchDesc && !matchCat) return false;
      }

      // Category filter
      if (selectedCategory != null && n.category != selectedCategory) {
        return false;
      }

      // Priority filter
      if (selectedPriority != null && n.priority != selectedPriority) {
        return false;
      }

      // Read status filter
      if (readFilter == 'Unread' && n.isRead) return false;
      if (readFilter == 'Read' && !n.isRead) return false;
      if (readFilter == 'Pinned' && !n.isPinned) return false;

      // Date filter
      if (dateFilter == 'Today') {
        final startOfDay = DateTime(now.year, now.month, now.day);
        if (n.timestamp.isBefore(startOfDay)) return false;
      } else if (dateFilter == 'Yesterday') {
        final startOfYest = DateTime(now.year, now.month, now.day - 1);
        final endOfYest = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
        if (n.timestamp.isBefore(startOfYest) || n.timestamp.isAfter(endOfYest)) return false;
      } else if (dateFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfDayOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (n.timestamp.isBefore(startOfDayOfWeek)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.timestamp.compareTo(a.timestamp);
      });
  }

  NotificationCenterState copyWith({
    List<NotificationItemModel>? notifications,
    NotificationSettingsModel? settings,
    String? searchQuery,
    NotificationCategory? selectedCategory,
    bool clearCategory = false,
    NotificationPriority? selectedPriority,
    bool clearPriority = false,
    String? dateFilter,
    String? readFilter,
    Set<String>? selectedNotificationIds,
  }) {
    return NotificationCenterState(
      notifications: notifications ?? this.notifications,
      settings: settings ?? this.settings,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedPriority: clearPriority ? null : (selectedPriority ?? this.selectedPriority),
      dateFilter: dateFilter ?? this.dateFilter,
      readFilter: readFilter ?? this.readFilter,
      selectedNotificationIds: selectedNotificationIds ?? this.selectedNotificationIds,
    );
  }
}

class NotificationCenterNotifier extends StateNotifier<NotificationCenterState> {
  final Ref _ref;

  NotificationCenterNotifier(this._ref)
      : super(const NotificationCenterState(
          notifications: [], // 100% Real Backend Data only. Zero mock items.
          settings: NotificationSettingsModel(),
        ));

  void syncFromBackend(List<AppNotificationModel> backendNotifs) {
    final mappedList = backendNotifs.map((b) {
      final typeStr = b.notificationType.toUpperCase();
      final titleUpper = b.title.toUpperCase();
      final bodyUpper = b.body.toUpperCase();

      NotificationCategory category = NotificationCategory.system;
      if (typeStr.contains('LEAVE') || titleUpper.contains('LEAVE') || bodyUpper.contains('LEAVE')) {
        category = NotificationCategory.leaves;
      } else if (typeStr.contains('ATTENDANCE') || typeStr.contains('CHECKIN') || typeStr.contains('CHECKOUT') || titleUpper.contains('ATTENDANCE') || bodyUpper.contains('ATTENDANCE')) {
        category = NotificationCategory.attendance;
      } else if (typeStr.contains('PAYROLL') || typeStr.contains('PAYSLIP') || typeStr.contains('SALARY') || titleUpper.contains('PAYROLL') || bodyUpper.contains('PAYSLIP')) {
        category = NotificationCategory.payroll;
      } else if (typeStr.contains('ORDER') || typeStr.contains('INVOICE') || titleUpper.contains('ORDER') || bodyUpper.contains('ORDER')) {
        category = NotificationCategory.orders;
      } else if (typeStr.contains('EMPLOYEE') || typeStr.contains('HR') || typeStr.contains('REQUEST') || titleUpper.contains('REQUEST')) {
        category = NotificationCategory.hr;
      } else if (typeStr.contains('TASK') || titleUpper.contains('TASK')) {
        category = NotificationCategory.tasks;
      } else if (typeStr.contains('SUBSCRIPTION') || typeStr.contains('BILLING')) {
        category = NotificationCategory.subscription;
      } else if (typeStr.contains('HOLIDAY') || titleUpper.contains('HOLIDAY') || titleUpper.contains('CALENDAR') || typeStr.contains('ANNOUNCEMENT')) {
        category = NotificationCategory.announcements;
      } else if (typeStr.contains('EXPORT') || typeStr.contains('REPORT') || typeStr.contains('OVERRIDE') || titleUpper.contains('REPORT') || titleUpper.contains('OVERRIDE') || titleUpper.contains('APPROVAL')) {
        category = NotificationCategory.system;
      }

      NotificationPriority priority = NotificationPriority.medium;
      if (typeStr.contains('URGENT') || typeStr.contains('LATE') || typeStr.contains('FAIL')) {
        priority = NotificationPriority.high;
      }

      NotificationType notifType = NotificationType.generalAnnouncement;
      if (typeStr.contains('LEAVE') || titleUpper.contains('LEAVE')) {
        notifType = NotificationType.leaveRequested;
      } else if (typeStr.contains('ATTENDANCE') || titleUpper.contains('ATTENDANCE')) {
        notifType = NotificationType.lateAttendance;
      } else if (typeStr.contains('PAYROLL') || titleUpper.contains('PAYROLL')) {
        notifType = NotificationType.payrollGenerated;
      } else if (typeStr.contains('ORDER') || titleUpper.contains('ORDER')) {
        notifType = NotificationType.orderAssigned;
      } else if (typeStr.contains('EMPLOYEE') || titleUpper.contains('EMPLOYEE')) {
        notifType = NotificationType.employeeUpdated;
      } else if (typeStr.contains('TASK') || titleUpper.contains('TASK')) {
        notifType = NotificationType.taskAssigned;
      } else if (typeStr.contains('SUBSCRIPTION')) {
        notifType = NotificationType.planExpiring;
      }

      String? actionLabel;
      String? actionRoute;

      if (typeStr.contains('LEAVE') || titleUpper.contains('LEAVE') || bodyUpper.contains('LEAVE')) {
        actionLabel = 'View Leaves';
        actionRoute = '/leaves';
      } else if (typeStr.contains('ATTENDANCE') || typeStr.contains('CHECKIN') || typeStr.contains('CHECKOUT') || titleUpper.contains('ATTENDANCE') || bodyUpper.contains('ATTENDANCE')) {
        actionLabel = 'View Attendance';
        actionRoute = '/attendance';
      } else if (typeStr.contains('PAYROLL') || typeStr.contains('PAYSLIP') || typeStr.contains('SALARY') || titleUpper.contains('PAYROLL') || bodyUpper.contains('PAYSLIP')) {
        actionLabel = 'View Payslips';
        actionRoute = '/company-admin/payroll';
      } else if (typeStr.contains('ORDER') || typeStr.contains('INVOICE') || titleUpper.contains('ORDER') || bodyUpper.contains('ORDER')) {
        actionLabel = 'View Orders';
        actionRoute = '/orders';
      } else if (typeStr.contains('EMPLOYEE') || typeStr.contains('HR') || typeStr.contains('REQUEST') || titleUpper.contains('REQUEST')) {
        actionLabel = 'View Requests';
        actionRoute = '/employee-requests';
      } else if (typeStr.contains('EXPORT') || typeStr.contains('REPORT') || typeStr.contains('OVERRIDE') || titleUpper.contains('REPORT') || titleUpper.contains('OVERRIDE') || titleUpper.contains('APPROVAL') || bodyUpper.contains('REPORT')) {
        actionLabel = 'View Reports';
        actionRoute = '/reports';
      } else if (typeStr.contains('HOLIDAY') || titleUpper.contains('HOLIDAY') || titleUpper.contains('CALENDAR') || bodyUpper.contains('HOLIDAY')) {
        actionLabel = 'View Holidays';
        actionRoute = '/company-admin/holidays';
      } else if (typeStr.contains('TASK') || titleUpper.contains('TASK') || bodyUpper.contains('TASK')) {
        actionLabel = 'View Tasks';
        actionRoute = '/tasks';
      } else if (typeStr.contains('SUBSCRIPTION') || typeStr.contains('BILLING')) {
        actionLabel = 'View Subscription';
        actionRoute = '/subscription';
      }

      return NotificationItemModel(
        id: b.notificationId,
        title: b.title,
        description: b.body,
        timestamp: b.createdAt,
        category: category,
        priority: priority,
        type: notifType,
        isRead: b.isRead,
        actionLabel: actionLabel,
        actionRoute: actionRoute,
      );
    }).toList();

    state = state.copyWith(notifications: mappedList);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(NotificationCategory? category) {
    if (category == state.selectedCategory) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  void setPriorityFilter(NotificationPriority? priority) {
    if (priority == state.selectedPriority) {
      state = state.copyWith(clearPriority: true);
    } else {
      state = state.copyWith(selectedPriority: priority);
    }
  }

  void setDateFilter(String filter) {
    state = state.copyWith(dateFilter: filter);
  }

  void setReadFilter(String filter) {
    state = state.copyWith(readFilter: filter);
  }

  void toggleReadStatus(String id) {
    markAsRead(id);
  }

  void markAsRead(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
    _ref.read(notificationsProvider.notifier).markAsRead(id);
  }

  void togglePinStatus(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isPinned: !n.isPinned);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  void deleteNotification(String id) {
    final updated = state.notifications.where((n) => n.id != id).toList();
    final updatedSelected = Set<String>.from(state.selectedNotificationIds)..remove(id);
    state = state.copyWith(notifications: updated, selectedNotificationIds: updatedSelected);
    _ref.read(notificationsProvider.notifier).deleteNotification(id);
  }

  void archiveNotification(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isArchived: true);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  void markAllAsRead() {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated);
    _ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  void clearAll() {
    state = state.copyWith(notifications: []);
    _ref.read(notificationsProvider.notifier).clearAll();
  }

  void clearReadNotifications() {
    final updated = state.notifications.where((n) => !n.isRead).toList();
    state = state.copyWith(notifications: updated);
  }

  void toggleSelectNotification(String id) {
    final selected = Set<String>.from(state.selectedNotificationIds);
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    state = state.copyWith(selectedNotificationIds: selected);
  }

  void selectAllFiltered() {
    final ids = state.filteredNotifications.map((n) => n.id).toSet();
    state = state.copyWith(selectedNotificationIds: ids);
  }

  void clearSelection() {
    state = state.copyWith(selectedNotificationIds: {});
  }

  void deleteSelected() {
    final selected = state.selectedNotificationIds;
    if (selected.isEmpty) return;
    for (final id in selected) {
      _ref.read(notificationsProvider.notifier).deleteNotification(id);
    }
    final updated = state.notifications.where((n) => !selected.contains(n.id)).toList();
    state = state.copyWith(notifications: updated, selectedNotificationIds: {});
  }

  void pinSelected() {
    final selected = state.selectedNotificationIds;
    if (selected.isEmpty) return;
    final updated = state.notifications.map((n) {
      if (selected.contains(n.id)) {
        return n.copyWith(isPinned: true);
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: updated);
  }

  void updateSettings(NotificationSettingsModel newSettings) {
    state = state.copyWith(settings: newSettings);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      clearCategory: true,
      clearPriority: true,
      dateFilter: 'All',
      readFilter: 'All',
      selectedNotificationIds: {},
    );
  }
}

final notificationCenterProvider =
    StateNotifierProvider<NotificationCenterNotifier, NotificationCenterState>((ref) {
  return NotificationCenterNotifier(ref);
});
