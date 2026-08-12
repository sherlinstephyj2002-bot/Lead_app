import 'notification_category.dart';
import 'notification_priority.dart';
import 'notification_type.dart';

class NotificationItemModel {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final NotificationCategory category;
  final NotificationPriority priority;
  final NotificationType type;
  final bool isRead;
  final bool isPinned;
  final bool isArchived;
  final String? actionLabel;
  final String? actionRoute;
  final String? relatedId;
  final String? senderName;
  final String? senderAvatar;

  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.priority,
    required this.type,
    this.isRead = false,
    this.isPinned = false,
    this.isArchived = false,
    this.actionLabel,
    this.actionRoute,
    this.relatedId,
    this.senderName,
    this.senderAvatar,
  });

  NotificationItemModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? timestamp,
    NotificationCategory? category,
    NotificationPriority? priority,
    NotificationType? type,
    bool? isRead,
    bool? isPinned,
    bool? isArchived,
    String? actionLabel,
    String? actionRoute,
    String? relatedId,
    String? senderName,
    String? senderAvatar,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      actionLabel: actionLabel ?? this.actionLabel,
      actionRoute: actionRoute ?? this.actionRoute,
      relatedId: relatedId ?? this.relatedId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }
}
