import 'package:flutter/material.dart';

/// Controller returned by [AppNotification.showPending] to allow updating 
/// the pending notification to Success or Error once processing completes.
class PendingNotificationController {
  final BuildContext _context;
  bool _isCompleted = false;

  PendingNotificationController(this._context);

  /// Automatically replaces the pending notification with a Success notification (1s auto-dismiss).
  void success([String message = 'Saved successfully']) {
    if (_isCompleted) return;
    _isCompleted = true;
    AppNotification.showSuccess(_context, message);
  }

  /// Automatically replaces the pending notification with an Error notification (2s auto-dismiss).
  void error([String message = 'Failed to save']) {
    if (_isCompleted) return;
    _isCompleted = true;
    AppNotification.showError(_context, message);
  }

  /// Dismisses the pending notification immediately.
  void dismiss() {
    if (_isCompleted) return;
    _isCompleted = true;
    AppNotification.dismiss(_context);
  }
}

/// Centralized notification utility for the WorkTrack application.
/// 
/// Key Specifications:
/// 1. SHORT AUTO-DISMISS TIME:
///    - Success: 1 second max.
///    - Failed / Error: 2 seconds max.
///    - Pending: Visible only while processing, automatically replaced on completion.
/// 2. DO NOT BLOCK BOTTOM NAVIGATION:
///    - Floats above bottom navigation bar with 24px margin (`bottom: 24`).
///    - Leaves bottom navigation tabs (Home, Orders, Attendance, Employees, More) clickable.
/// 3. COMPACT NOTIFICATION DESIGN:
///    - Compact width pill based on content.
///    - Small height, rounded corners (24px), subtle shadow (elevation 4).
/// 4. PREVENT STACKING:
///    - Clears active snackbars before displaying a new one (`clearSnackBars()`).
class AppNotification {
  AppNotification._();

  /// Dismisses any currently visible notification immediately.
  static void dismiss(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Displays a compact, floating green success notification (Auto-dismisses in 1 second).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 1),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // PREVENT STACKING: Clear existing notifications immediately
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: const Color(0xFF10B981), // Compact vibrant green
        margin: const EdgeInsets.only(
          bottom: 24, // Floats 24px above bottom navigation bar
          left: 48,
          right: 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a compact, floating red error notification (Auto-dismisses in 2 seconds).
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: const Color(0xFFEF4444), // Compact error red
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 48,
          right: 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cancel_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a pending/loading notification while an async operation is running.
  /// 
  /// Returns a [PendingNotificationController] to easily transition to success or error when done.
  static PendingNotificationController showPending(
    BuildContext context, [
    String message = 'Saving...',
  ]) {
    if (!context.mounted) return PendingNotificationController(context);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5), // Remains active until process resolves
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: const Color(0xFF1E293B), // Compact sleek dark badge
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 48,
          right: 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return PendingNotificationController(context);
  }

  /// Displays a compact floating info notification (Auto-dismisses in 2 seconds).
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: const Color(0xFF3B82F6), // Vibrant info blue
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 48,
          right: 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

