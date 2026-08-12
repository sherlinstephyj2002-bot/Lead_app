import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_category.dart';
import '../models/notification_priority.dart';
import '../providers/notification_center_provider.dart';

class NotificationFilterBar extends ConsumerWidget {
  const NotificationFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(notificationCenterProvider);
    final notifier = ref.read(notificationCenterProvider.notifier);
    final selectedCount = state.selectedNotificationIds.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search Field & Bulk Actions Row ──
          Row(
            children: [
              // Global Search Field
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (val) => notifier.setSearchQuery(val),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      hintText: 'Search notifications by title, details or category...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Bulk Action Button Group (When items are selected)
              if (selectedCount > 0) ...[
                ElevatedButton.icon(
                  onPressed: () => notifier.deleteSelected(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text('Delete ($selectedCount)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => notifier.pinSelected(),
                  icon: const Icon(Icons.push_pin_rounded, size: 16),
                  label: const Text('Pin Selected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B4CF0),
                    side: const BorderSide(color: Color(0xFF5B4CF0)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear Selection',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => notifier.clearSelection(),
                ),
              ] else ...[
                // Standard Quick Actions
                OutlinedButton.icon(
                  onPressed: () => notifier.markAllAsRead(),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark All Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B4CF0),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'More Actions',
                  icon: Icon(Icons.tune_rounded, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  onSelected: (val) {
                    if (val == 'selectAll') notifier.selectAllFiltered();
                    if (val == 'clearRead') notifier.clearReadNotifications();
                    if (val == 'reset') notifier.resetFilters();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'selectAll', child: Text('Select All Visible')),
                    const PopupMenuItem(value: 'clearRead', child: Text('Clear Read Notifications')),
                    const PopupMenuItem(value: 'reset', child: Text('Reset Filters')),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ── Scrollable Filter Pills & Dropdowns Row ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Read Status Chips
                _buildChoiceChip('All', state.readFilter == 'All', () => notifier.setReadFilter('All')),
                const SizedBox(width: 6),
                _buildChoiceChip('Unread (${state.unreadCount})', state.readFilter == 'Unread', () => notifier.setReadFilter('Unread')),
                const SizedBox(width: 6),
                _buildChoiceChip('Read', state.readFilter == 'Read', () => notifier.setReadFilter('Read')),
                const SizedBox(width: 6),
                _buildChoiceChip('Pinned 📌', state.readFilter == 'Pinned', () => notifier.setReadFilter('Pinned')),

                const SizedBox(width: 16),
                Container(height: 20, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                const SizedBox(width: 16),

                // Category Filter Dropdown
                SizedBox(
                  width: 160,
                  height: 38,
                  child: DropdownButtonFormField<NotificationCategory?>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      hintText: 'Category',
                      hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    value: state.selectedCategory,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ...NotificationCategory.values.map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.displayName, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (cat) => notifier.setCategoryFilter(cat),
                  ),
                ),
                const SizedBox(width: 8),

                // Priority Filter Dropdown
                SizedBox(
                  width: 140,
                  height: 38,
                  child: DropdownButtonFormField<NotificationPriority?>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      hintText: 'Priority',
                      hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    value: state.selectedPriority,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Priorities')),
                      ...NotificationPriority.values.map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ),
                      ),
                    ],
                    onChanged: (p) => notifier.setPriorityFilter(p),
                  ),
                ),
                const SizedBox(width: 8),

                // Date Filter Dropdown
                SizedBox(
                  width: 140,
                  height: 38,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    value: state.dateFilter,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Dates')),
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
                      DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setDateFilter(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF5B4CF0),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onSelected(),
    );
  }
}
