import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/notification_category.dart';
import '../models/notification_item_model.dart';
import '../providers/notification_center_provider.dart';

import '../../../shared/providers/providers.dart';

class NotificationCenterSheetWidget extends ConsumerStatefulWidget {
  const NotificationCenterSheetWidget({super.key});

  @override
  ConsumerState<NotificationCenterSheetWidget> createState() => _NotificationCenterSheetWidgetState();
}

class _NotificationCenterSheetWidgetState extends ConsumerState<NotificationCenterSheetWidget> {
  String _selectedFilterKey = 'All'; // 'All', 'Unread', 'Leave', 'Attendance', 'Payroll', 'Orders', 'System'

  @override
  Widget build(BuildContext context) {
    final backendNotifsAsync = ref.watch(notificationsProvider);
    final backendNotifs = backendNotifsAsync.value ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationCenterProvider.notifier).syncFromBackend(backendNotifs);
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(notificationCenterProvider);
    final notifier = ref.read(notificationCenterProvider.notifier);

    // Apply Filter
    final allNotifications = state.notifications.where((n) => !n.isArchived).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final filteredList = allNotifications.where((n) {
      if (_selectedFilterKey == 'Unread') return !n.isRead;
      if (_selectedFilterKey == 'Leave') return n.category == NotificationCategory.leaves;
      if (_selectedFilterKey == 'Attendance') return n.category == NotificationCategory.attendance;
      if (_selectedFilterKey == 'Payroll') return n.category == NotificationCategory.payroll;
      if (_selectedFilterKey == 'Orders') return n.category == NotificationCategory.orders;
      if (_selectedFilterKey == 'System') {
        return n.category == NotificationCategory.system ||
            n.category == NotificationCategory.subscription ||
            n.category == NotificationCategory.announcements ||
            n.category == NotificationCategory.hr;
      }
      return true;
    }).toList();

    // Group Notifications by Date Section
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yestStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    final todayItems = <NotificationItemModel>[];
    final yestItems = <NotificationItemModel>[];
    final weekItems = <NotificationItemModel>[];
    final olderItems = <NotificationItemModel>[];

    for (final item in filteredList) {
      if (item.timestamp.isAfter(todayStart)) {
        todayItems.add(item);
      } else if (item.timestamp.isAfter(yestStart)) {
        yestItems.add(item);
      } else if (item.timestamp.isAfter(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Handle Bar ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Top Title Row & Bulk Actions ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4CF0).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF5B4CF0), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notification Center',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                if (state.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.unreadCount} New',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'mark_all') {
                      notifier.markAllAsRead();
                    } else if (val == 'clear_all') {
                      notifier.clearAll();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'mark_all',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF5B4CF0)),
                          SizedBox(width: 10),
                          Text('Mark all as read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 10),
                          Text('Clear all notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Horizontal Filter Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
            child: Row(
              children: [
                _buildFilterChip('All', _selectedFilterKey == 'All'),
                _buildFilterChip('Unread', _selectedFilterKey == 'Unread'),
                _buildFilterChip('Leave', _selectedFilterKey == 'Leave'),
                _buildFilterChip('Attendance', _selectedFilterKey == 'Attendance'),
                _buildFilterChip('Payroll', _selectedFilterKey == 'Payroll'),
                _buildFilterChip('Orders', _selectedFilterKey == 'Orders'),
                _buildFilterChip('System', _selectedFilterKey == 'System'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderColor),

          // ── Grouped Notifications List ──
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState(context, isDark)
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    children: [
                      if (todayItems.isNotEmpty) ...[
                        _buildSectionHeader('Today', todayItems.length, isDark),
                        ...todayItems.map((item) => _buildNotificationCard(context, item, cardBgColor, borderColor, isDark)),
                        const SizedBox(height: 16),
                      ],
                      if (yestItems.isNotEmpty) ...[
                        _buildSectionHeader('Yesterday', yestItems.length, isDark),
                        ...yestItems.map((item) => _buildNotificationCard(context, item, cardBgColor, borderColor, isDark)),
                        const SizedBox(height: 16),
                      ],
                      if (weekItems.isNotEmpty) ...[
                        _buildSectionHeader('This Week', weekItems.length, isDark),
                        ...weekItems.map((item) => _buildNotificationCard(context, item, cardBgColor, borderColor, isDark)),
                        const SizedBox(height: 16),
                      ],
                      if (olderItems.isNotEmpty) ...[
                        _buildSectionHeader('Older', olderItems.length, isDark),
                        ...olderItems.map((item) => _buildNotificationCard(context, item, cardBgColor, borderColor, isDark)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedFilterKey = label);
          }
        },
        selectedColor: const Color(0xFF5B4CF0),
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, top: 4.0),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    NotificationItemModel item,
    Color cardBgColor,
    Color borderColor,
    bool isDark,
  ) {
    final notifier = ref.read(notificationCenterProvider.notifier);
    final categoryColor = item.category.color;
    final categoryIcon = item.category.icon;
    final timeFormatted = _formatTimeAgo(item.timestamp);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        notifier.deleteNotification(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification removed.'), duration: Duration(seconds: 2)),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        color: item.isRead ? cardBgColor : (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.3) : const Color(0xFFEEF2FF)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: item.isRead ? borderColor : const Color(0xFF5B4CF0).withValues(alpha: 0.4),
            width: item.isRead ? 1 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: () {
            notifier.markAsRead(item.id);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            if (item.actionRoute != null && item.actionRoute!.isNotEmpty) {
              context.push(item.actionRoute!);
            } else {
              context.push('/notification-detail', extra: item);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon Badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5B4CF0),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            timeFormatted,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          height: 1.3,
                        ),
                      ),
                      if (item.actionLabel != null && item.actionLabel!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            notifier.markAsRead(item.id);
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            if (item.actionRoute != null && item.actionRoute!.isNotEmpty) {
                              context.push(item.actionRoute!);
                            } else {
                              context.push('/notification-detail', extra: item);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4CF0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            item.actionLabel!,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_rounded,
                size: 48,
                color: Color(0xFF5B4CF0),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Notifications',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You are all caught up! No notifications match the selected filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(timestamp);
  }
}
