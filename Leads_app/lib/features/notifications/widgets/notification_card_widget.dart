import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/notification_item_model.dart';
import '../models/notification_category.dart';
import '../models/notification_priority.dart';
import '../providers/notification_center_provider.dart';

class NotificationCardWidget extends ConsumerWidget {
  final NotificationItemModel notification;
  final VoidCallback onTap;

  const NotificationCardWidget({
    super.key,
    required this.notification,
    required this.onTap,
  });

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(notificationCenterProvider);
    final notifier = ref.read(notificationCenterProvider.notifier);
    final isSelected = state.selectedNotificationIds.contains(notification.id);

    final catColor = notification.category.color;
    final priorityColor = notification.priority.color;
    final priorityBg = notification.priority.badgeBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF5B4CF0).withValues(alpha: 0.08)
            : (notification.isRead
                ? (isDark ? Theme.of(context).cardColor : Colors.white)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF5B4CF0)
              : (notification.isPinned
                  ? const Color(0xFF5B4CF0).withValues(alpha: 0.4)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          width: isSelected || notification.isPinned ? 1.5 : 1,
        ),
        boxShadow: notification.isRead
            ? const [BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))]
            : const [BoxShadow(color: Color(0x105B4CF0), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selection Checkbox
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFF5B4CF0),
                  onChanged: (_) => notifier.toggleSelectNotification(notification.id),
                ),
                const SizedBox(width: 4),

                // Category Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notification.category.icon, color: catColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Card Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Line: Badges & Relative Time
                      Row(
                        children: [
                          // Unread Indicator Dot
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF5B4CF0),
                                shape: BoxShape.circle,
                              ),
                            ),

                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notification.category.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? priorityColor.withValues(alpha: 0.2) : priorityBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              notification.priority.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Pinned Icon Indicator
                          if (notification.isPinned) ...[
                            const Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFF5B4CF0)),
                            const SizedBox(width: 6),
                          ],

                          // Relative Timestamp
                          Text(
                            _formatRelativeTime(notification.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Description
                      Text(
                        notification.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Footer Line: Sender Name & Direct Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (notification.senderName != null)
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  notification.senderName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),

                          // Action Button
                          if (notification.actionLabel != null && notification.actionLabel!.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                if (!notification.isRead) {
                                  notifier.toggleReadStatus(notification.id);
                                }
                                if (notification.actionRoute != null && notification.actionRoute!.isNotEmpty) {
                                  context.push(notification.actionRoute!);
                                } else {
                                  context.push('/notification-detail', extra: notification);
                                }
                              },
                              icon: const Icon(Icons.arrow_outward_rounded, size: 14),
                              label: Text(
                                notification.actionLabel!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5B4CF0),
                                side: const BorderSide(color: Color(0xFF5B4CF0)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Overflow Options Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  onSelected: (action) {
                    switch (action) {
                      case 'toggle_read':
                        notifier.toggleReadStatus(notification.id);
                        break;
                      case 'toggle_pin':
                        notifier.togglePinStatus(notification.id);
                        break;
                      case 'archive':
                        notifier.archiveNotification(notification.id);
                        break;
                      case 'delete':
                        notifier.deleteNotification(notification.id);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_read',
                      child: Row(
                        children: [
                          Icon(notification.isRead ? Icons.mark_as_unread_rounded : Icons.drafts_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(notification.isRead ? 'Mark as Unread' : 'Mark as Read'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_pin',
                      child: Row(
                        children: [
                          Icon(notification.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(notification.isPinned ? 'Unpin Notification' : 'Pin Notification'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Archive'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
