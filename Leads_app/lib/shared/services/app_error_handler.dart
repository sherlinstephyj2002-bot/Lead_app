import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized Error Handler for WorkTrack application.
/// Maps all Firebase, network, and unexpected exceptions into clean,
/// professional, user-friendly strings while keeping detailed raw logs
/// in the debug console for developers.
class AppErrorHandler {
  AppErrorHandler._();

  /// Returns a clean, user-friendly error string for display in UI dialogs & SnackBars.
  /// Always logs the complete raw exception details to the debug console.
  static String parseError(dynamic error, [StackTrace? stackTrace]) {
    // 1. Always log raw error for developer debugging
    if (kDebugMode) {
      debugPrint('================ [WORKTRACK ERROR LOG] ================');
      debugPrint('Raw Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack Trace:\n$stackTrace');
      }
      debugPrint('======================================================');
    }

    if (error == null) {
      return 'Something went wrong. Please try again later.';
    }

    // 2. Handle FirebaseAuthException specifically
    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthCode(error.code, error.message);
    }

    // 3. Handle general FirebaseException (Firestore, Storage, Functions)
    if (error is FirebaseException) {
      return _mapFirebaseExceptionCode(error.code, error.message);
    }

    // 4. Handle String messages (if exception was converted to string e.g. "Exception: [firebase_auth/...]")
    final errorString = error.toString();
    if (errorString.contains('firebase_auth/') ||
        errorString.contains('FirebaseException') ||
        errorString.contains('[firebase_')) {
      return _parseRawFirebaseString(errorString);
    }

    // 5. Handle network related string exceptions
    final lowerStr = errorString.toLowerCase();
    if (lowerStr.contains('network') ||
        lowerStr.contains('socketexception') ||
        lowerStr.contains('connection refused') ||
        lowerStr.contains('handshakeexception')) {
      return 'Network error. Please check your internet connection.';
    }

    if (lowerStr.contains('timeout') || lowerStr.contains('timed out')) {
      return 'The request timed out. Please check your internet connection.';
    }

    // If string is already clean (no brackets, no Exception: prefix, reasonable length), return it
    if (!errorString.contains('[') &&
        !errorString.contains('Exception:') &&
        !errorString.contains('StackTrace') &&
        errorString.length < 120 &&
        errorString.trim().isNotEmpty) {
      return errorString.trim();
    }

    // Fallback for any unknown or internal SDK exception
    return 'Something went wrong. Please try again later.';
  }

  /// Maps standard FirebaseAuth error codes to friendly strings
  static String _mapFirebaseAuthCode(String code, String? rawMessage) {
    final cleanCode = code.toLowerCase().trim();
    switch (cleanCode) {
      case 'wrong-password':
      case 'invalid-password':
      case 'invalid-credential':
        return 'Incorrect password.';

      case 'user-not-found':
        return 'Account not found.';

      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email address.';

      case 'invalid-email':
        return 'Invalid email.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'user-disabled':
        return 'Your account has been disabled. Please contact your administrator.';

      case 'requires-recent-login':
        return 'Please sign in again to continue.';

      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';

      case 'expired-action-code':
        return 'OTP expired.';

      case 'invalid-action-code':
        return 'Invalid OTP code.';

      case 'quota-exceeded':
        return 'Service limit reached. Please try again later.';

      case 'operation-not-allowed':
        return 'This sign-in method is currently disabled.';

      case 'credential-already-in-use':
        return 'This account credential is already linked to another user.';

      default:
        return 'Something went wrong. Please try again later.';
    }
  }

  /// Maps standard Firebase (Firestore / Storage) error codes to friendly strings
  static String _mapFirebaseExceptionCode(String code, String? rawMessage) {
    final cleanCode = code.toLowerCase().trim();
    switch (cleanCode) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';

      case 'unavailable':
      case 'service-unavailable':
        return 'Service is temporarily unavailable. Please try again later.';

      case 'not-found':
        return 'Account not found.';

      case 'already-exists':
        return 'Record already exists.';

      case 'resource-exhausted':
        return 'Usage limit exceeded. Please try again later.';

      case 'deadline-exceeded':
        return 'Request timed out. Please check your network connection.';

      case 'unauthenticated':
        return 'Please sign in again to continue.';

      case 'cancelled':
      case 'canceled':
        return 'Operation was cancelled.';

      default:
        return 'Something went wrong. Please try again later.';
    }
  }

  /// Parses raw exception string output that might contain bracketed Firebase code fragments
  static String _parseRawFirebaseString(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid-email')) {
      return 'Invalid email.';
    }
    if (lower.contains('wrong-password') || lower.contains('invalid-credential') || lower.contains('invalid-password')) {
      return 'Incorrect password.';
    }
    if (lower.contains('user-not-found')) {
      return 'Account not found.';
    }
    if (lower.contains('otp expired') || lower.contains('expired-action-code')) {
      return 'OTP expired.';
    }
    if (lower.contains('password mismatch')) {
      return 'Password mismatch.';
    }
    if (lower.contains('email-already-in-use')) {
      return 'An account already exists with this email address.';
    }
    if (lower.contains('too-many-requests')) {
      return 'Too many login attempts. Please try again later.';
    }
    if (lower.contains('network-request-failed') || lower.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    if (lower.contains('user-disabled')) {
      return 'Your account has been disabled. Please contact your administrator.';
    }
    if (lower.contains('permission-denied')) {
      return 'You do not have permission to perform this action.';
    }
    return 'Something went wrong. Please try again later.';
  }
}
