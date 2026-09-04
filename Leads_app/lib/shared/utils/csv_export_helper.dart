import 'package:intl/intl.dart';
import 'app_formatter.dart';

/// Helper class for sanitizing and formatting CSV values to ensure clean, accurate,
/// and human-readable Excel rendering without formula injection, scientific notation (4.23E+09),
/// or date column truncated '#####' rendering.
class CsvExportHelper {
  /// Formats currency for CSV/Excel export (e.g. ₹20,000.00).
  static String formatCurrency(double? amount) {
    return AppFormatter.formatCurrency(amount);
  }

  /// Formats date and time cleanly as text `yyyy-MM-dd HH:mm:ss` (e.g., 2026-08-11 19:48:32).
  /// Prefixing with '\t' forces Excel to render as plain text, preventing Excel's Date-Type
  /// column overflow '#####' behavior while keeping full date and time visible.
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final formatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    return '\t$formatted';
  }

  /// Formats date-only fields as text `yyyy-MM-dd` (e.g., 2026-08-11).
  static String formatDateOnly(DateTime? dateTime) {
    if (dateTime == null) return '';
    final formatted = DateFormat('yyyy-MM-dd').format(dateTime);
    return '\t$formatted';
  }

  /// Formats time-only fields as text `hh:mm a` (e.g., 07:48 PM).
  static String formatTimeOnly(DateTime? dateTime) {
    if (dateTime == null) return '';
    final formatted = DateFormat('hh:mm a').format(dateTime);
    return '\t$formatted';
  }

  /// Formats mobile / phone numbers so Excel treats them as literal text.
  /// Prevents Excel from converting phone numbers to scientific notation (4.23E+09),
  /// stripping leading zeros, or introducing unwanted '=' formula prefixes.
  static String formatPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final cleaned = phone.trim();
    // Prefixing with '\t' (tab character) forces Excel to interpret 
    // the cell value as explicit text without rendering formula '=' or scientific notation.
    return '\t$cleaned';
  }

  /// Formats employee IDs, reference codes, or numeric identifiers.
  /// Preserves exact characters (e.g., STEF12, JOHN45, 00123) without auto-conversion.
  static String formatId(String? id) {
    if (id == null || id.trim().isEmpty) return '';
    final cleaned = id.trim();
    // If the ID is strictly numeric and has leading zero(s), prefix with '\t' to preserve zeros
    if (cleaned.startsWith('0') && cleaned.length > 1 && RegExp(r'^\d+$').hasMatch(cleaned)) {
      return '\t$cleaned';
    }
    return sanitizeText(cleaned);
  }

  /// Sanitizes text fields and prevents Excel Formula Injection (=, +, -, @).
  static String sanitizeText(String? value) {
    if (value == null) return '';
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    // Formula safety check: if string starts with formula symbols (=, +, -, @)
    if (trimmed.startsWith('=') || trimmed.startsWith('@') || trimmed.startsWith('+') || trimmed.startsWith('-')) {
      // If it's a legitimate plain numeric value (like -15.50 or +10), leave as is
      if (double.tryParse(trimmed) != null) {
        return trimmed;
      }
      // Otherwise, prefix with tab character to treat as plain text in Excel
      return '\t$trimmed';
    }

    return trimmed;
  }
}
