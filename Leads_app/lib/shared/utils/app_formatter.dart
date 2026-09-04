import 'package:intl/intl.dart';

/// Centralized application formatting utility for Currency, Dates, and Numbers.
/// Guarantees consistent presentation across UI, PDFs, Excel, and CSV exports.
class AppFormatter {
  static final NumberFormat _inCurrencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inCurrencyNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final DateFormat _defaultDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _fullDateFormat = DateFormat('dd MMMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Format double amount into Indian currency format: ₹20,000.00 or ₹1,25,000.00
  static String formatCurrency(
    double? amount, {
    bool includeSymbol = true,
    bool showDecimals = true,
    String symbol = '₹',
  }) {
    if (amount == null || amount.isNaN || amount.isInfinite) {
      return includeSymbol ? '${symbol}0.00' : '0.00';
    }

    final formatter = showDecimals ? _inCurrencyFormat : _inCurrencyNoDecimals;
    final formatted = formatter.format(amount);

    if (symbol != '₹') {
      return formatted.replaceAll('₹', symbol);
    }

    if (!includeSymbol) {
      return formatted.replaceAll('₹', '').trim();
    }

    return formatted;
  }

  /// Safe PDF currency format with Unicode Rupee symbol fallback
  static String formatCurrencyPdf(
    double? amount, {
    bool showDecimals = true,
    String fallbackSymbol = '₹',
  }) {
    return formatCurrency(
      amount,
      includeSymbol: true,
      showDecimals: showDecimals,
      symbol: fallbackSymbol,
    );
  }

  /// Format date to readable string: "03 Sep 2026"
  static String formatDate(DateTime? date, {String? customPattern}) {
    if (date == null) return '—';
    try {
      if (customPattern != null) {
        return DateFormat(customPattern).format(date.toLocal());
      }
      return _defaultDateFormat.format(date.toLocal());
    } catch (_) {
      return '—';
    }
  }

  /// Format date to full readable string: "03 September 2026"
  static String formatDateFull(DateTime? date) {
    if (date == null) return '—';
    try {
      return _fullDateFormat.format(date.toLocal());
    } catch (_) {
      return '—';
    }
  }

  /// Format date and time: "03 Sep 2026, 05:30 PM"
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    try {
      return _dateTimeFormat.format(dateTime.toLocal());
    } catch (_) {
      return '—';
    }
  }

  /// Format date for ISO export (Excel / CSV): "2026-09-03"
  static String formatDateIso(DateTime? date) {
    if (date == null) return '';
    try {
      return _isoDateFormat.format(date.toLocal());
    } catch (_) {
      return '';
    }
  }
}
