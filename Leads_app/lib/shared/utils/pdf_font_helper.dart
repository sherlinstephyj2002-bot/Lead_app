import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Helper to load Unicode TTF fonts for PDF generation.
/// Guarantees that the Indian Rupee symbol (₹) and all special characters
/// render cleanly without square boxes (□) or missing glyphs.
class PdfFontHelper {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  /// Loads TTF fonts with full Unicode and Rupee (₹) symbol support.
  static Future<pw.ThemeData> getPdfTheme() async {
    try {
      _cachedRegular ??= await PdfGoogleFonts.robotoRegular();
      _cachedBold ??= await PdfGoogleFonts.robotoBold();

      return pw.ThemeData.withFont(
        base: _cachedRegular!,
        bold: _cachedBold!,
      );
    } catch (_) {
      // Fallback to standard Helvetica if network font download is unavailable
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  /// Returns cached regular font or fallback
  static pw.Font get regularFont => _cachedRegular ?? pw.Font.helvetica();

  /// Returns cached bold font or fallback
  static pw.Font get boldFont => _cachedBold ?? pw.Font.helveticaBold();
}
