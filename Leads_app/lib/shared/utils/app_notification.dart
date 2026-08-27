import 'package:flutter/material.dart';

/// Centralized notification utility for the WorkTrack Lead App.
class AppNotification {
  /// Displays a compact, floating green success notification.
  /// 
  /// Key Behavior & Specs:
  /// 1. DURATION: Stays visible for ONLY 2 seconds.
  /// 2. COMPACT WIDTH: Floating pill/badge styling with horizontal margins.
  /// 3. POSITION: Floats above bottom navigation bar (bottom margin 24px).
  /// 4. PREVENT STACKING: Dismisses any active snackbars before showing new one.
  /// 5. STYLE: Green background, check icon, rounded corners (24px).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    
    // PREVENT STACKING: Clear existing snackbars
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: const Color(0xFF10B981), // Vibrant green success color
        margin: const EdgeInsets.only(
          bottom: 24, // Floats safely above bottom navigation bar
          left: 36,
          right: 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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

  /// Optional helper to show error snackbars without altering standard error appearance.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: const Color(0xFFBA1A1A),
        margin: const EdgeInsets.only(
          bottom: 24,
          left: 24,
          right: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
