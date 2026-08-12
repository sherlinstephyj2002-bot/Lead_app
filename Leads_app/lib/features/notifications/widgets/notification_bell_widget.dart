import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_center_sheet.dart';
import '../../../shared/providers/providers.dart';

class NotificationBellWidget extends ConsumerWidget {
  final Color iconColor;
  final double iconSize;

  const NotificationBellWidget({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 24.0,
  });

  void _openNotificationCenter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => const NotificationCenterSheetWidget(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);
    final backendNotifs = notifsAsync.value ?? [];
    final unreadCount = backendNotifs.where((n) => !n.isRead).length;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Notification Center',
          icon: Icon(
            unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            color: iconColor,
            size: iconSize,
          ),
          onPressed: () => _openNotificationCenter(context),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => _openNotificationCenter(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33EF4444),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
