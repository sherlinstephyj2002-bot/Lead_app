import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_html.dart';

class FileDownloadService {
  /// Downloads or exports a CSV file directly to the user's Downloads folder
  static Future<void> downloadCsv({
    required String csvContent,
    required String fileName,
  }) async {
    final bytes = utf8.encode(csvContent);
    final fullName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';

    if (kIsWeb) {
      downloadFileWeb(bytes, fullName, 'text/csv;charset=utf-8');
    } else {
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fullName,
      );
    }
  }

  /// Downloads or exports a PDF file directly to the user's Downloads folder
  static Future<void> downloadPdf({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    final fullName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

    if (kIsWeb) {
      downloadFileWeb(pdfBytes, fullName, 'application/pdf');
    } else {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fullName,
      );
    }
  }
}
